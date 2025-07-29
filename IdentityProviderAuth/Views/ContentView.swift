import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        Group {
            switch authManager.authenticationState {
            case .unauthenticated:
                LoginView()
            case .authenticating:
                LoadingView(message: "Authenticating...")
            case .authenticated(let user):
                MainAppView(user: user)
            case .biometricPrompt:
                BiometricPromptView()
            case .error(let error):
                ErrorView(error: error)
            }
        }
        .animation(.easeInOut, value: authManager.authenticationState)
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct BiometricPromptView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "faceid")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Biometric Authentication")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Use your biometric authentication to access your account")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Use Password Instead") {
                authManager.authenticationState = .unauthenticated
            }
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            Task {
                await authManager.authenticateWithBiometrics()
            }
        }
    }
}

struct ErrorView: View {
    let error: AuthenticationError
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                authManager.authenticationState = .unauthenticated
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}