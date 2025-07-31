import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App Logo/Title
                VStack(spacing: 10) {
                    Image(systemName: "person.badge.key")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Identity Provider Auth")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Provider Selection (if multiple providers)
                if authManager.availableProviders.count > 1 {
                    ProviderSelectionView()
                        .padding(.horizontal)
                }
                
                // Login Form
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.headline)
                        
                        TextField("Enter your username", text: $viewModel.username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        
                        SecureField("Enter your password", text: $viewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.password)
                    }
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.login(authManager: authManager)
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isLoginButtonEnabled ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!viewModel.isLoginButtonEnabled)
                }
                .padding(.horizontal)
                
                // Biometric Authentication Option
                if authManager.isBiometricAuthenticationEnabled() && authManager.getBiometricType() != .none {
                    VStack(spacing: 10) {
                        Text("or")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Button(action: {
                            Task {
                                await authManager.authenticateWithBiometrics()
                            }
                        }) {
                            HStack {
                                Image(systemName: biometricIcon)
                                Text("Use \(biometricName)")
                            }
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                        }
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.clearForm()
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

struct ProviderSelectionView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Identity Provider")
                .font(.headline)
            
            Picker("Select Provider", selection: Binding(
                get: { authManager.selectedProvider?.id ?? "" },
                set: { providerId in
                    if let provider = authManager.availableProviders.first(where: { $0.id == providerId }) {
                        authManager.selectProvider(provider)
                    }
                }
            )) {
                ForEach(authManager.availableProviders, id: \.id) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@MainActor
class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    var isLoginButtonEnabled: Bool {
        !username.isEmpty && !password.isEmpty && !isLoading
    }
    
    func login(authManager: AuthenticationManager) async {
        guard isLoginButtonEnabled else { return }
        
        isLoading = true
        errorMessage = nil
        
        let credentials = Credentials(username: username, password: password)
        await authManager.authenticate(credentials: credentials)
        
        // Check if authentication failed
        if case .error(let error) = authManager.authenticationState {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func clearForm() {
        username = ""
        password = ""
        errorMessage = nil
        isLoading = false
    }
}