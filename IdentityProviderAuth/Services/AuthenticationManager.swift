import Foundation
import Combine

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
    }
    
    deinit {
        tokenRefreshTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    func checkAuthenticationStatus() {
        Task {
            // Check if we have stored tokens first
            do {
                let _: AuthTokens = try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
                
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
        
        do {
            try keychainManager.deleteAll()
        } catch {
            print("Failed to clear keychain: \(error)")
        }
        
        authenticationState = .unauthenticated
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
}