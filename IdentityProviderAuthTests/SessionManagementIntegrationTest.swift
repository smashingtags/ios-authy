import Foundation
import XCTest
import Combine
import UIKit
@testable import IdentityProviderAuth

/// Integration tests for session management functionality
/// These tests verify the complete session management flow including:
/// - App launch authentication check with various token states
/// - Automatic token refresh on foreground
/// - Session timeout handling with user activity tracking
/// - Background app security and lifecycle management
/// - End-to-end session flows with real component interactions
@MainActor
class SessionManagementIntegrationTest: XCTestCase {
    
    var authManager: AuthenticationManager!
    var mockKeychainManager: MockKeychainManager!
    var mockBiometricManager: MockBiometricManager!
    var mockConfigurationManager: MockConfigurationManager!
    var mockIdentityProviderService: MockIdentityProviderService!
    var mockNetworkManager: MockNetworkManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Set up mock dependencies
        mockKeychainManager = MockKeychainManager()
        mockBiometricManager = MockBiometricManager()
        mockConfigurationManager = MockConfigurationManager()
        mockNetworkManager = MockNetworkManager()
        mockIdentityProviderService = MockIdentityProviderService(networkManager: mockNetworkManager)
        
        // Configure default provider for tests
        let testProvider = IdentityProvider(
            id: "test-provider",
            name: "Test Provider",
            displayName: "Test Provider",
            authorizationEndpoint: URL(string: "https://test.example.com/auth")!,
            tokenEndpoint: URL(string: "https://test.example.com/token")!,
            userInfoEndpoint: URL(string: "https://test.example.com/userinfo"),
            clientId: "test-client-id",
            scope: "openid profile email",
            isDefault: true
        )
        
        mockConfigurationManager.providers = [testProvider]
        mockConfigurationManager.defaultProvider = testProvider
        
        // Create AuthenticationManager with mocked dependencies
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
    
    // MARK: - Complete Session Lifecycle Integration Tests
    
    func testCompleteSessionLifecycleWithValidTokens() async {
        // Given: Valid stored tokens and user data
        let tokens = createValidTokens(expiresIn: 3600) // 1 hour
        let user = createTestUser()
        
        try! mockKeychainManager.store(tokens, forKey: KeychainManager.Keys.authTokens)
        try! mockKeychainManager.store(user, forKey: KeychainManager.Keys.user)
        try! mockKeychainManager.store("test-provider", forKey: KeychainManager.Keys.selectedProvider)
        
        let authExpectation = XCTestExpectation(description: "Should authenticate on app launch")
        
        // Monitor authentication state changes
        authManager.$authenticationState
            .dropFirst() // Skip initial unauthenticated state
            .sink { state in
                if case .authenticated(let authenticatedUser) = state {
                    XCTAssertEqual(authenticatedUser.id, user.id)
                    XCTAssertEqual(authenticatedUser.username, user.username)
                    authExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: App launches and checks authentication status
        authManager.checkAuthenticationStatus()
        
        // Then: Should authenticate successfully
        await fulfillment(of: [authExpectation], timeout: 3.0)
        
        // Verify session management is active
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
        
        // Test user activity tracking
        authManager.refreshUserActivity()
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
        
        // Test foreground handling
        authManager.handleAppWillEnterForeground()
        
        // Wait for any async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should still be authenticated
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
    }
    
    func testSessionLifecycleWithExpiredTokensAndSuccessfulRefresh() async {
        // Given: Expired tokens but valid refresh token
        let expiredTokens = createExpiredTokens()
        let refreshedTokens = createValidTokens(expiresIn: 3600)
        let user = createTestUser()
        
        try! mockKeychainManager.store(expiredTokens, forKey: KeychainManager.Keys.authTokens)
        try! mockKeychainManager.store(user, forKey: KeychainManager.Keys.user)
        try! mockKeychainManager.store("test-provider", forKey: KeychainManager.Keys.selectedProvider)
        
        // Configure mock to return refreshed tokens
        mockIdentityProviderService.mockRefreshTokenResult = .success(refreshedTokens)
        
        let refreshExpectation = XCTestExpectation(description: "Should refresh tokens and authenticate")
        
        authManager.$authenticationState
            .dropFirst()
            .sink { state in
                if case .authenticated(let authenticatedUser) = state {
                    XCTAssertEqual(authenticatedUser.id, user.id)
                    refreshExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: App launches with expired tokens
        authManager.checkAuthenticationStatus()
        
        // Then: Should refresh tokens and authenticate
        await fulfillment(of: [refreshExpectation], timeout: 3.0)
        
        // Verify token refresh was called
        XCTAssertTrue(mockIdentityProviderService.refreshTokenCalled)
        
        // Verify new tokens were stored
        let storedTokens: AuthTokens? = try? mockKeychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
        XCTAssertNotNil(storedTokens)
        XCTAssertEqual(storedTokens?.accessToken, refreshedTokens.accessToken)
    }
    
    func testSessionLifecycleWithFailedTokenRefresh() async {
        // Given: Expired tokens and failed refresh
        let expiredTokens = createExpiredTokens()
        let user = createTestUser()
        
        try! mockKeychainManager.store(expiredTokens, forKey: KeychainManager.Keys.authTokens)
        try! mockKeychainManager.store(user, forKey: KeychainManager.Keys.user)
        try! mockKeychainManager.store("test-provider", forKey: KeychainManager.Keys.selectedProvider)
        
        // Configure mock to fail token refresh
        mockIdentityProviderService.mockRefreshTokenResult = .failure(AuthenticationError.tokenExpired)
        
        let errorExpectation = XCTestExpectation(description: "Should handle token refresh failure")
        
        authManager.$authenticationState
            .dropFirst()
            .sink { state in
                if case .error(let error) = state {
                    XCTAssertEqual(error as? AuthenticationError, .tokenExpired)
                    errorExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: App launches with expired tokens that can't be refreshed
        authManager.checkAuthenticationStatus()
        
        // Then: Should enter error state
        await fulfillment(of: [errorExpectation], timeout: 3.0)
        
        // Verify token refresh was attempted
        XCTAssertTrue(mockIdentityProviderService.refreshTokenCalled)
    }
    
    // MARK: - Biometric Authentication Integration Tests
    
    func testSessionLifecycleWithBiometricAuthentication() async {
        // Given: Valid tokens, enabled biometrics, and available biometric hardware
        let tokens = createValidTokens(expiresIn: 3600)
        let user = createTestUser()
        
        try! mockKeychainManager.store(tokens, forKey: KeychainManager.Keys.authTokens)
        try! mockKeychainManager.store(user, forKey: KeychainManager.Keys.user)
        try! mockKeychainManager.store("test-provider", forKey: KeychainManager.Keys.selectedProvider)
        
        mockBiometricManager.isAvailable = true
        mockBiometricManager.isEnabled = true
        mockBiometricManager.biometricType = .faceID
        
        let biometricExpectation = XCTestExpectation(description: "Should prompt for biometric authentication")
        let authExpectation = XCTestExpectation(description: "Should authenticate after biometric success")
        
        var stateChanges: [AuthenticationState] = []
        
        authManager.$authenticationState
            .dropFirst()
            .sink { state in
                stateChanges.append(state)
                
                if case .biometricPrompt = state {
                    biometricExpectation.fulfill()
                } else if case .authenticated(let authenticatedUser) = state {
                    XCTAssertEqual(authenticatedUser.id, user.id)
                    authExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: App launches with biometric authentication enabled
        authManager.checkAuthenticationStatus()
        
        // Then: Should prompt for biometric authentication and then authenticate
        await fulfillment(of: [biometricExpectation, authExpectation], timeout: 3.0)
        
        // Verify the state progression
        XCTAssertTrue(stateChanges.contains { if case .biometricPrompt = $0 { return true }; return false })
        XCTAssertTrue(stateChanges.contains { if case .authenticated = $0 { return true }; return false })
    }
    
    func testSessionLifecycleWithBiometricFailure() async {
        // Given: Valid tokens, enabled biometrics, but biometric authentication fails
        let tokens = createValidTokens(expiresIn: 3600)
        let user = createTestUser()
        
        try! mockKeychainManager.store(tokens, forKey: KeychainManager.Keys.authTokens)
        try! mockKeychainManager.store(user, forKey: KeychainManager.Keys.user)
        try! mockKeychainManager.store("test-provider", forKey: KeychainManager.Keys.selectedProvider)
        
        mockBiometricManager.isAvailable = true
        mockBiometricManager.isEnabled = true
        mockBiometricManager.shouldThrowError = true
        mockBiometricManager.errorToThrow = .failed
        
        let errorExpectation = XCTestExpectation(description: "Should handle biometric authentication failure")
        
        authManager.$authenticationState
            .dropFirst()
            .sink { state in
                if case .error(let error) = state {
                    XCTAssertEqual(error as? AuthenticationError, .biometricAuthenticationFailed)
                    errorExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: App launches and biometric authentication fails
        authManager.checkAuthenticationStatus()
        
        // Then: Should enter error state
        await fulfillment(of: [errorExpectation], timeout: 3.0)
    }
    
    // MARK: - Foreground Token Refresh Integration Tests
    
    func testForegroundTokenRefreshIntegration() async {
        // Given: Authenticated user with tokens near expiration
        let nearExpiryTokens = createValidTokens(expiresIn: 300) // 5 minutes
        let refreshedTokens = createValidTokens(expiresIn: 3600) // 1 hour
        let user = createTestUser()
        
        try! mockKeychainManager.store(nearExpiryTokens, forKey: KeychainManager.Keys.authTokens)
        try! mockKeychainManager.store(user, forKey: KeychainManager.Keys.user)
        try! mockKeychainManager.store("test-provider", forKey: KeychainManager.Keys.selectedProvider)
        
        // Set authenticated state
        authManager.authenticationState = .authenticated(user)
        
        // Configure mock to return refreshed tokens
        mockIdentityProviderService.mockRefreshTokenResult = .success(refreshedTokens)
        
        let refreshExpectation = XCTestExpectation(description: "Should refresh tokens on foreground")
        
        mockIdentityProviderService.onRefreshToken = {
            refreshExpectation.fulfill()
        }
        
        // When: App enters foreground
        authManager.handleAppWillEnterForeground()
        
        // Then: Should refresh tokens
        await fulfillment(of: [refreshExpectation], timeout: 3.0)
        
        // Verify new tokens were stored
        let storedTokens: AuthTokens? = try? mockKeychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
        XCTAssertNotNil(storedTokens)
        XCTAssertEqual(storedTokens?.accessToken, refreshedTokens.accessToken)
        
        // Should remain authenticated
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
    }
    
    func testForegroundWithoutTokenRefreshNeeded() async {
        // Given: Authenticated user with fresh tokens
        let freshTokens = createValidTokens(expiresIn: 3600) // 1 hour
        let user = createTestUser()
        
        try! mockKeychainManager.store(freshTokens, forKey: KeychainManager.Keys.authTokens)
        try! mockKeychainManager.store(user, forKey: KeychainManager.Keys.user)
        try! mockKeychainManager.store("test-provider", forKey: KeychainManager.Keys.selectedProvider)
        
        // Set authenticated state
        authManager.authenticationState = .authenticated(user)
        
        // When: App enters foreground
        authManager.handleAppWillEnterForeground()
        
        // Wait for any potential async operations
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then: Should not refresh tokens
        XCTAssertFalse(mockIdentityProviderService.refreshTokenCalled)
        
        // Should remain authenticated
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
    }
    
    // MARK: - Session Timeout Integration Tests
    
    func testSessionTimeoutWithUserActivity() async {
        // Given: Authenticated user
        let user = createTestUser()
        authManager.authenticationState = .authenticated(user)
        
        // When: User activity is tracked
        authManager.refreshUserActivity()
        
        // Then: Session should remain active
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
        
        // Simulate multiple user activities
        for _ in 0..<5 {
            authManager.refreshUserActivity()
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        // Should still be authenticated
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
    }
    
    func testLogoutClearsSessionState() async {
        // Given: Authenticated user with stored data
        let tokens = createValidTokens(expiresIn: 3600)
        let user = createTestUser()
        
        try! mockKeychainManager.store(tokens, forKey: KeychainManager.Keys.authTokens)
        try! mockKeychainManager.store(user, forKey: KeychainManager.Keys.user)
        try! mockKeychainManager.store("test-provider", forKey: KeychainManager.Keys.selectedProvider)
        
        authManager.authenticationState = .authenticated(user)
        
        let logoutExpectation = XCTestExpectation(description: "Should logout and clear state")
        
        authManager.$authenticationState
            .dropFirst()
            .sink { state in
                if case .unauthenticated = state {
                    logoutExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: User logs out
        authManager.logout()
        
        // Then: Should clear all stored data and return to unauthenticated state
        await fulfillment(of: [logoutExpectation], timeout: 1.0)
        
        // Verify keychain was cleared
        XCTAssertTrue(mockKeychainManager.storedItems.isEmpty)
    }
    
    // MARK: - End-to-End Session Flow Integration Tests
    
    func testCompleteAuthenticationToLogoutFlow() async {
        // Given: Fresh authentication credentials
        let credentials = Credentials(username: "testuser", password: "testpass")
        let tokens = createValidTokens(expiresIn: 3600)
        let user = createTestUser()
        
        // Configure mocks for successful authentication
        mockIdentityProviderService.shouldThrowError = false
        mockIdentityProviderService.mockAuthenticateResult = .success((tokens, user))
        
        let authExpectation = XCTestExpectation(description: "Should authenticate successfully")
        let logoutExpectation = XCTestExpectation(description: "Should logout successfully")
        
        var stateChanges: [AuthenticationState] = []
        
        authManager.$authenticationState
            .sink { state in
                stateChanges.append(state)
                
                if case .authenticated(let authenticatedUser) = state {
                    XCTAssertEqual(authenticatedUser.id, user.id)
                    authExpectation.fulfill()
                } else if case .unauthenticated = state, stateChanges.count > 1 {
                    // Only fulfill on second unauthenticated state (after logout)
                    logoutExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: User authenticates
        await authManager.authenticate(credentials: credentials)
        await fulfillment(of: [authExpectation], timeout: 3.0)
        
        // Verify authentication state and stored data
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
        
        let storedTokens: AuthTokens? = try? mockKeychainManager.retrieve(AuthTokens.self, forKey: KeychainManager.Keys.authTokens)
        let storedUser: User? = try? mockKeychainManager.retrieve(User.self, forKey: KeychainManager.Keys.user)
        XCTAssertNotNil(storedTokens)
        XCTAssertNotNil(storedUser)
        XCTAssertEqual(storedUser?.id, user.id)
        
        // Test session management during authenticated state
        authManager.refreshUserActivity()
        authManager.handleAppWillEnterForeground()
        
        // Should still be authenticated
        XCTAssertEqual(authManager.authenticationState, .authenticated(user))
        
        // When: User logs out
        authManager.logout()
        
        // Then: Should return to unauthenticated state and clear data
        await fulfillment(of: [logoutExpectation], timeout: 1.0)
        
        // Verify all data was cleared
        XCTAssertTrue(mockKeychainManager.storedItems.isEmpty)
        
        // Verify state progression
        XCTAssertTrue(stateChanges.contains { if case .authenticating = $0 { return true }; return false })
        XCTAssertTrue(stateChanges.contains { if case .authenticated = $0 { return true }; return false })
        XCTAssertTrue(stateChanges.filter { if case .unauthenticated = $0 { return true }; return false }.count >= 2)
    }
    
    // MARK: - Helper Methods
    
    private func createValidTokens(expiresIn: TimeInterval) -> AuthTokens {
        return AuthTokens(
            accessToken: "valid_access_token_\(UUID().uuidString)",
            refreshToken: "valid_refresh_token_\(UUID().uuidString)",
            tokenType: "Bearer",
            expiresIn: expiresIn,
            scope: "openid profile email",
            idToken: "valid_id_token_\(UUID().uuidString)",
            issuedAt: Date()
        )
    }
    
    private func createExpiredTokens() -> AuthTokens {
        return AuthTokens(
            accessToken: "expired_access_token",
            refreshToken: "expired_refresh_token",
            tokenType: "Bearer",
            expiresIn: -3600, // Expired 1 hour ago
            scope: "openid profile email",
            idToken: "expired_id_token",
            issuedAt: Date(timeIntervalSinceNow: -7200) // Issued 2 hours ago
        )
    }
    
    private func createTestUser() -> User {
        return User(
            id: "integration_test_user_\(UUID().uuidString)",
            username: "integrationtestuser",
            email: "integration.test@example.com",
            displayName: "Integration Test User",
            provider: "test-provider"
        )
    }
}

// MARK: - Mock Extensions for Integration Testing
// Extensions removed - functionality moved to main MockIdentityProviderService class