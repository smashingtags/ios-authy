import XCTest
@testable import IdentityProviderAuth

class IdentityProviderServiceTests: XCTestCase {
    var identityProviderService: IdentityProviderService!
    var mockNetworkManager: MockNetworkManagerForIdentityProvider!
    
    override func setUp() {
        super.setUp()
        mockNetworkManager = MockNetworkManagerForIdentityProvider()
        identityProviderService = IdentityProviderService(networkManager: mockNetworkManager)
    }
    
    override func tearDown() {
        identityProviderService = nil
        mockNetworkManager = nil
        super.tearDown()
    }
    
    // MARK: - OAuth 2.0 Authentication Tests
    
    func testAuthenticateWithValidCredentials() async throws {
        // Given
        let credentials = Credentials(username: "testuser", password: "testpass")
        let provider = createTestProvider()
        
        let tokenResponse = TokenResponse(
            accessToken: "access_token_123",
            tokenType: "Bearer",
            expiresIn: 3600,
            refreshToken: "refresh_token_123",
            scope: "openid profile",
            idToken: "id_token_123"
        )
        
        mockNetworkManager.mockResponse = tokenResponse
        
        // When
        let result = try await identityProviderService.authenticate(credentials: credentials, provider: provider)
        
        // Then
        XCTAssertEqual(result.accessToken, "access_token_123")
        XCTAssertEqual(result.refreshToken, "refresh_token_123")
        XCTAssertEqual(result.tokenType, "Bearer")
        XCTAssertEqual(result.expiresIn, 3600)
        XCTAssertEqual(result.scope, "openid profile")
        XCTAssertEqual(result.idToken, "id_token_123")
        XCTAssertNotNil(result.issuedAt)
        
        // Verify the request was made correctly
        XCTAssertEqual(mockNetworkManager.lastRequest?.url, provider.tokenEndpoint)
        XCTAssertEqual(mockNetworkManager.lastRequest?.method, .POST)
        XCTAssertEqual(mockNetworkManager.lastRequest?.headers["Content-Type"], "application/x-www-form-urlencoded")
        XCTAssertEqual(mockNetworkManager.lastRequest?.headers["Accept"], "application/json")
        
        // Verify form data
        if let bodyData = mockNetworkManager.lastRequest?.body,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            XCTAssertTrue(bodyString.contains("grant_type=password"))
            XCTAssertTrue(bodyString.contains("username=testuser"))
            XCTAssertTrue(bodyString.contains("password=testpass"))
            XCTAssertTrue(bodyString.contains("client_id=test_client"))
            XCTAssertTrue(bodyString.contains("scope=openid%20profile"))
        } else {
            XCTFail("Request body should contain form data")
        }
    }
    
    func testAuthenticateWithInvalidCredentials() async {
        // Given
        let credentials = Credentials(username: "invalid", password: "invalid")
        let provider = createTestProvider()
        
        mockNetworkManager.mockError = NetworkError.httpError(401, nil)
        
        // When/Then
        do {
            let _ = try await identityProviderService.authenticate(credentials: credentials, provider: provider)
            XCTFail("Expected authentication error")
        } catch let error as AuthenticationError {
            if case .invalidCredentials = error {
                // Expected
            } else {
                XCTFail("Expected invalidCredentials error, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthenticationError.invalidCredentials, got \(error)")
        }
    }
    
    func testAuthenticateWithServerError() async {
        // Given
        let credentials = Credentials(username: "testuser", password: "testpass")
        let provider = createTestProvider()
        
        let errorData = """
        {"error": "server_error", "error_description": "Internal server error"}
        """.data(using: .utf8)
        
        mockNetworkManager.mockError = NetworkError.httpError(500, errorData)
        
        // When/Then
        do {
            let _ = try await identityProviderService.authenticate(credentials: credentials, provider: provider)
            XCTFail("Expected server error")
        } catch let error as AuthenticationError {
            if case .serverError(let code, let message) = error {
                XCTAssertEqual(code, 500)
                XCTAssertNotNil(message)
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthenticationError.serverError, got \(error)")
        }
    }
    
    func testAuthenticateWithNetworkError() async {
        // Given
        let credentials = Credentials(username: "testuser", password: "testpass")
        let provider = createTestProvider()
        
        mockNetworkManager.mockError = NetworkError.noInternetConnection
        
        // When/Then
        do {
            let _ = try await identityProviderService.authenticate(credentials: credentials, provider: provider)
            XCTFail("Expected network error")
        } catch let error as AuthenticationError {
            if case .networkError(let networkError) = error {
                XCTAssertTrue(networkError is NetworkError)
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthenticationError.networkError, got \(error)")
        }
    }
    
    // MARK: - Token Refresh Tests
    
    func testRefreshTokenWithValidToken() async throws {
        // Given
        let refreshToken = "valid_refresh_token"
        let provider = createTestProvider()
        
        let tokenResponse = TokenResponse(
            accessToken: "new_access_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            refreshToken: "new_refresh_token",
            scope: "openid profile",
            idToken: "new_id_token"
        )
        
        mockNetworkManager.mockResponse = tokenResponse
        
        // When
        let result = try await identityProviderService.refreshToken(refreshToken, provider: provider)
        
        // Then
        XCTAssertEqual(result.accessToken, "new_access_token")
        XCTAssertEqual(result.refreshToken, "new_refresh_token")
        XCTAssertEqual(result.tokenType, "Bearer")
        XCTAssertEqual(result.expiresIn, 3600)
        XCTAssertEqual(result.scope, "openid profile")
        XCTAssertEqual(result.idToken, "new_id_token")
        
        // Verify the request was made correctly
        XCTAssertEqual(mockNetworkManager.lastRequest?.url, provider.tokenEndpoint)
        XCTAssertEqual(mockNetworkManager.lastRequest?.method, .POST)
        
        // Verify form data
        if let bodyData = mockNetworkManager.lastRequest?.body,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            XCTAssertTrue(bodyString.contains("grant_type=refresh_token"))
            XCTAssertTrue(bodyString.contains("refresh_token=valid_refresh_token"))
            XCTAssertTrue(bodyString.contains("client_id=test_client"))
        } else {
            XCTFail("Request body should contain form data")
        }
    }
    
    func testRefreshTokenWithExpiredToken() async {
        // Given
        let expiredRefreshToken = "expired_refresh_token"
        let provider = createTestProvider()
        
        mockNetworkManager.mockError = NetworkError.httpError(401, nil)
        
        // When/Then
        do {
            let _ = try await identityProviderService.refreshToken(expiredRefreshToken, provider: provider)
            XCTFail("Expected token expired error")
        } catch let error as AuthenticationError {
            if case .tokenExpired = error {
                // Expected
            } else {
                XCTFail("Expected tokenExpired error, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthenticationError.tokenExpired, got \(error)")
        }
    }
    
    func testRefreshTokenWithoutNewRefreshToken() async throws {
        // Given
        let refreshToken = "valid_refresh_token"
        let provider = createTestProvider()
        
        let tokenResponse = TokenResponse(
            accessToken: "new_access_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            refreshToken: nil, // No new refresh token provided
            scope: "openid profile",
            idToken: "new_id_token"
        )
        
        mockNetworkManager.mockResponse = tokenResponse
        
        // When
        let result = try await identityProviderService.refreshToken(refreshToken, provider: provider)
        
        // Then
        XCTAssertEqual(result.refreshToken, refreshToken) // Should keep the original refresh token
    }
    
    // MARK: - User Info Retrieval Tests
    
    func testGetUserInfoWithValidToken() async throws {
        // Given
        let accessToken = "valid_access_token"
        let provider = createTestProviderWithUserInfo()
        
        let userInfoResponse = UserInfoResponse(
            sub: "user123",
            preferredUsername: "testuser",
            email: "test@example.com",
            name: "Test User"
        )
        
        mockNetworkManager.mockResponse = userInfoResponse
        
        // When
        let result = try await identityProviderService.getUserInfo(accessToken: accessToken, provider: provider)
        
        // Then
        XCTAssertEqual(result.id, "user123")
        XCTAssertEqual(result.username, "testuser")
        XCTAssertEqual(result.email, "test@example.com")
        XCTAssertEqual(result.displayName, "Test User")
        XCTAssertEqual(result.provider, provider.id)
        
        // Verify the request was made correctly
        XCTAssertEqual(mockNetworkManager.lastRequest?.url, provider.userInfoEndpoint)
        XCTAssertEqual(mockNetworkManager.lastRequest?.method, .GET)
        XCTAssertEqual(mockNetworkManager.lastRequest?.headers["Authorization"], "Bearer valid_access_token")
        XCTAssertEqual(mockNetworkManager.lastRequest?.headers["Accept"], "application/json")
    }
    
    func testGetUserInfoWithoutUserInfoEndpoint() async throws {
        // Given
        let accessToken = "valid_access_token"
        let provider = createTestProvider() // No userInfoEndpoint
        
        // When
        let result = try await identityProviderService.getUserInfo(accessToken: accessToken, provider: provider)
        
        // Then
        XCTAssertNotNil(result.id)
        XCTAssertEqual(result.username, "user")
        XCTAssertNil(result.email)
        XCTAssertNil(result.displayName)
        XCTAssertEqual(result.provider, provider.id)
        
        // Verify no network request was made
        XCTAssertNil(mockNetworkManager.lastRequest)
    }
    
    func testGetUserInfoWithInvalidToken() async {
        // Given
        let invalidAccessToken = "invalid_access_token"
        let provider = createTestProviderWithUserInfo()
        
        mockNetworkManager.mockError = NetworkError.httpError(401, nil)
        
        // When/Then
        do {
            let _ = try await identityProviderService.getUserInfo(accessToken: invalidAccessToken, provider: provider)
            XCTFail("Expected token expired error")
        } catch let error as AuthenticationError {
            if case .tokenExpired = error {
                // Expected
            } else {
                XCTFail("Expected tokenExpired error, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthenticationError.tokenExpired, got \(error)")
        }
    }
    
    func testGetUserInfoWithServerError() async {
        // Given
        let accessToken = "valid_access_token"
        let provider = createTestProviderWithUserInfo()
        
        let errorData = "Service unavailable".data(using: .utf8)
        mockNetworkManager.mockError = NetworkError.httpError(503, errorData)
        
        // When/Then
        do {
            let _ = try await identityProviderService.getUserInfo(accessToken: accessToken, provider: provider)
            XCTFail("Expected server error")
        } catch let error as AuthenticationError {
            if case .serverError(let code, let message) = error {
                XCTAssertEqual(code, 503)
                XCTAssertNotNil(message)
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthenticationError.serverError, got \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testUnknownErrorHandling() async {
        // Given
        let credentials = Credentials(username: "testuser", password: "testpass")
        let provider = createTestProvider()
        
        struct CustomError: Error {}
        mockNetworkManager.mockError = CustomError()
        
        // When/Then
        do {
            let _ = try await identityProviderService.authenticate(credentials: credentials, provider: provider)
            XCTFail("Expected unknown error")
        } catch let error as AuthenticationError {
            if case .unknownError = error {
                // Expected
            } else {
                XCTFail("Expected unknownError, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthenticationError.unknownError, got \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestProvider() -> IdentityProvider {
        return IdentityProvider(
            id: "test_provider",
            name: "Test Provider",
            displayName: "Test Identity Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: nil,
            clientId: "test_client",
            scope: "openid profile",
            isDefault: true
        )
    }
    
    private func createTestProviderWithUserInfo() -> IdentityProvider {
        return IdentityProvider(
            id: "test_provider",
            name: "Test Provider",
            displayName: "Test Identity Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: URL(string: "https://example.com/userinfo")!,
            clientId: "test_client",
            scope: "openid profile",
            isDefault: true
        )
    }
}

// MARK: - Mock Network Manager for Identity Provider Service

class MockNetworkManagerForIdentityProvider: NetworkManagerProtocol {
    var mockResponse: Any?
    var mockError: Error?
    var lastRequest: NetworkRequest?
    var isConnected: Bool = true
    
    func performRequest<T: Codable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T {
        lastRequest = request
        
        if let error = mockError {
            throw error
        }
        
        guard let response = mockResponse else {
            throw NetworkError.noData
        }
        
        guard let typedResponse = response as? T else {
            throw NetworkError.decodingError(NSError(domain: "TestError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Type mismatch"]))
        }
        
        return typedResponse
    }
    
    func performRequest(_ request: NetworkRequest) async throws -> Data {
        lastRequest = request
        
        if let error = mockError {
            throw error
        }
        
        guard let response = mockResponse else {
            throw NetworkError.noData
        }
        
        if let data = response as? Data {
            return data
        }
        
        // Try to encode the response as JSON
        do {
            if let codableResponse = response as? Codable {
                return try JSONEncoder().encode(codableResponse)
            } else {
                // Fallback to empty data
                return Data()
            }
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}

// Helper struct for encoding any response
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}