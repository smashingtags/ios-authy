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
                    .onTapGesture {
                        authManager.refreshUserActivity()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        authManager.refreshUserActivity()
                    }
            case .biometricPrompt:
                BiometricPromptView()
            case .error(let error):
                ErrorView(error: error)
            }
        }
        .animation(.easeInOut, value: authManager.authenticationState)
        .backgroundSecurity()
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
            Image(systemName: biometricIcon)
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("\(biometricName) Authentication")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Use \(biometricName) to access your account")
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
    
    private var biometricIcon: String {
        switch authManager.getBiometricType() {
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
    
    private var biometricName: String {
        authManager.getBiometricType().displayName
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