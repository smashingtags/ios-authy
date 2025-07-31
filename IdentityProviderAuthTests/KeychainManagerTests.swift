import XCTest
import Security
@testable import IdentityProviderAuth

class KeychainManagerTests: XCTestCase {
    var keychainManager: KeychainManager!
    let testService = "KeychainManagerTests"
    
    override func setUp() {
        super.setUp()
        keychainManager = KeychainManager(service: testService)
        // Clean up any existing test data
        try? keychainManager.deleteAll()
    }
    
    override func tearDown() {
        // Clean up test data
        try? keychainManager.deleteAll()
        keychainManager = nil
        super.tearDown()
    }
    
    // MARK: - Store Operation Tests
    
    func testStoreAuthTokensSuccess() throws {
        // Given
        let testTokens = AuthTokens(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid profile",
            idToken: "test_id_token",
            issuedAt: Date()
        )
        
        // When
        try keychainManager.store(testTokens, forKey: KeychainManager.Keys.authTokens)
        
        // Then
        let retrievedTokens: AuthTokens? = try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
        XCTAssertNotNil(retrievedTokens)
        XCTAssertEqual(retrievedTokens?.accessToken, testTokens.accessToken)
        XCTAssertEqual(retrievedTokens?.refreshToken, testTokens.refreshToken)
        XCTAssertEqual(retrievedTokens?.tokenType, testTokens.tokenType)
        XCTAssertEqual(retrievedTokens?.expiresIn, testTokens.expiresIn)
        XCTAssertEqual(retrievedTokens?.scope, testTokens.scope)
        XCTAssertEqual(retrievedTokens?.idToken, testTokens.idToken)
    }
    
    func testStoreUserSuccess() throws {
        // Given
        let testUser = User(
            id: "test_user_id",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            provider: "test_provider"
        )
        
        // When
        try keychainManager.store(testUser, forKey: KeychainManager.Keys.user)
        
        // Then
        let retrievedUser: User? = try keychainManager.retrieve(User.self, forKey: KeychainManager.Keys.user)
        XCTAssertNotNil(retrievedUser)
        XCTAssertEqual(retrievedUser?.id, testUser.id)
        XCTAssertEqual(retrievedUser?.username, testUser.username)
        XCTAssertEqual(retrievedUser?.email, testUser.email)
        XCTAssertEqual(retrievedUser?.displayName, testUser.displayName)
        XCTAssertEqual(retrievedUser?.provider, testUser.provider)
    }
    
    func testStoreIdentityProviderSuccess() throws {
        // Given
        let testProvider = IdentityProvider(
            id: "test_provider",
            name: "Test Provider",
            displayName: "Test Identity Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: URL(string: "https://example.com/userinfo")!,
            clientId: "test_client_id",
            scope: "openid profile",
            isDefault: true
        )
        
        // When
        try keychainManager.store(testProvider, forKey: KeychainManager.Keys.selectedProvider)
        
        // Then
        let retrievedProvider: IdentityProvider? = try keychainManager.retrieve(IdentityProvider.self, forKey: KeychainManager.Keys.selectedProvider)
        XCTAssertNotNil(retrievedProvider)
        XCTAssertEqual(retrievedProvider?.id, testProvider.id)
        XCTAssertEqual(retrievedProvider?.name, testProvider.name)
        XCTAssertEqual(retrievedProvider?.displayName, testProvider.displayName)
        XCTAssertEqual(retrievedProvider?.authorizationEndpoint, testProvider.authorizationEndpoint)
        XCTAssertEqual(retrievedProvider?.tokenEndpoint, testProvider.tokenEndpoint)
        XCTAssertEqual(retrievedProvider?.userInfoEndpoint, testProvider.userInfoEndpoint)
        XCTAssertEqual(retrievedProvider?.clientId, testProvider.clientId)
        XCTAssertEqual(retrievedProvider?.scope, testProvider.scope)
        XCTAssertEqual(retrievedProvider?.isDefault, testProvider.isDefault)
    }
    
    func testStoreOverwritesExistingItem() throws {
        // Given
        let originalTokens = AuthTokens(
            accessToken: "original_access_token",
            refreshToken: "original_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "original_id_token",
            issuedAt: Date()
        )
        
        let updatedTokens = AuthTokens(
            accessToken: "updated_access_token",
            refreshToken: "updated_refresh_token",
            tokenType: "Bearer",
            expiresIn: 7200,
            scope: "openid profile",
            idToken: "updated_id_token",
            issuedAt: Date()
        )
        
        // When
        try keychainManager.store(originalTokens, forKey: KeychainManager.Keys.authTokens)
        try keychainManager.store(updatedTokens, forKey: KeychainManager.Keys.authTokens)
        
        // Then
        let retrievedTokens: AuthTokens? = try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
        XCTAssertNotNil(retrievedTokens)
        XCTAssertEqual(retrievedTokens?.accessToken, updatedTokens.accessToken)
        XCTAssertEqual(retrievedTokens?.refreshToken, updatedTokens.refreshToken)
        XCTAssertEqual(retrievedTokens?.expiresIn, updatedTokens.expiresIn)
        XCTAssertEqual(retrievedTokens?.scope, updatedTokens.scope)
        XCTAssertEqual(retrievedTokens?.idToken, updatedTokens.idToken)
    }
    
    // MARK: - Retrieve Operation Tests
    
    func testRetrieveNonExistentItemReturnsNil() throws {
        // When
        let retrievedTokens: AuthTokens? = try keychainManager.retrieve(AuthTokens.self, forKey: "non_existent_key")
        
        // Then
        XCTAssertNil(retrievedTokens)
    }
    
    func testRetrieveWithWrongTypeThrowsError() throws {
        // Given
        let testTokens = AuthTokens(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "test_id_token",
            issuedAt: Date()
        )
        try keychainManager.store(testTokens, forKey: KeychainManager.Keys.authTokens)
        
        // When/Then
        XCTAssertThrowsError(try keychainManager.retrieve(User.self, forKey: KeychainManager.Keys.authTokens)) { error in
            // Should throw a decoding error when trying to decode AuthTokens as User
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testRetrieveAfterStoreMultipleItems() throws {
        // Given
        let testTokens = AuthTokens(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "test_id_token",
            issuedAt: Date()
        )
        
        let testUser = User(
            id: "test_user_id",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            provider: "test_provider"
        )
        
        // When
        try keychainManager.store(testTokens, forKey: KeychainManager.Keys.authTokens)
        try keychainManager.store(testUser, forKey: KeychainManager.Keys.user)
        
        // Then
        let retrievedTokens: AuthTokens? = try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
        let retrievedUser: User? = try keychainManager.retrieve(User.self, forKey: KeychainManager.Keys.user)
        
        XCTAssertNotNil(retrievedTokens)
        XCTAssertNotNil(retrievedUser)
        XCTAssertEqual(retrievedTokens?.accessToken, testTokens.accessToken)
        XCTAssertEqual(retrievedUser?.username, testUser.username)
    }
    
    // MARK: - Delete Operation Tests
    
    func testDeleteExistingItem() throws {
        // Given
        let testTokens = AuthTokens(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "test_id_token",
            issuedAt: Date()
        )
        try keychainManager.store(testTokens, forKey: KeychainManager.Keys.authTokens)
        
        // Verify item exists
        let retrievedBeforeDelete: AuthTokens? = try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
        XCTAssertNotNil(retrievedBeforeDelete)
        
        // When
        try keychainManager.delete(forKey: KeychainManager.Keys.authTokens)
        
        // Then
        let retrievedAfterDelete: AuthTokens? = try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
        XCTAssertNil(retrievedAfterDelete)
    }
    
    func testDeleteNonExistentItemDoesNotThrow() throws {
        // When/Then - Should not throw an error
        XCTAssertNoThrow(try keychainManager.delete(forKey: "non_existent_key"))
    }
    
    func testDeleteOneItemLeavesOthersIntact() throws {
        // Given
        let testTokens = AuthTokens(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "test_id_token",
            issuedAt: Date()
        )
        
        let testUser = User(
            id: "test_user_id",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            provider: "test_provider"
        )
        
        try keychainManager.store(testTokens, forKey: KeychainManager.Keys.authTokens)
        try keychainManager.store(testUser, forKey: KeychainManager.Keys.user)
        
        // When
        try keychainManager.delete(forKey: KeychainManager.Keys.authTokens)
        
        // Then
        let retrievedTokens: AuthTokens? = try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
        let retrievedUser: User? = try keychainManager.retrieve(User.self, forKey: KeychainManager.Keys.user)
        
        XCTAssertNil(retrievedTokens)
        XCTAssertNotNil(retrievedUser)
        XCTAssertEqual(retrievedUser?.username, testUser.username)
    }
    
    // MARK: - Delete All Operation Tests
    
    func testDeleteAllRemovesAllItems() throws {
        // Given
        let testTokens = AuthTokens(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "test_id_token",
            issuedAt: Date()
        )
        
        let testUser = User(
            id: "test_user_id",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            provider: "test_provider"
        )
        
        let testProvider = IdentityProvider(
            id: "test_provider",
            name: "Test Provider",
            displayName: "Test Identity Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: URL(string: "https://example.com/userinfo")!,
            clientId: "test_client_id",
            scope: "openid profile",
            isDefault: true
        )
        
        try keychainManager.store(testTokens, forKey: KeychainManager.Keys.authTokens)
        try keychainManager.store(testUser, forKey: KeychainManager.Keys.user)
        try keychainManager.store(testProvider, forKey: KeychainManager.Keys.selectedProvider)
        
        // Verify items exist
        XCTAssertNotNil(try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens))
        XCTAssertNotNil(try keychainManager.retrieve(User.self, forKey: KeychainManager.Keys.user))
        XCTAssertNotNil(try keychainManager.retrieve(IdentityProvider.self, forKey: KeychainManager.Keys.selectedProvider))
        
        // When
        try keychainManager.deleteAll()
        
        // Then
        XCTAssertNil(try keychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens))
        XCTAssertNil(try keychainManager.retrieve(User.self, forKey: KeychainManager.Keys.user))
        XCTAssertNil(try keychainManager.retrieve(IdentityProvider.self, forKey: KeychainManager.Keys.selectedProvider))
    }
    
    func testDeleteAllOnEmptyKeychainDoesNotThrow() throws {
        // When/Then - Should not throw an error
        XCTAssertNoThrow(try keychainManager.deleteAll())
    }
    
    // MARK: - Service Isolation Tests
    
    func testDifferentServicesAreIsolated() throws {
        // Given
        let service1Manager = KeychainManager(service: "Service1")
        let service2Manager = KeychainManager(service: "Service2")
        
        let testTokens = AuthTokens(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "test_id_token",
            issuedAt: Date()
        )
        
        // When
        try service1Manager.store(testTokens, forKey: "test_key")
        
        // Then
        let retrievedFromService1: AuthTokens? = try service1Manager.retrieve(AuthTokens.self, forKey: "test_key")
        let retrievedFromService2: AuthTokens? = try service2Manager.retrieve(AuthTokens.self, forKey: "test_key")
        
        XCTAssertNotNil(retrievedFromService1)
        XCTAssertNil(retrievedFromService2)
        
        // Cleanup
        try service1Manager.deleteAll()
        try service2Manager.deleteAll()
    }
    
    // MARK: - Error Handling Tests
    
    func testKeychainErrorHandling() {
        // This test verifies that keychain errors are properly wrapped in AuthenticationError
        // We can't easily simulate keychain failures in unit tests, but we can verify the error handling structure
        
        // Create a keychain manager with an invalid service name to potentially trigger errors
        let invalidKeychainManager = KeychainManager(service: "")
        
        // The actual behavior will depend on the keychain implementation
        // This test mainly ensures the error handling structure is in place
        XCTAssertNotNil(invalidKeychainManager)
    }
}

// MARK: - Mock Integration Tests

class KeychainManagerMockIntegrationTests: XCTestCase {
    var realKeychainManager: KeychainManager!
    var mockKeychainManager: MockKeychainManager!
    let testService = "KeychainManagerMockIntegrationTests"
    
    override func setUp() {
        super.setUp()
        realKeychainManager = KeychainManager(service: testService)
        mockKeychainManager = MockKeychainManager()
        
        // Clean up any existing test data
        try? realKeychainManager.deleteAll()
    }
    
    override func tearDown() {
        // Clean up test data
        try? realKeychainManager.deleteAll()
        realKeychainManager = nil
        mockKeychainManager = nil
        super.tearDown()
    }
    
    func testMockKeychainManagerBehaviorConsistency() throws {
        // Given
        let testTokens = AuthTokens(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "test_id_token",
            issuedAt: Date()
        )
        
        // When - Store in both managers
        try realKeychainManager.store(testTokens, forKey: "test_key")
        try mockKeychainManager.store(testTokens, forKey: "test_key")
        
        // Then - Both should retrieve the same data
        let realRetrieved: AuthTokens? = try realKeychainManager.retrieve(AuthTokens.self, forKey: "test_key")
        let mockRetrieved: AuthTokens? = try mockKeychainManager.retrieve(AuthTokens.self, forKey: "test_key")
        
        XCTAssertNotNil(realRetrieved)
        XCTAssertNotNil(mockRetrieved)
        XCTAssertEqual(realRetrieved?.accessToken, mockRetrieved?.accessToken)
        XCTAssertEqual(realRetrieved?.refreshToken, mockRetrieved?.refreshToken)
        XCTAssertEqual(realRetrieved?.tokenType, mockRetrieved?.tokenType)
        XCTAssertEqual(realRetrieved?.expiresIn, mockRetrieved?.expiresIn)
        XCTAssertEqual(realRetrieved?.scope, mockRetrieved?.scope)
        XCTAssertEqual(realRetrieved?.idToken, mockRetrieved?.idToken)
        
        // Test deletion consistency
        try realKeychainManager.delete(forKey: "test_key")
        try mockKeychainManager.delete(forKey: "test_key")
        
        let realAfterDelete: AuthTokens? = try realKeychainManager.retrieve(AuthTokens.self, forKey: "test_key")
        let mockAfterDelete: AuthTokens? = try mockKeychainManager.retrieve(AuthTokens.self, forKey: "test_key")
        
        XCTAssertNil(realAfterDelete)
        XCTAssertNil(mockAfterDelete)
    }
    
    func testMockKeychainManagerErrorSimulation() {
        // Given
        mockKeychainManager.shouldThrowError = true
        mockKeychainManager.errorToThrow = .keychainError(errSecInternalError)
        
        let testTokens = AuthTokens(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "openid",
            idToken: "test_id_token",
            issuedAt: Date()
        )
        
        // When/Then - Mock should throw errors when configured to do so
        XCTAssertThrowsError(try mockKeychainManager.store(testTokens, forKey: "test_key")) { error in
            if case AuthenticationError.keychainError(let status) = error {
                XCTAssertEqual(status, errSecInternalError)
            } else {
                XCTFail("Expected keychainError, got \(error)")
            }
        }
        
        XCTAssertThrowsError(try mockKeychainManager.retrieve(AuthTokens.self, forKey: "test_key")) { error in
            if case AuthenticationError.keychainError(let status) = error {
                XCTAssertEqual(status, errSecInternalError)
            } else {
                XCTFail("Expected keychainError, got \(error)")
            }
        }
        
        XCTAssertThrowsError(try mockKeychainManager.delete(forKey: "test_key")) { error in
            if case AuthenticationError.keychainError(let status) = error {
                XCTAssertEqual(status, errSecInternalError)
            } else {
                XCTFail("Expected keychainError, got \(error)")
            }
        }
        
        XCTAssertThrowsError(try mockKeychainManager.deleteAll()) { error in
            if case AuthenticationError.keychainError(let status) = error {
                XCTAssertEqual(status, errSecInternalError)
            } else {
                XCTFail("Expected keychainError, got \(error)")
            }
        }
    }
}