import Foundation
import LocalAuthentication

protocol BiometricManagerProtocol {
    func isBiometricAuthenticationAvailable() -> Bool
    func authenticateWithBiometrics() async throws -> Bool
    func getBiometricType() -> BiometricType
}

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        }
    }
}

class BiometricManager: BiometricManagerProtocol {
    private let context = LAContext()
    
    func isBiometricAuthenticationAvailable() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func authenticateWithBiometrics() async throws -> Bool {
        guard isBiometricAuthenticationAvailable() else {
            throw AuthenticationError.biometricAuthenticationFailed
        }
        
        let reason = "Authenticate to access your account"
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return result
        } catch {
            throw AuthenticationError.biometricAuthenticationFailed
        }
    }
    
    func getBiometricType() -> BiometricType {
        guard isBiometricAuthenticationAvailable() else {
            return .none
        }
        
        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }
}