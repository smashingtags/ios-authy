import Foundation
import LocalAuthentication

protocol BiometricManagerProtocol {
    func isBiometricAuthenticationAvailable() -> Bool
    func authenticateWithBiometrics() async throws -> Bool
    func getBiometricType() -> BiometricType
    func isBiometricAuthenticationEnabled() -> Bool
    func setBiometricAuthenticationEnabled(_ enabled: Bool)
    func shouldPromptForBiometricSetup() -> Bool
    func setBiometricSetupPrompted()
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
    private let userDefaults = UserDefaults.standard
    
    private enum UserDefaultsKeys {
        static let biometricAuthEnabled = "biometric_auth_enabled"
        static let biometricSetupPrompted = "biometric_setup_prompted"
    }
    
    func isBiometricAuthenticationAvailable() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func authenticateWithBiometrics() async throws -> Bool {
        guard isBiometricAuthenticationAvailable() else {
            throw AuthenticationError.biometricAuthenticationFailed
        }
        
        guard isBiometricAuthenticationEnabled() else {
            throw AuthenticationError.biometricAuthenticationFailed
        }
        
        let reason = "Authenticate to access your account"
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return result
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .userFallback:
                // User chose to cancel or use fallback - this is not an error
                throw BiometricAuthenticationError.userCancelled
            case .biometryNotAvailable, .biometryNotEnrolled:
                throw BiometricAuthenticationError.notAvailable
            case .biometryLockout:
                throw BiometricAuthenticationError.lockout
            default:
                throw BiometricAuthenticationError.failed
            }
        } catch {
            throw BiometricAuthenticationError.failed
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
    
    func isBiometricAuthenticationEnabled() -> Bool {
        return userDefaults.bool(forKey: UserDefaultsKeys.biometricAuthEnabled)
    }
    
    func setBiometricAuthenticationEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: UserDefaultsKeys.biometricAuthEnabled)
    }
    
    func shouldPromptForBiometricSetup() -> Bool {
        return isBiometricAuthenticationAvailable() && 
               !isBiometricAuthenticationEnabled() && 
               !userDefaults.bool(forKey: UserDefaultsKeys.biometricSetupPrompted)
    }
    
    func setBiometricSetupPrompted() {
        userDefaults.set(true, forKey: UserDefaultsKeys.biometricSetupPrompted)
    }
}