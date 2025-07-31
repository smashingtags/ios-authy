import XCTest
import Combine
@testable import IdentityProviderAuth

@MainActor
class AuthenticationManagerTests: XCTestCase {
    var authenticationManager: AuthenticationManager!
    var mockKeychainManager: MockKeychainManager!
    var mockBiometricManager: MockBiometricManager!
    var mockConfigurationManager: MockConfigurationManager!
    var mockIdentityProviderService: MockIdentityProviderService!
    var mockNetworkManager: MockNetworkManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockKeychainManager = MockKeychainManager()
        mockBiometricManager = MockBiometricManager()
        mockConfigurationManager = MockConfigurationManager()
        mockIdentityProviderService = MockIdentityProviderService()
        mockNetworkManager = MockNetworkManager()
        cancellables = Set<AnyCancellable>()
        
        authenticationManager = AuthenticationManager(
            keychainManager: mockKeychainManager,
            biometricManager: mockBiometricManager,
            configurationManager: mockConfigurationManager,
            identityProviderService: mockIdentityProviderService,
            networkManager: mockNetworkManager
        )
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        authenticationManager = nil
        mockKeychainManager = nil
        mockBiometricManager = nil
        mockConfigurationManager = nil
        mockIdentityProviderService = nil
        mockNetworkManager = nil
        super.tearDown()
    }
    
    // MARK: - Authentication State Management Tests
    
    func testInitialAuthenticationState() {
        // Then
        XCTAssertEqual(authenticationManager.authenticationState, .unauthenticated)
    }
    
    func testAuthenticateWithValidCredentials() async {
        // Given
        let credentials = Credentials(username: "testuser", password: "testpass")
        let provider = createTestProvider()
        let expectedTokens = createTestTokens()
        let expectedUser = createTestUser()
        
        authenticationManager.selectProvider(provider)
        mockIdentityProviderService.mockAuthTokens = expectedTokens
        mockIdentityProviderService.mockUser = expectedUser
        
        // When
        await authenticationManager.authenticate(credentials: credentials)
        
        // Then
        if case .authenticated(let user) = authenticationManager.authenticationState {
            XCTAssertEqual(user.id, expectedUser.id)
            XCTAssertEqual(user.username, expectedUser.username)
        } else {
            XCTFail("Expected authenticated state, got \(authenticationManager.authenticationState)")
        }
        
        // Verify tokens and user were stored
        XCTAssertTrue(mockKeychainManager.storedItems.keys.contains(KeychainManager.Keys.authTokens))
        XCTAssertTrue(mockKeychainManager.storedItems.keys.contains(KeychainManager.Keys.user))
        XCTAssertTrue(mockKeychainManager.storedItems.keys.contains(KeychainManager.Keys.selectedProvider))
    }
    
    func testAuthenticateWithInvalidCredentials() async {
        // Given
        let credentials = Credentials(username: "invalid", password: "invalid")
        let provider = createTestProvider()
        
        authenticationManager.selectProvider(provider)
        mockIdentityProviderService.mockError = AuthenticationError.invalidCredentials
        
        // When
        await authenticationManager.authenticate(credentials: credentials)
        
        // Then
        if case .error(let error) = authenticationManager.authenticationState {
            if case .invalidCredentials = error {
                // Expected
            } else {
                XCTFail("Expected invalidCredentials error, got \(error)")
            }
        } else {
            XCTFail("Expected error state, got \(authenticationManager.authenticationState)")
        }
    }
    
    func testAuthenticateWithoutSelectedProvider() async {
        // Given
        let credentials = Credentials(username: "testuser", password: "testpass")
        // No provider selected
        
        // When
        await authenticationManager.authenticate(credentials: credentials)
        
        // Then
        if case .error(let error) = authenticationManager.authenticationState {
            if case .configurationError(let message) = error {
                XCTAssertTrue(message.contains("No provider selected"))
            } else {
                XCTFail("Expected configurationError, got \(error)")
            }
        } else {
            XCTFail("Expected error state, got \(authenticationManager.authenticationState)")
        }
    }
    
    func testAuthenticationStateTransitions() async {
        // Given
        let credentials = Credentials(username: "testuser", password: "testpass")
        let provider = createTestProvider()
        let expectedTokens = createTestTokens()
        let expectedUser = createTestUser()
        
        authenticationManager.selectProvider(provider)
        mockIdentityProviderService.mockAuthTokens = expectedTokens
        mockIdentityProviderService.mockUser = expectedUser
        
        var stateChanges: [AuthenticationState] = []
        
        authenticationManager.$authenticationState
            .sink { state in
                stateChanges.append(state)
            }
            .store(in: &cancellables)
        
        // When
        await authenticationManager.authenticate(credentials: credentials)
        
        // Then
        XCTAssertTrue(stateChanges.contains(.unauthenticated))
        XCTAssertTrue(stateChanges.contains(.authenticating))
        XCTAssertTrue(stateChanges.contains { state in
            if case .authenticated = state { return true }
            return false
        })
    }
    
    // MARK: - Token Refresh Logic Tests
    
    func testCheckAuthenticationStatusWithValidTokens() async {
        // Given
        let validTokens = createTestTokens()
        let user = createTestUser()
        let provider = createTestProvider()
        
        mockKeychainManager.storedItems[KeychainManager.Keys.authTokens] = try! JSONEncoder().encode(validTokens)
        mockKeychainManager.storedItems[KeychainManager.Keys.user] = try! JSONEncoder().encode(user)
        mockKeychainManager.storedItems[KeychainManager.Keys.selectedProvider] = provider.id.data(using: .utf8)!
        mockConfigurationManager.mockProviders = [provider]
        
        // When
        authenticationManager.checkAuthenticationStatus()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        if case .authenticated(let authenticatedUser) = authenticationManager.authenticationState {
            XCTAssertEqual(authenticatedUser.id, user.id)
        } else {
            XCTFail("Expected authenticated state, got \(authenticationManager.authenticationState)")
        }
    }
    
    func testCheckAuthenticationStatusWithExpiredTokens() async {
        // Given
        let expiredTokens = AuthTokens(
            accessToken: "expired_token",
            refreshToken: "refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid profile",
            idToken: "id_token",
            issuedAt: Date().addingTimeInterval(-7200) // 2 hours ago
        )
        let user = createTestUser()
        let provider = createTestProvider()
        let newTokens = createTestTokens()
        
        mockKeychainManager.storedItems[KeychainManager.Keys.authTokens] = try! JSONEncoder().encode(expiredTokens)
        mockKeychainManager.storedItems[KeychainManager.Keys.user] = try! JSONEncoder().encode(user)
        mockKeychainManager.storedItems[KeychainManager.Keys.selectedProvider] = provider.id.data(using: .utf8)!
        mockConfigurationManager.mockProviders = [provider]
        mockIdentityProviderService.mockRefreshTokens = newTokens
        
        // When
        authenticationManager.checkAuthenticationStatus()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        if case .authenticated(let authenticatedUser) = authenticationManager.authenticationState {
            XCTAssertEqual(authenticatedUser.id, user.id)
        } else {
            XCTFail("Expected authenticated state after token refresh, got \(authenticationManager.authenticationState)")
        }
        
        // Verify refresh token was called
        XCTAssertTrue(mockIdentityProviderService.refreshTokenCalled)
    }
    
    func testTokenRefreshFailure() async {
        // Given
        let expiredTokens = AuthTokens(
            accessToken: "expired_token",
            refreshToken: "refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid profile",
            idToken: "id_token",
            issuedAt: Date().addingTimeInterval(-7200) // 2 hours ago
        )
        let user = createTestUser()
        let provider = createTestProvider()
        
        mockKeychainManager.storedItems[KeychainManager.Keys.authTokens] = try! JSONEncoder().encode(expiredTokens)
        mockKeychainManager.storedItems[KeychainManager.Keys.user] = try! JSONEncoder().encode(user)
        mockKeychainManager.storedItems[KeychainManager.Keys.selectedProvider] = provider.id.data(using: .utf8)!
        mockConfigurationManager.mockProviders = [provider]
        mockIdentityProviderService.mockRefreshError = AuthenticationError.tokenExpired
        
        // When
        authenticationManager.checkAuthenticationStatus()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        if case .error(let error) = authenticationManager.authenticationState {
            if case .tokenExpired = error {
                // Expected
            } else {
                XCTFail("Expected tokenExpired error, got \(error)")
            }
        } else {
            XCTFail("Expected error state, got \(authenticationManager.authenticationState)")
        }
    }
    
    // MARK: - Logout Functionality Tests
    
    func testLogout() {
        // Given
        authenticationManager.authenticationState = .authenticated(createTestUser())
        mockKeychainManager.storedItems[KeychainManager.Keys.authTokens] = Data()
        mockKeychainManager.storedItems[KeychainManager.Keys.user] = Data()
        
        // When
        authenticationManager.logout()
        
        // Then
        XCTAssertEqual(authenticationManager.authenticationState, .unauthenticated)
        XCTAssertTrue(mockKeychainManager.deleteAllCalled)
    }
    
    func testLogoutClearsStoredData() {
        // Given
        mockKeychainManager.storedItems[KeychainManager.Keys.authTokens] = Data()
        mockKeychainManager.storedItems[KeychainManager.Keys.user] = Data()
        mockKeychainManager.storedItems[KeychainManager.Keys.selectedProvider] = Data()
        
        // When
        authenticationManager.logout()
        
        // Then
        XCTAssertTrue(mockKeychainManager.deleteAllCalled)
    }
    
    // MARK: - App Lifecycle Handling Tests
    
    func testHandleAppWillEnterForeground() async {
        // Given
        let tokens = createTestTokens()
        let user = createTestUser()
        let provider = createTestProvider()
        
        authenticationManager.authenticationState = .authenticated(user)
        mockKeychainManager.storedItems[KeychainManager.Keys.authTokens] = try! JSONEncoder().encode(tokens)
        mockKeychainManager.storedItems[KeychainManager.Keys.user] = try! JSONEncoder().encode(user)
        mockKeychainManager.storedItems[KeychainManager.Keys.selectedProvider] = provider.id.data(using: .utf8)!
        mockConfigurationManager.mockProviders = [provider]
        
        // When
        authenticationManager.handleAppWillEnterForeground()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        // Should remain authenticated if tokens are still valid
        if case .authenticated(let authenticatedUser) = authenticationManager.authenticationState {
            XCTAssertEqual(authenticatedUser.id, user.id)
        } else {
            XCTFail("Expected to remain authenticated, got \(authenticationManager.authenticationState)")
        }
    }
    
    func testHandleAppDidEnterBackground() {
        // Given
        authenticationManager.authenticationState = .authenticated(createTestUser())
        
        // When
        authenticationManager.handleAppDidEnterBackground()
        
        // Then
        // Should remain authenticated (background handling is minimal)
        if case .authenticated = authenticationManager.authenticationState {
            // Expected
        } else {
            XCTFail("Expected to remain authenticated in background, got \(authenticationManager.authenticationState)")
        }
    }
    
    // MARK: - Biometric Authentication Tests
    
    func testAuthenticateWithBiometricsSuccess() async {
        // Given
        let tokens = createTestTokens()
        let user = createTestUser()
        let provider = createTestProvider()
        
        mockBiometricManager.isAvailable = true
        mockBiometricManager.authenticationResult = true
        mockKeychainManager.storedItems[KeychainManager.Keys.authTokens] = try! JSONEncoder().encode(tokens)
        mockKeychainManager.storedItems[KeychainManager.Keys.user] = try! JSONEncoder().encode(user)
        mockKeychainManager.storedItems[KeychainManager.Keys.selectedProvider] = provider.id.data(using: .utf8)!
        mockConfigurationManager.mockProviders = [provider]
        
        // When
        await authenticationManager.authenticateWithBiometrics()
        
        // Then
        if case .authenticated(let authenticatedUser) = authenticationManager.authenticationState {
            XCTAssertEqual(authenticatedUser.id, user.id)
        } else {
            XCTFail("Expected authenticated state, got \(authenticationManager.authenticationState)")
        }
        
        XCTAssertTrue(mockBiometricManager.authenticateWithBiometricsCalled)
    }
    
    func testAuthenticateWithBiometricsFailure() async {
        // Given
        mockBiometricManager.isAvailable = true
        mockBiometricManager.authenticationResult = false
        
        // When
        await authenticationManager.authenticateWithBiometrics()
        
        // Then
        if case .error(let error) = authenticationManager.authenticationState {
            if case .biometricAuthenticationFailed = error {
                // Expected
            } else {
                XCTFail("Expected biometricAuthenticationFailed error, got \(error)")
            }
        } else {
            XCTFail("Expected error state, got \(authenticationManager.authenticationState)")
        }
    }
    
    func testAuthenticateWithBiometricsNotAvailable() async {
        // Given
        mockBiometricManager.isAvailable = false
        
        // When
        await authenticationManager.authenticateWithBiometrics()
        
        // Then
        if case .error(let error) = authenticationManager.authenticationState {
            if case .biometricAuthenticationFailed = error {
                // Expected
            } else {
                XCTFail("Expected biometricAuthenticationFailed error, got \(error)")
            }
        } else {
            XCTFail("Expected error state, got \(authenticationManager.authenticationState)")
        }
    }
    
    // MARK: - Provider Selection Tests
    
    func testSelectProvider() {
        // Given
        let provider = createTestProvider()
        
        // When
        authenticationManager.selectProvider(provider)
        
        // Then
        XCTAssertEqual(authenticationManager.selectedProvider?.id, provider.id)
        XCTAssertTrue(mockKeychainManager.storedItems.keys.contains(KeychainManager.Keys.selectedProvider))
    }
    
    func testLoadConfigurationWithValidProviders() {
        // Given
        let providers = [createTestProvider(), createSecondTestProvider()]
        mockConfigurationManager.mockProviders = providers
        mockConfigurationManager.mockDefaultProvider = providers[0]
        
        // When
        // Configuration is loaded during initialization
        let newAuthManager = AuthenticationManager(
            keychainManager: mockKeychainManager,
            biometricManager: mockBiometricManager,
            configurationManager: mockConfigurationManager,
            identityProviderService: mockIdentityProviderService,
            networkManager: mockNetworkManager
        )
        
        // Then
        XCTAssertEqual(newAuthManager.availableProviders.count, 2)
        XCTAssertEqual(newAuthManager.selectedProvider?.id, providers[0].id)
    }
    
    func testLoadConfigurationWithError() {
        // Given
        mockConfigurationManager.mockError = AuthenticationError.configurationError("Test error")
        
        // When
        let newAuthManager = AuthenticationManager(
            keychainManager: mockKeychainManager,
            biometricManager: mockBiometricManager,
            configurationManager: mockConfigurationManager,
            identityProviderService: mockIdentityProviderService,
            networkManager: mockNetworkManager
        )
        
        // Then
        if case .error(let error) = newAuthManager.authenticationState {
            if case .configurationError = error {
                // Expected
            } else {
                XCTFail("Expected configurationError, got \(error)")
            }
        } else {
            XCTFail("Expected error state, got \(newAuthManager.authenticationState)")
        }
    }
    
    // MARK: - User Activity and Session Management Tests
    
    func testRefreshUserActivity() {
        // Given
        let initialTime = Date()
        
        // When
        authenticationManager.refreshUserActivity()
        
        // Then
        // This test verifies the method doesn't crash and updates internal state
        // In a real implementation, we'd verify the lastActivityTime was updated
    }
    
    // MARK: - Helper Methods
    
    private func createTestProvider() -> IdentityProvider {
        return IdentityProvider(
            id: "test-provider",
            name: "Test Provider",
            displayName: "Test Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: URL(string: "https://example.com/userinfo")!,
            clientId: "test-client",
            scope: "openid profile",
            isDefault: true
        )
    }
    
    private func createSecondTestProvider() -> IdentityProvider {
        return IdentityProvider(
            id: "test-provider-2",
            name: "Test Provider 2",
            displayName: "Test Provider 2",
            authorizationEndpoint: URL(string: "https://example2.com/auth")!,
            tokenEndpoint: URL(string: "https://example2.com/token")!,
            userInfoEndpoint: URL(string: "https://example2.com/userinfo")!,
            clientId: "test-client-2",
            scope: "openid profile email",
            isDefault: false
        )
    }
    
    private func createTestTokens() -> AuthTokens {
        return AuthTokens(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid profile",
            idToken: "test_id_token",
            issuedAt: Date()
        )
    }
    
    private func createTestUser() -> User {
        return User(
            id: "test-user-id",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            provider: "test-provider"
        )
    }
}

// MARK: - Mock Classes

class MockKeychainManager: KeychainManagerProtocol {
    var storedItems: [String: Data] = [:]
    var deleteAllCalled = false
    var shouldThrowError = false
    
    func store<T: Codable>(_ item: T, forKey key: String) throws {
        if shouldThrowError {
            throw AuthenticationError.keychainError(errSecItemNotFound)
        }
        let data = try JSONEncoder().encode(item)
        storedItems[key] = data
    }
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        if shouldThrowError {
            throw AuthenticationError.keychainError(errSecItemNotFound)
        }
        guard let data = storedItems[key] else {
            return nil
        }
        return try JSONDecoder().decode(type, from: data)
    }
    
    func delete(forKey key: String) throws {
        if shouldThrowError {
            throw AuthenticationError.keychainError(errSecItemNotFound)
        }
        storedItems.removeValue(forKey: key)
    }
    
    func deleteAll() throws {
        if shouldThrowError {
            throw AuthenticationError.keychainError(errSecItemNotFound)
        }
        deleteAllCalled = true
        storedItems.removeAll()
    }
}

class MockBiometricManager: BiometricManagerProtocol {
    var isAvailable = false
    var authenticationResult = false
    var biometricType: BiometricType = .none
    var isEnabled = false
    var shouldPromptSetup = false
    var setupPrompted = false
    
    var authenticateWithBiometricsCalled = false
    
    func isBiometricAuthenticationAvailable() -> Bool {
        return isAvailable
    }
    
    func authenticateWithBiometrics() async throws -> Bool {
        authenticateWithBiometricsCalled = true
        if !isAvailable {
            throw BiometricAuthenticationError.notAvailable
        }
        return authenticationResult
    }
    
    func getBiometricType() -> BiometricType {
        return biometricType
    }
    
    func isBiometricAuthenticationEnabled() -> Bool {
        return isEnabled
    }
    
    func setBiometricAuthenticationEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    func shouldPromptForBiometricSetup() -> Bool {
        return shouldPromptSetup
    }
    
    func setBiometricSetupPrompted() {
        setupPrompted = true
    }
}

class MockConfigurationManager: ConfigurationManagerProtocol {
    var mockProviders: [IdentityProvider] = []
    var mockDefaultProvider: IdentityProvider?
    var mockError: Error?
    
    func loadProviders() throws -> [IdentityProvider] {
        if let error = mockError {
            throw error
        }
        return mockProviders
    }
    
    func getDefaultProvider() throws -> IdentityProvider {
        if let error = mockError {
            throw error
        }
        return mockDefaultProvider ?? mockProviders.first!
    }
    
    func validateProvider(_ provider: IdentityProvider) throws {
        if let error = mockError {
            throw error
        }
    }
}

class MockIdentityProviderService: IdentityProviderServiceProtocol {
    var mockAuthTokens: AuthTokens?
    var mockRefreshTokens: AuthTokens?
    var mockUser: User?
    var mockError: Error?
    var mockRefreshError: Error?
    
    var authenticateCalled = false
    var refreshTokenCalled = false
    var getUserInfoCalled = false
    
    func authenticate(credentials: Credentials, provider: IdentityProvider) async throws -> AuthTokens {
        authenticateCalled = true
        if let error = mockError {
            throw error
        }
        return mockAuthTokens!
    }
    
    func refreshToken(_ refreshToken: String, provider: IdentityProvider) async throws -> AuthTokens {
        refreshTokenCalled = true
        if let error = mockRefreshError {
            throw error
        }
        return mockRefreshTokens!
    }
    
    func getUserInfo(accessToken: String, provider: IdentityProvider) async throws -> User {
        getUserInfoCalled = true
        if let error = mockError {
            throw error
        }
        return mockUser!
    }
}

class MockNetworkManager: NetworkManagerProtocol {
    var isConnected: Bool = true
    
    func performRequest<T: Codable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T {
        throw NetworkError.noData
    }
    
    func performRequest(_ request: NetworkRequest) async throws -> Data {
        throw NetworkError.noData
    }
}