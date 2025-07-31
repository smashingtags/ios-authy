import Foundation

// MARK: - Core Authentication Models

struct Credentials {
    let username: String
    let password: String
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: TimeInterval
    let scope: String?
    let idToken: String?
    let issuedAt: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(issuedAt) >= expiresIn
    }
    
    var expirationDate: Date {
        issuedAt.addingTimeInterval(expiresIn)
    }
}

struct User: Codable {
    let id: String
    let username: String
    let email: String?
    let displayName: String?
    let provider: String
}

struct IdentityProvider: Codable {
    let id: String
    let name: String
    let displayName: String
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let userInfoEndpoint: URL?
    let clientId: String
    let scope: String
    let isDefault: Bool
}

// MARK: - Authentication State

enum AuthenticationState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(User)
    case biometricPrompt
    case error(AuthenticationError)
    
    static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated),
             (.authenticating, .authenticating),
             (.biometricPrompt, .biometricPrompt):
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

// MARK: - Error Types

enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case networkError(Error)
    case serverError(Int, String?)
    case tokenExpired
    case biometricAuthenticationFailed
    case keychainError(OSStatus)
    case configurationError(String)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .tokenExpired:
            return "Your session has expired. Please log in again."
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

enum BiometricAuthenticationError: LocalizedError {
    case notAvailable
    case userCancelled
    case lockout
    case failed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available"
        case .userCancelled:
            return "Biometric authentication was cancelled"
        case .lockout:
            return "Biometric authentication is locked out. Please try again later."
        case .failed:
            return "Biometric authentication failed"
        }
    }
}