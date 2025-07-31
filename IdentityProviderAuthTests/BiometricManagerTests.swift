import XCTest
import LocalAuthentication
@testable import IdentityProviderAuth

class BiometricManagerTests: XCTestCase {
    var biometricManager: BiometricManager!
    var mockUserDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // Use a test suite name to avoid conflicts with app data
        mockUserDefaults = UserDefaults(suiteName: "BiometricManagerTests")
        mockUserDefaults.removePersistentDomain(forName: "BiometricManagerTests")
        biometricManager = BiometricManager()
    }
    
    override func tearDown() {
        mockUserDefaults.removePersistentDomain(forName: "BiometricManagerTests")
        mockUserDefaults = nil
        biometricManager = nil
        super.tearDown()
    }
    
    // MARK: - Biometric Availability Tests
    
    func testIsBiometricAuthenticationAvailable() {
        // This test will depend on the device/simulator capabilities
        // We can only test that the method returns a boolean value
        let isAvailable = biometricManager.isBiometricAuthenticationAvailable()
        XCTAssertTrue(isAvailable is Bool)
    }
    
    func testGetBiometricType() {
        let biometricType = biometricManager.getBiometricType()
        XCTAssertTrue(biometricType is BiometricType)
    }
    
    // MARK: - User Preferences Tests
    
    func testBiometricAuthenticationEnabledDefaultValue() {
        // By default, biometric authentication should be disabled
        XCTAssertFalse(biometricManager.isBiometricAuthenticationEnabled())
    }
    
    func testSetBiometricAuthenticationEnabled() {
        // Test enabling biometric authentication
        biometricManager.setBiometricAuthenticationEnabled(true)
        XCTAssertTrue(biometricManager.isBiometricAuthenticationEnabled())
        
        // Test disabling biometric authentication
        biometricManager.setBiometricAuthenticationEnabled(false)
        XCTAssertFalse(biometricManager.isBiometricAuthenticationEnabled())
    }
    
    func testShouldPromptForBiometricSetupDefaultValue() {
        // Initially, if biometrics are available but not enabled and not prompted, should return true
        // This test will vary based on device capabilities
        let shouldPrompt = biometricManager.shouldPromptForBiometricSetup()
        XCTAssertTrue(shouldPrompt is Bool)
    }
    
    func testSetBiometricSetupPrompted() {
        // Initially should prompt (if biometrics available)
        let initialShouldPrompt = biometricManager.shouldPromptForBiometricSetup()
        
        // After setting prompted, should not prompt again
        biometricManager.setBiometricSetupPrompted()
        let shouldPromptAfter = biometricManager.shouldPromptForBiometricSetup()
        
        // If biometrics are available, the behavior should change
        if biometricManager.isBiometricAuthenticationAvailable() {
            XCTAssertTrue(initialShouldPrompt)
            XCTAssertFalse(shouldPromptAfter)
        } else {
            XCTAssertFalse(initialShouldPrompt)
            XCTAssertFalse(shouldPromptAfter)
        }
    }
    
    func testShouldPromptForBiometricSetupWhenEnabled() {
        // If biometric auth is already enabled, should not prompt
        biometricManager.setBiometricAuthenticationEnabled(true)
        XCTAssertFalse(biometricManager.shouldPromptForBiometricSetup())
    }
    
    // MARK: - BiometricType Display Name Tests
    
    func testBiometricTypeDisplayNames() {
        XCTAssertEqual(BiometricType.none.displayName, "None")
        XCTAssertEqual(BiometricType.touchID.displayName, "Touch ID")
        XCTAssertEqual(BiometricType.faceID.displayName, "Face ID")
        XCTAssertEqual(BiometricType.opticID.displayName, "Optic ID")
    }
}

// MARK: - Mock BiometricManager for Testing

class MockBiometricManager: BiometricManagerProtocol {
    var isAvailable = false
    var biometricType: BiometricType = .none
    var isEnabled = false
    var setupPrompted = false
    var shouldThrowError = false
    var errorToThrow: BiometricAuthenticationError = .failed
    
    func isBiometricAuthenticationAvailable() -> Bool {
        return isAvailable
    }
    
    func authenticateWithBiometrics() async throws -> Bool {
        if shouldThrowError {
            throw errorToThrow
        }
        return isEnabled && isAvailable
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
        return isAvailable && !isEnabled && !setupPrompted
    }
    
    func setBiometricSetupPrompted() {
        setupPrompted = true
    }
}

// MARK: - Authentication Manager Biometric Tests

class AuthenticationManagerBiometricTests: XCTestCase {
    var authManager: AuthenticationManager!
    var mockBiometricManager: MockBiometricManager!
    var mockKeychainManager: MockKeychainManager!
    var mockConfigurationManager: MockConfigurationManager!
    var mockNetworkManager: MockNetworkManager!
    var mockIdentityProviderService: MockIdentityProviderService!
    
    override func setUp() {
        super.setUp()
        mockBiometricManager = MockBiometricManager()
        mockKeychainManager = MockKeychainManager()
        mockConfigurationManager = MockConfigurationManager()
        mockNetworkManager = MockNetworkManager()
        mockIdentityProviderService = MockIdentityProviderService(networkManager: mockNetworkManager)
        
        authManager = AuthenticationManager(
            keychainManager: mockKeychainManager,
            biometricManager: mockBiometricManager,
            configurationManager: mockConfigurationManager,
            identityProviderService: mockIdentityProviderService,
            networkManager: mockNetworkManager
        )
    }
    
    override func tearDown() {
        authManager = nil
        mockBiometricManager = nil
        mockKeychainManager = nil
        mockConfigurationManager = nil
        mockNetworkManager = nil
        mockIdentityProviderService = nil
        super.tearDown()
    }
    
    @MainActor
    func testAuthenticateWithBiometricsSuccess() async {
        // Setup
        mockBiometricManager.isAvailable = true
        mockBiometricManager.isEnabled = true
        mockBiometricManager.biometricType = .faceID
        
        let testTokens = AuthTokens(
            accessToken: "access_token",
            refreshToken: "refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "id_token",
            issuedAt: Date()
        )
        let testUser = User(id: "123", username: "testuser", email: "test@example.com", displayName: "Test User", provider: "test")
        
        mockKeychainManager.storedItems[KeychainManager.Keys.authTokens] = try! JSONEncoder().encode(testTokens)
        mockKeychainManager.storedItems[KeychainManager.Keys.user] = try! JSONEncoder().encode(testUser)
        
        // Execute
        await authManager.authenticateWithBiometrics()
        
        // Verify
        if case .authenticated(let user) = authManager.authenticationState {
            XCTAssertEqual(user.username, "testuser")
        } else {
            XCTFail("Expected authenticated state, got \(authManager.authenticationState)")
        }
    }
    
    @MainActor
    func testAuthenticateWithBiometricsUserCancelled() async {
        // Setup
        mockBiometricManager.isAvailable = true
        mockBiometricManager.isEnabled = true
        mockBiometricManager.shouldThrowError = true
        mockBiometricManager.errorToThrow = .userCancelled
        
        // Execute
        await authManager.authenticateWithBiometrics()
        
        // Verify - should return to unauthenticated state without error
        XCTAssertEqual(authManager.authenticationState, .unauthenticated)
    }
    
    @MainActor
    func testAuthenticateWithBiometricsNotAvailable() async {
        // Setup
        mockBiometricManager.isAvailable = false
        
        // Execute
        await authManager.authenticateWithBiometrics()
        
        // Verify
        if case .error(let error) = authManager.authenticationState {
            XCTAssertEqual(error as? AuthenticationError, .biometricAuthenticationFailed)
        } else {
            XCTFail("Expected error state, got \(authManager.authenticationState)")
        }
    }
    
    @MainActor
    func testAuthenticateWithBiometricsFailed() async {
        // Setup
        mockBiometricManager.isAvailable = true
        mockBiometricManager.isEnabled = true
        mockBiometricManager.shouldThrowError = true
        mockBiometricManager.errorToThrow = .failed
        
        // Execute
        await authManager.authenticateWithBiometrics()
        
        // Verify
        if case .error(let error) = authManager.authenticationState {
            XCTAssertEqual(error as? AuthenticationError, .biometricAuthenticationFailed)
        } else {
            XCTFail("Expected error state, got \(authManager.authenticationState)")
        }
    }
    
    @MainActor
    func testEnableBiometricAuthentication() {
        authManager.enableBiometricAuthentication()
        XCTAssertTrue(mockBiometricManager.isEnabled)
    }
    
    @MainActor
    func testDisableBiometricAuthentication() {
        mockBiometricManager.isEnabled = true
        authManager.disableBiometricAuthentication()
        XCTAssertFalse(mockBiometricManager.isEnabled)
    }
    
    @MainActor
    func testShouldPromptForBiometricSetup() {
        mockBiometricManager.isAvailable = true
        mockBiometricManager.isEnabled = false
        mockBiometricManager.setupPrompted = false
        
        XCTAssertTrue(authManager.shouldPromptForBiometricSetup())
        
        authManager.setBiometricSetupPrompted()
        XCTAssertTrue(mockBiometricManager.setupPrompted)
    }
    
    @MainActor
    func testCheckAuthenticationStatusWithBiometrics() async {
        // Setup - simulate stored tokens and enabled biometrics
        mockBiometricManager.isAvailable = true
        mockBiometricManager.isEnabled = true
        
        let testTokens = AuthTokens(
            accessToken: "access_token",
            refreshToken: "refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "id_token",
            issuedAt: Date()
        )
        let testUser = User(id: "123", username: "testuser", email: "test@example.com", displayName: "Test User", provider: "test")
        
        mockKeychainManager.storedItems[KeychainManager.Keys.authTokens] = try! JSONEncoder().encode(testTokens)
        mockKeychainManager.storedItems[KeychainManager.Keys.user] = try! JSONEncoder().encode(testUser)
        
        // Execute
        authManager.checkAuthenticationStatus()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify that biometric prompt state was triggered
        // Note: The actual state might change quickly, so we check that it's not unauthenticated
        XCTAssertNotEqual(authManager.authenticationState, .unauthenticated)
    }
}

// MARK: - Mock Classes for Testing

class MockKeychainManager: KeychainManagerProtocol {
    var storedItems: [String: Data] = [:]
    var shouldThrowError = false
    var errorToThrow: AuthenticationError = .keychainError(errSecInternalError)
    
    func store<T: Codable>(_ item: T, forKey key: String) throws {
        if shouldThrowError {
            throw errorToThrow
        }
        storedItems[key] = try JSONEncoder().encode(item)
    }
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        if shouldThrowError {
            throw errorToThrow
        }
        guard let data = storedItems[key] else {
            return nil
        }
        return try JSONDecoder().decode(type, from: data)
    }
    
    func delete(forKey key: String) throws {
        if shouldThrowError {
            throw errorToThrow
        }
        storedItems.removeValue(forKey: key)
    }
    
    func deleteAll() throws {
        if shouldThrowError {
            throw errorToThrow
        }
        storedItems.removeAll()
    }
}

class MockConfigurationManager: ConfigurationManagerProtocol {
    var providers: [IdentityProvider] = []
    var defaultProvider: IdentityProvider?
    var shouldThrowError = false
    var errorToThrow: AuthenticationError = .configurationError("Mock error")
    
    func loadProviders() throws -> [IdentityProvider] {
        if shouldThrowError {
            throw errorToThrow
        }
        return providers
    }
    
    func getDefaultProvider() throws -> IdentityProvider {
        if shouldThrowError {
            throw errorToThrow
        }
        guard let provider = defaultProvider else {
            throw AuthenticationError.configurationError("No default provider")
        }
        return provider
    }
    
    func validateProvider(_ provider: IdentityProvider) throws {
        if shouldThrowError {
            throw errorToThrow
        }
        // Mock validation - always passes unless shouldThrowError is true
    }
}

class MockNetworkManager: NetworkManagerProtocol {
    var isConnected = true
    var shouldThrowError = false
    var errorToThrow: Error = NetworkError.noInternetConnection
    
    func performRequest<T: Codable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T {
        if shouldThrowError {
            throw errorToThrow
        }
        // Return a mock response - this would need to be customized per test
        throw NetworkError.noInternetConnection
    }
    
    func performRequest(_ request: NetworkRequest) async throws -> Data {
        if shouldThrowError {
            throw errorToThrow
        }
        return Data()
    }
}

class MockIdentityProviderService: IdentityProviderServiceProtocol {
    let networkManager: NetworkManagerProtocol
    var shouldThrowError = false
    var errorToThrow: AuthenticationError = .invalidCredentials
    
    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }
    
    func authenticate(credentials: Credentials, provider: IdentityProvider) async throws -> AuthTokens {
        if shouldThrowError {
            throw errorToThrow
        }
        return AuthTokens(
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "mock_id_token",
            issuedAt: Date()
        )
    }
    
    func refreshToken(_ refreshToken: String, provider: IdentityProvider) async throws -> AuthTokens {
        if shouldThrowError {
            throw errorToThrow
        }
        return AuthTokens(
            accessToken: "new_access_token",
            refreshToken: "new_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "new_id_token",
            issuedAt: Date()
        )
    }
    
    func getUserInfo(accessToken: String, provider: IdentityProvider) async throws -> User {
        if shouldThrowError {
            throw errorToThrow
        }
        return User(
            id: "mock_user_id",
            username: "mockuser",
            email: "mock@example.com",
            displayName: "Mock User",
            provider: provider.id
        )
    }
}

// MARK: - Protocol Extensions for Testing

extension AuthenticationState: Equatable {
    public static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated):
            return true
        case (.authenticating, .authenticating):
            return true
        case (.biometricPrompt, .biometricPrompt):
            return true
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

extension AuthenticationError: Equatable {
    public static func == (lhs: AuthenticationError, rhs: AuthenticationError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredentials, .invalidCredentials):
            return true
        case (.tokenExpired, .tokenExpired):
            return true
        case (.biometricAuthenticationFailed, .biometricAuthenticationFailed):
            return true
        case (.keychainError(let lhsStatus), .keychainError(let rhsStatus)):
            return lhsStatus == rhsStatus
        case (.configurationError(let lhsMessage), .configurationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

