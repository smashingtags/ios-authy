import XCTest
import Combine
import Security
import Network
@testable import IdentityProviderAuth

// MARK: - Mock Keychain Manager

class MockKeychainManager: KeychainManagerProtocol {
    var storedItems: [String: Data] = [:]
    var deleteAllCalled = false
    var shouldThrowError = false
    var errorToThrow: AuthenticationError = .keychainError(errSecItemNotFound)
    
    // Additional properties for test extensions
    var mockRetrieveResults: [String: Any] = [:]
    
    func store<T: Codable>(_ item: T, forKey key: String) throws {
        if shouldThrowError {
            throw errorToThrow
        }
        let data = try JSONEncoder().encode(item)
        storedItems[key] = data
    }
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Check mockRetrieveResults first
        if let result = mockRetrieveResults[key] {
            if let directResult = result as? T {
                return directResult
            }
            // Try to encode and decode for type safety
            if let codableResult = result as? Codable {
                if let data = try? JSONEncoder().encode(codableResult) {
                    return try? JSONDecoder().decode(type, from: data)
                }
            }
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
        deleteAllCalled = true
        storedItems.removeAll()
    }
}

// MARK: - Mock Biometric Manager

class MockBiometricManager: BiometricManagerProtocol {
    var isAvailable = false
    var authenticationResult = false
    var biometricType: BiometricType = .none
    var isEnabled = false
    var shouldPromptSetup = false
    var setupPrompted = false
    var shouldThrowError = false
    var errorToThrow: BiometricAuthenticationError = .failed
    
    var authenticateWithBiometricsCalled = false
    
    func isBiometricAuthenticationAvailable() -> Bool {
        return isAvailable
    }
    
    func authenticateWithBiometrics() async throws -> Bool {
        authenticateWithBiometricsCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        if !isAvailable {
            throw BiometricAuthenticationError.notAvailable
        }
        return authenticationResult && isEnabled && isAvailable
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

// MARK: - Mock Configuration Manager

class MockConfigurationManager: ConfigurationManagerProtocol {
    var mockProviders: [IdentityProvider] = []
    var providers: [IdentityProvider] = []
    var mockDefaultProvider: IdentityProvider?
    var defaultProvider: IdentityProvider?
    var mockError: Error?
    var shouldThrowError = false
    var errorToThrow: AuthenticationError = .configurationError("Mock error")
    
    func loadProviders() throws -> [IdentityProvider] {
        if shouldThrowError {
            throw errorToThrow
        }
        if let error = mockError {
            throw error
        }
        return !mockProviders.isEmpty ? mockProviders : providers
    }
    
    func getDefaultProvider() throws -> IdentityProvider {
        if shouldThrowError {
            throw errorToThrow
        }
        if let error = mockError {
            throw error
        }
        if let provider = mockDefaultProvider ?? defaultProvider {
            return provider
        }
        let allProviders = !mockProviders.isEmpty ? mockProviders : providers
        guard let firstProvider = allProviders.first else {
            throw AuthenticationError.configurationError("No default provider")
        }
        return firstProvider
    }
    
    func validateProvider(_ provider: IdentityProvider) throws {
        if shouldThrowError {
            throw errorToThrow
        }
        if let error = mockError {
            throw error
        }
        // Mock validation - always passes unless shouldThrowError is true
    }
}

// MARK: - Mock Identity Provider Service

class MockIdentityProviderService: IdentityProviderServiceProtocol {
    let networkManager: NetworkManagerProtocol?
    var mockAuthTokens: AuthTokens?
    var mockRefreshTokens: AuthTokens?
    var mockUser: User?
    var mockError: Error?
    var mockRefreshError: Error?
    var shouldThrowError = false
    var errorToThrow: AuthenticationError = .invalidCredentials
    
    var authenticateCalled = false
    var refreshTokenCalled = false
    var getUserInfoCalled = false
    
    init(networkManager: NetworkManagerProtocol? = nil) {
        self.networkManager = networkManager
    }
    
    func authenticate(credentials: Credentials, provider: IdentityProvider) async throws -> AuthTokens {
        authenticateCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        if let error = mockError {
            throw error
        }
        return mockAuthTokens ?? AuthTokens(
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
        refreshTokenCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        if let error = mockRefreshError {
            throw error
        }
        return mockRefreshTokens ?? AuthTokens(
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
        getUserInfoCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        if let error = mockError {
            throw error
        }
        return mockUser ?? User(
            id: "mock_user_id",
            username: "mockuser",
            email: "mock@example.com",
            displayName: "Mock User",
            provider: provider.id
        )
    }
}

// MARK: - Mock Network Manager

class MockNetworkManager: NetworkManagerProtocol {
    var isConnected: Bool = true
    var shouldThrowError = false
    var errorToThrow: Error = NetworkError.noInternetConnection
    
    func performRequest<T: Codable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T {
        if shouldThrowError {
            throw errorToThrow
        }
        // Return a mock response - this would need to be customized per test
        throw NetworkError.noData
    }
    
    func performRequest(_ request: NetworkRequest) async throws -> Data {
        if shouldThrowError {
            throw errorToThrow
        }
        if !isConnected {
            throw NetworkError.noInternetConnection
        }
        return Data()
    }
}

// MARK: - Mock URL Session (for NetworkManager tests)

class MockURLSession {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    var lastRequest: URLRequest?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        if let error = error {
            throw error
        }
        
        guard let data = data, let response = response else {
            throw URLError(.badServerResponse)
        }
        
        return (data, response)
    }
}

// MARK: - Enhanced Mock Network Manager (for NetworkManager tests)

class EnhancedMockNetworkManager: NetworkManagerProtocol {
    private let mockSession: MockURLSession
    var isConnected: Bool = true
    
    init(session: MockURLSession) {
        self.mockSession = session
    }
    
    func performRequest<T: Codable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T {
        let data = try await performRequest(request)
        
        do {
            return try JSONDecoder().decode(responseType, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    func performRequest(_ request: NetworkRequest) async throws -> Data {
        guard isConnected else {
            throw NetworkError.noInternetConnection
        }
        
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        
        // Set headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set body for POST requests
        if let body = request.body {
            urlRequest.httpBody = body
        }
        
        // Ensure HTTPS
        guard request.url.scheme == "https" else {
            throw NetworkError.sslError
        }
        
        do {
            let (data, response) = try await mockSession.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidURL
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.httpError(httpResponse.statusCode, data)
            }
            
            return data
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw NetworkError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.noInternetConnection
            case .serverCertificateUntrusted, .secureConnectionFailed:
                throw NetworkError.sslError
            default:
                throw NetworkError.httpError(error.errorCode, nil)
            }
        } catch {
            throw error
        }
    }
}

// MARK: - Test Extensions

extension MockKeychainManager {
    func simulateError(_ error: AuthenticationError) {
        shouldThrowError = true
        errorToThrow = error
    }
    
    func reset() {
        storedItems.removeAll()
        deleteAllCalled = false
        shouldThrowError = false
        errorToThrow = .keychainError(errSecItemNotFound)
    }
}

extension MockIdentityProviderService {
    func simulateDelayedResponse() {
        // Can be used to simulate network delays in tests
    }
    
    func reset() {
        mockAuthTokens = nil
        mockRefreshTokens = nil
        mockUser = nil
        mockError = nil
        mockRefreshError = nil
        authenticateCalled = false
        refreshTokenCalled = false
        getUserInfoCalled = false
    }
}

// MARK: - Test Helper Extensions

extension AuthenticationState: Equatable {
    public static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated):
            return true
        case (.authenticating, .authenticating):
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

@retroactive extension AuthenticationError: Equatable {
    public static func == (lhs: AuthenticationError, rhs: AuthenticationError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredentials, .invalidCredentials):
            return true
        case (.networkError, .networkError):
            return true
        case (.serverError(let lhsCode), .serverError(let rhsCode)):
            return lhsCode == rhsCode
        case (.configurationError(let lhsMessage), .configurationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.keychainError(let lhsStatus), .keychainError(let rhsStatus)):
            return lhsStatus == rhsStatus
        case (.tokenExpired, .tokenExpired):
            return true
        case (.biometricAuthenticationFailed, .biometricAuthenticationFailed):
            return true
        default:
            return false
        }
    }
}