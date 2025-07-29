import Foundation

// MARK: - Network Request Models

struct NetworkRequest {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let timeout: TimeInterval
    
    init(url: URL, method: HTTPMethod = .GET, headers: [String: String] = [:], body: Data? = nil, timeout: TimeInterval = 30) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - OAuth Token Request/Response Models

struct TokenRequest: Codable {
    let grantType: String
    let username: String
    let password: String
    let clientId: String
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case username
        case password
        case clientId = "client_id"
        case scope
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: TimeInterval
    let refreshToken: String?
    let scope: String?
    let idToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case idToken = "id_token"
    }
}

struct RefreshTokenRequest: Codable {
    let grantType: String
    let refreshToken: String
    let clientId: String
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
        case clientId = "client_id"
    }
}

struct UserInfoResponse: Codable {
    let sub: String
    let preferredUsername: String?
    let email: String?
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case sub
        case preferredUsername = "preferred_username"
        case email
        case name
    }
}

// MARK: - Network Error Models

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case httpError(Int, Data?)
    case timeout
    case noInternetConnection
    case sslError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .httpError(let code, _):
            return "HTTP error: \(code)"
        case .timeout:
            return "Request timed out"
        case .noInternetConnection:
            return "No internet connection"
        case .sslError:
            return "SSL connection error"
        }
    }
}