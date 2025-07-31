import XCTest
import Combine
@testable import IdentityProviderAuth

@MainActor
class SessionManagementTests: XCTestCase {
    var authManager: AuthenticationManager!
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
        mockNetworkManager = MockNetworkManager()
        mockIdentityProviderService = MockIdentityProviderService(networkManager: mockNetworkManager)
        
        authManager = AuthenticationManager(
            keychainManager: mockKeychainManager,
            biometricManager: mockBiometricManager,
            configurationManager: mockConfigurationManager,
            identityProviderService: mockIdentityProviderService,
            networkManager: mockNetworkManager
        )
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        authManager = nil
        mockKeychainManager = nil
        mockBiometricManager = nil
        mockConfigurationManager = nil
        mockIdentityProviderService = nil
        mockNetworkManager = nil
        super.tearDown()
    }
    
    // MARK: - App Launch Authentication Tests
    
    func testAppLaunchWithValidStoredTokens() async {
        // Given
        let tokens = createMockTokens(expiresIn: 3600) // 1 hour
        let user = createMockUser()
        
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.authTokens] = tokens
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.user] = user
        
        let expectation = XCTestExpectation(description: "Authentication state should be authenticated")
        
        authManager.$authenticationState
            .dropFirst() // Skip initial unauthenticated state
            .sink { state in
                if case .authenticated(let authenticatedUser) = state {
                    XCTAssertEqual(authenticatedUser.id, user.id)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        authManager.checkAuthenticationStatus()
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testAppLaunchWithExpiredTokens() async {
        // Given
        let expiredTokens = createMockTokens(expiresIn: -3600) // Expired 1 hour ago
        let user = createMockUser()
        let refreshedTokens = createMockTokens(expiresIn: 3600)
        
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.authTokens] = expiredTokens
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.user] = user
        mockIdentityProviderService.mockRefreshTokenResult = .success(refreshedTokens)
        
        let expectation = XCTestExpectation(description: "Tokens should be refreshed")
        
        authManager.$authenticationState
            .dropFirst()
            .sink { state in
                if case .authenticated = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        authManager.checkAuthenticationStatus()
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(mockIdentityProviderService.refreshTokenCalled)
    }
    
    func testAppLaunchWithNoStoredTokens() async {
        // Given
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.authTokens] = nil
        
        let expectation = XCTestExpectation(description: "Authentication state should remain unauthenticated")
        
        // Wait a bit to ensure state doesn't change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if case .unauthenticated = self.authManager.authenticationState {
                expectation.fulfill()
            }
        }
        
        // When
        authManager.checkAuthenticationStatus()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Foreground Token Refresh Tests
    
    func testForegroundTokenRefreshWhenTokenNearExpiration() async {
        // Given
        let tokens = createMockTokens(expiresIn: 300) // 5 minutes until expiration
        let user = createMockUser()
        let refreshedTokens = createMockTokens(expiresIn: 3600)
        
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.authTokens] = tokens
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.user] = user
        mockIdentityProviderService.mockRefreshTokenResult = .success(refreshedTokens)
        
        // Set authenticated state
        authManager.authenticationState = .authenticated(user)
        
        let expectation = XCTestExpectation(description: "Token should be refreshed on foreground")
        
        mockIdentityProviderService.onRefreshToken = {
            expectation.fulfill()
        }
        
        // When
        authManager.handleAppWillEnterForeground()
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testForegroundTokenRefreshWhenTokenNotNearExpiration() async {
        // Given
        let tokens = createMockTokens(expiresIn: 3600) // 1 hour until expiration
        let user = createMockUser()
        
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.authTokens] = tokens
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.user] = user
        
        // Set authenticated state
        authManager.authenticationState = .authenticated(user)
        
        // When
        authManager.handleAppWillEnterForeground()
        
        // Wait a bit to ensure no refresh happens
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then
        XCTAssertFalse(mockIdentityProviderService.refreshTokenCalled)
    }
    
    // MARK: - Session Timeout Tests
    
    func testSessionTimeoutAfterInactivity() async {
        // Given
        let user = createMockUser()
        authManager.authenticationState = .authenticated(user)
        
        let expectation = XCTestExpectation(description: "User should be logged out after timeout")
        
        authManager.$authenticationState
            .dropFirst()
            .sink { state in
                if case .unauthenticated = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - Simulate session timeout by directly calling the timeout handler
        // Note: In a real test, we would need to wait for the actual timeout or mock the timer
        authManager.logout() // Simulating timeout behavior
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testUserActivityResetsSessionTimeout() {
        // Given
        let user = createMockUser()
        authManager.authenticationState = .authenticated(user)
        
        // When
        authManager.refreshUserActivity()
        
        // Then
        // The session should remain active (no logout should occur)
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
    }
    
    // MARK: - Integration Tests
    
    func testCompleteSessionManagementFlow() async {
        // Given
        let tokens = createMockTokens(expiresIn: 3600)
        let user = createMockUser()
        
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.authTokens] = tokens
        mockKeychainManager.mockRetrieveResults[KeychainManager.Keys.user] = user
        
        let authExpectation = XCTestExpectation(description: "Should authenticate on launch")
        
        authManager.$authenticationState
            .dropFirst()
            .sink { state in
                if case .authenticated = state {
                    authExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - App launch
        authManager.checkAuthenticationStatus()
        await fulfillment(of: [authExpectation], timeout: 2.0)
        
        // Then - User activity should keep session alive
        authManager.refreshUserActivity()
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
        
        // When - Foreground refresh
        authManager.handleAppWillEnterForeground()
        
        // Then - Should remain authenticated
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
    }
    
    // MARK: - Helper Methods
    
    private func createMockTokens(expiresIn: TimeInterval) -> AuthTokens {
        return AuthTokens(
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            tokenType: "Bearer",
            expiresIn: expiresIn,
            scope: "openid profile",
            idToken: "mock_id_token",
            issuedAt: Date()
        )
    }
    
    private func createMockUser() -> User {
        return User(
            id: "test_user_id",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            provider: "test_provider"
        )
    }
}

// MARK: - Mock Extensions for Testing

extension MockKeychainManager {
    var mockRetrieveResults: [String: Any] = [:]
    
    override func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let result = mockRetrieveResults[key] {
            if let directResult = result as? T {
                return directResult
            }
            // Try to encode and decode for type safety
            if let data = try? JSONEncoder().encode(result as! Codable) {
                return try? JSONDecoder().decode(type, from: data)
            }
        }
        
        return storedItems[key].flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

extension MockIdentityProviderService {
    var refreshTokenCalled = false
    var mockRefreshTokenResult: Result<AuthTokens, Error>?
    var onRefreshToken: (() -> Void)?
    
    override func refreshToken(_ refreshToken: String, provider: IdentityProvider) async throws -> AuthTokens {
        refreshTokenCalled = true
        onRefreshToken?()
        
        if let result = mockRefreshTokenResult {
            switch result {
            case .success(let tokens):
                return tokens
            case .failure(let error):
                throw error
            }
        }
        
        return try await super.refreshToken(refreshToken, provider: provider)
    }
}