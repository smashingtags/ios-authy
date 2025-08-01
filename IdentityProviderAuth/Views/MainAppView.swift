import SwiftUI

struct MainAppView: View {
    let user: User
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showBiometricSetup = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Welcome Section
                VStack(spacing: 15) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Welcome!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(user.displayName ?? user.username)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
                
                // User Information Card
                VStack(alignment: .leading, spacing: 15) {
                    Text("Account Information")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    InfoRow(label: "Username", value: user.username)
                    
                    if let email = user.email {
                        InfoRow(label: "Email", value: email)
                    }
                    
                    InfoRow(label: "Provider", value: user.provider)
                    
                    if let displayName = user.displayName {
                        InfoRow(label: "Display Name", value: displayName)
                    }
                    
                    // Biometric Authentication Toggle
                    if authManager.getBiometricType() != .none {
                        HStack {
                            Text("Biometric Login")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)
                            
                            Toggle("", isOn: Binding(
                                get: { authManager.isBiometricAuthenticationEnabled() },
                                set: { enabled in
                                    if enabled {
                                        authManager.enableBiometricAuthentication()
                                    } else {
                                        authManager.disableBiometricAuthentication()
                                    }
                                }
                            ))
                            .labelsHidden()
                            
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Logout Button
                Button(action: {
                    authManager.logout()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                        Text("Sign Out")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 50)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Check if we should prompt for biometric setup
                if authManager.shouldPromptForBiometricSetup() {
                    showBiometricSetup = true
                }
                // Track user activity when view appears
                authManager.refreshUserActivity()
            }
            .onTapGesture {
                // Track user activity on tap
                authManager.refreshUserActivity()
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        // Track user activity on any gesture
                        authManager.refreshUserActivity()
                    }
            )
            .sheet(isPresented: $showBiometricSetup) {
                BiometricSetupView(biometricType: authManager.getBiometricType())
                    .environmentObject(authManager)
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}