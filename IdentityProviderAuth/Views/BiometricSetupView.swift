import SwiftUI

struct BiometricSetupView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    let biometricType: BiometricType
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon
            Image(systemName: biometricIcon)
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            // Title and Description
            VStack(spacing: 16) {
                Text("Enable \(biometricType.displayName)?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Use \(biometricType.displayName) to quickly and securely sign in to your account.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Buttons
            VStack(spacing: 16) {
                Button(action: {
                    authManager.enableBiometricAuthentication()
                    authManager.setBiometricSetupPrompted()
                    dismiss()
                }) {
                    Text("Enable \(biometricType.displayName)")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    authManager.setBiometricSetupPrompted()
                    dismiss()
                }) {
                    Text("Not Now")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationBarHidden(true)
    }
    
    private var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "person.badge.key"
        }
    }
}

#Preview {
    BiometricSetupView(biometricType: .faceID)
        .environmentObject(AuthenticationManager())
}