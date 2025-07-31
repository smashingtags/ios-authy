import XCTest
import Combine
@testable import IdentityProviderAuth

@MainActor
class LoginViewModelTests: XCTestCase {
    var loginViewModel: LoginViewModel!
    var mockAuthenticationManager: MockAuthenticationManagerForLogin!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        loginViewModel = LoginViewModel()
        mockAuthenticationManager = MockAuthenticationManagerForLogin()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        loginViewModel = nil
        mockAuthenticationManager = nil
        super.tearDown()
    }
    
    // MARK: - Form Validation Tests
    
    func testInitialState() {
        // Then
        XCTAssertEqual(loginViewModel.username, "")
        XCTAssertEqual(loginViewModel.password, "")
        XCTAssertNil(loginViewModel.errorMessage)
        XCTAssertFalse(loginViewModel.isLoading)
        XCTAssertFalse(loginViewModel.isLoginButtonEnabled)
    }
    
    func testLoginButtonEnabledWithValidInput() {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        
        // Then
        XCTAssertTrue(loginViewModel.isLoginButtonEnabled)
    }
    
    func testLoginButtonDisabledWithEmptyUsername() {
        // Given
        loginViewModel.username = ""
        loginViewModel.password = "testpass"
        
        // Then
        XCTAssertFalse(loginViewModel.isLoginButtonEnabled)
    }
    
    func testLoginButtonDisabledWithEmptyPassword() {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = ""
        
        // Then
        XCTAssertFalse(loginViewModel.isLoginButtonEnabled)
    }
    
    func testLoginButtonDisabledWithBothFieldsEmpty() {
        // Given
        loginViewModel.username = ""
        loginViewModel.password = ""
        
        // Then
        XCTAssertFalse(loginViewModel.isLoginButtonEnabled)
    }
    
    func testLoginButtonDisabledWhenLoading() {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        loginViewModel.isLoading = true
        
        // Then
        XCTAssertFalse(loginViewModel.isLoginButtonEnabled)
    }
    
    func testFormValidationWithWhitespaceOnlyInput() {
        // Given
        loginViewModel.username = "   "
        loginViewModel.password = "   "
        
        // Then
        XCTAssertFalse(loginViewModel.isLoginButtonEnabled)
    }
    
    func testFormValidationWithValidInputAfterTrimming() {
        // Given
        loginViewModel.username = "  testuser  "
        loginViewModel.password = "  testpass  "
        
        // Then
        XCTAssertTrue(loginViewModel.isLoginButtonEnabled)
    }
    
    // MARK: - Authentication Integration Tests
    
    func testLoginWithValidCredentials() async {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        mockAuthenticationManager.authenticationState = .unauthenticated
        
        var loadingStates: [Bool] = []
        loginViewModel.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
            }
            .store(in: &cancellables)
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertTrue(mockAuthenticationManager.authenticateCalled)
        XCTAssertEqual(mockAuthenticationManager.lastCredentials?.username, "testuser")
        XCTAssertEqual(mockAuthenticationManager.lastCredentials?.password, "testpass")
        XCTAssertNil(loginViewModel.errorMessage)
        
        // Verify loading states
        XCTAssertTrue(loadingStates.contains(false)) // Initial state
        XCTAssertTrue(loadingStates.contains(true))  // Loading state
        XCTAssertFalse(loginViewModel.isLoading)     // Final state
    }
    
    func testLoginWithInvalidCredentials() async {
        // Given
        loginViewModel.username = "invalid"
        loginViewModel.password = "invalid"
        mockAuthenticationManager.authenticationState = .error(.invalidCredentials)
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertTrue(mockAuthenticationManager.authenticateCalled)
        XCTAssertEqual(loginViewModel.errorMessage, "Invalid username or password")
        XCTAssertFalse(loginViewModel.isLoading)
    }
    
    func testLoginWithNetworkError() async {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        let networkError = NetworkError.noInternetConnection
        mockAuthenticationManager.authenticationState = .error(.networkError(networkError))
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertTrue(mockAuthenticationManager.authenticateCalled)
        XCTAssertNotNil(loginViewModel.errorMessage)
        XCTAssertTrue(loginViewModel.errorMessage!.contains("Network error"))
        XCTAssertFalse(loginViewModel.isLoading)
    }
    
    func testLoginWithServerError() async {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        mockAuthenticationManager.authenticationState = .error(.serverError(500, "Internal server error"))
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertTrue(mockAuthenticationManager.authenticateCalled)
        XCTAssertNotNil(loginViewModel.errorMessage)
        XCTAssertTrue(loginViewModel.errorMessage!.contains("Server error"))
        XCTAssertFalse(loginViewModel.isLoading)
    }
    
    func testLoginWithConfigurationError() async {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        mockAuthenticationManager.authenticationState = .error(.configurationError("Invalid configuration"))
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertTrue(mockAuthenticationManager.authenticateCalled)
        XCTAssertNotNil(loginViewModel.errorMessage)
        XCTAssertTrue(loginViewModel.errorMessage!.contains("Configuration error"))
        XCTAssertFalse(loginViewModel.isLoading)
    }
    
    func testLoginWithSuccessfulAuthentication() async {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        let user = User(id: "123", username: "testuser", email: "test@example.com", displayName: "Test User", provider: "test")
        mockAuthenticationManager.authenticationState = .authenticated(user)
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertTrue(mockAuthenticationManager.authenticateCalled)
        XCTAssertNil(loginViewModel.errorMessage) // No error on successful authentication
        XCTAssertFalse(loginViewModel.isLoading)
    }
    
    func testLoginWithEmptyCredentials() async {
        // Given
        loginViewModel.username = ""
        loginViewModel.password = ""
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertFalse(mockAuthenticationManager.authenticateCalled) // Should not call authenticate with empty credentials
        XCTAssertFalse(loginViewModel.isLoading)
    }
    
    func testLoginWhileAlreadyLoading() async {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        loginViewModel.isLoading = true
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertFalse(mockAuthenticationManager.authenticateCalled) // Should not call authenticate while loading
    }
    
    // MARK: - Error Handling and User Feedback Tests
    
    func testErrorMessageDisplayForDifferentErrorTypes() async {
        let testCases: [(AuthenticationError, String)] = [
            (.invalidCredentials, "Invalid username or password"),
            (.tokenExpired, "Your session has expired. Please log in again."),
            (.biometricAuthenticationFailed, "Biometric authentication failed"),
            (.configurationError("Test config error"), "Configuration error: Test config error"),
            (.keychainError(errSecItemNotFound), "Keychain error: -25300"),
            (.networkError(NetworkError.timeout), "Network error: Request timed out"),
            (.serverError(404, "Not found"), "Server error (404): Not found"),
            (.unknownError(NSError(domain: "TestDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Test error"])), "Unknown error: Test error")
        ]
        
        for (error, expectedMessage) in testCases {
            // Given
            loginViewModel.username = "testuser"
            loginViewModel.password = "testpass"
            mockAuthenticationManager.authenticationState = .error(error)
            
            // When
            await loginViewModel.login(authManager: mockAuthenticationManager)
            
            // Then
            XCTAssertEqual(loginViewModel.errorMessage, expectedMessage, "Error message mismatch for \(error)")
            
            // Reset for next test
            loginViewModel.clearForm()
            mockAuthenticationManager.reset()
        }
    }
    
    func testErrorMessageClearedOnNewLogin() async {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        loginViewModel.errorMessage = "Previous error"
        mockAuthenticationManager.authenticationState = .unauthenticated
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertNil(loginViewModel.errorMessage) // Error should be cleared at start of login
    }
    
    func testLoadingStateManagement() async {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        mockAuthenticationManager.authenticationState = .unauthenticated
        
        var loadingStates: [Bool] = []
        loginViewModel.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
            }
            .store(in: &cancellables)
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertTrue(loadingStates.contains(false)) // Initial false
        XCTAssertTrue(loadingStates.contains(true))  // Set to true during login
        XCTAssertFalse(loginViewModel.isLoading)     // Back to false after login
    }
    
    // MARK: - Form Management Tests
    
    func testClearForm() {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        loginViewModel.errorMessage = "Some error"
        loginViewModel.isLoading = true
        
        // When
        loginViewModel.clearForm()
        
        // Then
        XCTAssertEqual(loginViewModel.username, "")
        XCTAssertEqual(loginViewModel.password, "")
        XCTAssertNil(loginViewModel.errorMessage)
        XCTAssertFalse(loginViewModel.isLoading)
    }
    
    func testFormStateAfterClear() {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        
        // Verify initial state
        XCTAssertTrue(loginViewModel.isLoginButtonEnabled)
        
        // When
        loginViewModel.clearForm()
        
        // Then
        XCTAssertFalse(loginViewModel.isLoginButtonEnabled)
    }
    
    // MARK: - Reactive Property Tests
    
    func testUsernamePropertyChanges() {
        // Given
        var usernameChanges: [String] = []
        
        loginViewModel.$username
            .sink { username in
                usernameChanges.append(username)
            }
            .store(in: &cancellables)
        
        // When
        loginViewModel.username = "test"
        loginViewModel.username = "testuser"
        
        // Then
        XCTAssertEqual(usernameChanges, ["", "test", "testuser"])
    }
    
    func testPasswordPropertyChanges() {
        // Given
        var passwordChanges: [String] = []
        
        loginViewModel.$password
            .sink { password in
                passwordChanges.append(password)
            }
            .store(in: &cancellables)
        
        // When
        loginViewModel.password = "pass"
        loginViewModel.password = "password"
        
        // Then
        XCTAssertEqual(passwordChanges, ["", "pass", "password"])
    }
    
    func testErrorMessagePropertyChanges() {
        // Given
        var errorChanges: [String?] = []
        
        loginViewModel.$errorMessage
            .sink { error in
                errorChanges.append(error)
            }
            .store(in: &cancellables)
        
        // When
        loginViewModel.errorMessage = "Error 1"
        loginViewModel.errorMessage = nil
        loginViewModel.errorMessage = "Error 2"
        
        // Then
        XCTAssertEqual(errorChanges, [nil, "Error 1", nil, "Error 2"])
    }
    
    func testIsLoadingPropertyChanges() {
        // Given
        var loadingChanges: [Bool] = []
        
        loginViewModel.$isLoading
            .sink { isLoading in
                loadingChanges.append(isLoading)
            }
            .store(in: &cancellables)
        
        // When
        loginViewModel.isLoading = true
        loginViewModel.isLoading = false
        loginViewModel.isLoading = true
        
        // Then
        XCTAssertEqual(loadingChanges, [false, true, false, true])
    }
    
    // MARK: - Edge Cases Tests
    
    func testLoginWithSpecialCharactersInCredentials() async {
        // Given
        loginViewModel.username = "user@domain.com"
        loginViewModel.password = "p@ssw0rd!#$%"
        mockAuthenticationManager.authenticationState = .unauthenticated
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertTrue(mockAuthenticationManager.authenticateCalled)
        XCTAssertEqual(mockAuthenticationManager.lastCredentials?.username, "user@domain.com")
        XCTAssertEqual(mockAuthenticationManager.lastCredentials?.password, "p@ssw0rd!#$%")
    }
    
    func testLoginWithVeryLongCredentials() async {
        // Given
        let longUsername = String(repeating: "a", count: 1000)
        let longPassword = String(repeating: "b", count: 1000)
        
        loginViewModel.username = longUsername
        loginViewModel.password = longPassword
        mockAuthenticationManager.authenticationState = .unauthenticated
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertTrue(mockAuthenticationManager.authenticateCalled)
        XCTAssertEqual(mockAuthenticationManager.lastCredentials?.username, longUsername)
        XCTAssertEqual(mockAuthenticationManager.lastCredentials?.password, longPassword)
    }
    
    func testMultipleConsecutiveLogins() async {
        // Given
        loginViewModel.username = "testuser"
        loginViewModel.password = "testpass"
        mockAuthenticationManager.authenticationState = .unauthenticated
        
        // When
        await loginViewModel.login(authManager: mockAuthenticationManager)
        await loginViewModel.login(authManager: mockAuthenticationManager)
        await loginViewModel.login(authManager: mockAuthenticationManager)
        
        // Then
        XCTAssertEqual(mockAuthenticationManager.authenticateCallCount, 3)
    }
}

// MARK: - Mock Authentication Manager for Login Tests

@MainActor
class MockAuthenticationManagerForLogin: ObservableObject {
    @Published var authenticationState: AuthenticationState = .unauthenticated
    @Published var availableProviders: [IdentityProvider] = []
    @Published var selectedProvider: IdentityProvider?
    
    var authenticateCalled = false
    var authenticateCallCount = 0
    var lastCredentials: Credentials?
    
    func authenticate(credentials: Credentials) async {
        authenticateCalled = true
        authenticateCallCount += 1
        lastCredentials = credentials
        
        // Simulate async authentication
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // The authenticationState is already set by the test
        // This simulates the real AuthenticationManager updating its state
    }
    
    func reset() {
        authenticateCalled = false
        authenticateCallCount = 0
        lastCredentials = nil
        authenticationState = .unauthenticated
    }
    
    // Other methods that might be called by the view model
    func isBiometricAuthenticationEnabled() -> Bool { return false }
    func getBiometricType() -> BiometricType { return .none }
    func authenticateWithBiometrics() async { }
    func selectProvider(_ provider: IdentityProvider) { }
}