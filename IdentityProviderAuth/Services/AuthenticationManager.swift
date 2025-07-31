import Foundation
import Combine
import UIKit

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var authenticationState: AuthenticationState = .unauthenticated
    @Published var availableProviders: [IdentityProvider] = []
    @Published var selectedProvider: IdentityProvider?
    
    private let keychainManager: KeychainManagerProtocol
    private let biometricManager: BiometricManagerProtocol
    private let configurationManager: ConfigurationManagerProtocol
    private let identityProviderService: IdentityProviderServiceProtocol
    private let networkManager: NetworkManagerProtocol
    
    private var cancellables = Set<AnyCancellable>()
    private var tokenRefreshTimer: Timer?
    private var sessionTimeoutTimer: Timer?
    private var lastActivityTime: Date = Date()
    
    // Session timeout configuration (30 minutes)
    private let sessionTimeoutInterval: TimeInterval = 30 * 60
    
    init(
        keychainManager: KeychainManagerProtocol = KeychainManager(),
        biometricManager: BiometricManagerProtocol = BiometricManager(),
        configurationManager: ConfigurationManagerProtocol = ConfigurationManager(),
        identityProviderService: IdentityProviderServiceProtocol? = nil,
        networkManager: NetworkManagerProtocol = NetworkManager()
    ) {
        self.keychainManager = keychainManager
        self.biometricManager = biometricManager
        self.configurationManager = configurationManager
        self.networkManager = networkManager
        self.identityProviderService = identityProviderService ?? IdentityProviderService(networkManager: networkManager)
        
        loadConfiguration()
        setupNetworkMonitoring()
        setupAppLifecycleMonitoring()
    }
    
    deinit {
        tokenRefreshTimer?.invalidate()
        sessionTimeoutTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    func checkAuthenticationStatus() {
        Task {
            // Check if we have stored tokens first
            do {
                let tokens: AuthTokens? = try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
                guard tokens != nil else {
                    await MainActor.run {
                        self.authenticationState = .unauthenticated
                    }
                    return
                }
                
                // If biometric auth is enabled and available, prompt for biometric authentication
                if biometricManager.isBiometricAuthenticationEnabled() && biometricManager.isBiometricAuthenticationAvailable() {
                    await authenticateWithBiometrics()
                } else {
                    // Otherwise, perform standard authentication check
                    await performAuthenticationCheck()
                }
            } catch {
                // No stored tokens, user needs to authenticate
                authenticationState = .unauthenticated
            }
        }
    }
    
    func authenticate(credentials: Credentials) async {
        guard let provider = selectedProvider else {
            authenticationState = .error(.configurationError("No provider selected"))
            return
        }
        
        authenticationState = .authenticating
        
        do {
            let tokens = try await identityProviderService.authenticate(credentials: credentials, provider: provider)
            let user = try await identityProviderService.getUserInfo(accessToken: tokens.accessToken, provider: provider)
            
            try keychainManager.store(tokens, forKey: KeychainManager.Keys.authTokens)
            try keychainManager.store(user, forKey: KeychainManager.Keys.user)
            try keychainManager.store(provider.id, forKey: KeychainManager.Keys.selectedProvider)
            
            authenticationState = .authenticated(user)
            scheduleTokenRefresh(tokens: tokens)
            refreshUserActivity() // Start session timeout
            
        } catch {
            authenticationState = .error(error as? AuthenticationError ?? .unknownError(error))
        }
    }
    
    func authenticateWithBiometrics() async {
        guard biometricManager.isBiometricAuthenticationAvailable() else {
            authenticationState = .error(.biometricAuthenticationFailed)
            return
        }
        
        authenticationState = .biometricPrompt
        
        do {
            let success = try await biometricManager.authenticateWithBiometrics()
            
            if success {
                await performAuthenticationCheck()
            } else {
                authenticationState = .error(.biometricAuthenticationFailed)
            }
        } catch let error as BiometricAuthenticationError {
            switch error {
            case .userCancelled:
                // User cancelled, return to unauthenticated state without error
                authenticationState = .unauthenticated
            case .notAvailable, .lockout, .failed:
                authenticationState = .error(.biometricAuthenticationFailed)
            }
        } catch {
            authenticationState = .error(.biometricAuthenticationFailed)
        }
    }
    
    func enableBiometricAuthentication() {
        biometricManager.setBiometricAuthenticationEnabled(true)
    }
    
    func disableBiometricAuthentication() {
        biometricManager.setBiometricAuthenticationEnabled(false)
    }
    
    func shouldPromptForBiometricSetup() -> Bool {
        return biometricManager.shouldPromptForBiometricSetup()
    }
    
    func setBiometricSetupPrompted() {
        biometricManager.setBiometricSetupPrompted()
    }
    
    func isBiometricAuthenticationEnabled() -> Bool {
        return biometricManager.isBiometricAuthenticationEnabled()
    }
    
    func getBiometricType() -> BiometricType {
        return biometricManager.getBiometricType()
    }
    
    func logout() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
        sessionTimeoutTimer?.invalidate()
        sessionTimeoutTimer = nil
        
        do {
            try keychainManager.deleteAll()
        } catch {
            print("Failed to clear keychain: \(error)")
        }
        
        authenticationState = .unauthenticated
    }
    
    func refreshUserActivity() {
        lastActivityTime = Date()
        resetSessionTimeout()
    }
    
    func handleAppWillEnterForeground() {
        Task {
            await refreshTokensIfNeeded()
        }
    }
    
    func handleAppDidEnterBackground() {
        // Session timeout will continue running in background
        // iOS will suspend the app after a short time anyway
    }
    
    func selectProvider(_ provider: IdentityProvider) {
        selectedProvider = provider
        
        do {
            try keychainManager.store(provider.id, forKey: KeychainManager.Keys.selectedProvider)
        } catch {
            print("Failed to store selected provider: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadConfiguration() {
        do {
            availableProviders = try configurationManager.loadProviders()
            
            // Load previously selected provider or use default
            if let storedProviderId: String = try keychainManager.retrieve(String.self, forKey: KeychainManager.Keys.selectedProvider),
               let provider = availableProviders.first(where: { $0.id == storedProviderId }) {
                selectedProvider = provider
            } else {
                selectedProvider = try configurationManager.getDefaultProvider()
            }
        } catch {
            authenticationState = .error(error as? AuthenticationError ?? .unknownError(error))
        }
    }
    
    private func setupNetworkMonitoring() {
        if let networkManager = networkManager as? NetworkManager {
            networkManager.$isConnected
                .sink { [weak self] isConnected in
                    if !isConnected {
                        self?.authenticationState = .error(.networkError(NetworkError.noInternetConnection))
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    private func performAuthenticationCheck() async {
        do {
            guard let tokens: AuthTokens = try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens),
                  let user: User = try keychainManager.retrieve(User.self, forKey: KeychainManager.Keys.user) else {
                authenticationState = .unauthenticated
                return
            }
            
            if tokens.isExpired {
                await refreshTokens(tokens)
            } else {
                authenticationState = .authenticated(user)
                scheduleTokenRefresh(tokens: tokens)
                refreshUserActivity() // Start session timeout
            }
        } catch {
            authenticationState = .unauthenticated
        }
    }
    
    private func refreshTokens(_ tokens: AuthTokens) async {
        guard let refreshToken = tokens.refreshToken,
              let provider = selectedProvider else {
            authenticationState = .error(.tokenExpired)
            return
        }
        
        do {
            let newTokens = try await identityProviderService.refreshToken(refreshToken, provider: provider)
            try keychainManager.store(newTokens, forKey: KeychainManager.Keys.authTokens)
            
            if let user: User = try keychainManager.retrieve(User.self, forKey: KeychainManager.Keys.user) {
                authenticationState = .authenticated(user)
                scheduleTokenRefresh(tokens: newTokens)
                refreshUserActivity() // Reset session timeout after token refresh
            }
        } catch {
            authenticationState = .error(.tokenExpired)
        }
    }
    
    private func scheduleTokenRefresh(tokens: AuthTokens) {
        tokenRefreshTimer?.invalidate()
        
        // Refresh token 5 minutes before expiration
        let refreshTime = max(tokens.expiresIn - 300, 60)
        
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshTime, repeats: false) { [weak self] _ in
            Task {
                await self?.refreshTokens(tokens)
            }
        }
    }
    
    private func setupAppLifecycleMonitoring() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
    }
    
    private func resetSessionTimeout() {
        guard case .authenticated = authenticationState else { return }
        
        sessionTimeoutTimer?.invalidate()
        sessionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeoutInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleSessionTimeout()
            }
        }
    }
    
    private func handleSessionTimeout() {
        guard case .authenticated = authenticationState else { return }
        
        // Check if user has been inactive for the timeout period
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
        if timeSinceLastActivity >= sessionTimeoutInterval {
            logout()
        } else {
            // Reset timer for remaining time
            let remainingTime = sessionTimeoutInterval - timeSinceLastActivity
            sessionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.handleSessionTimeout()
                }
            }
        }
    }
    
    private func refreshTokensIfNeeded() async {
        guard case .authenticated = authenticationState else { return }
        
        do {
            guard let tokens: AuthTokens = try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens) else {
                authenticationState = .unauthenticated
                return
            }
            
            // Check if token is close to expiration (within 10 minutes)
            let timeUntilExpiration = tokens.expirationDate.timeIntervalSinceNow
            if timeUntilExpiration < 600 { // 10 minutes
                await refreshTokens(tokens)
            }
        } catch {
            authenticationState = .unauthenticated
        }
    }
}