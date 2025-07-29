import SwiftUI

@main
struct IdentityProviderAuthApp: App {
    @StateObject private var authenticationManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authenticationManager)
                .onAppear {
                    authenticationManager.checkAuthenticationStatus()
                }
        }
    }
}