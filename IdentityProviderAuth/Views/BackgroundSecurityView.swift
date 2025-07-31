import SwiftUI

struct BackgroundSecurityView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("App Secured")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Return to the app to continue")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct BackgroundSecurityModifier: ViewModifier {
    @State private var isInBackground = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: isInBackground ? 10 : 0)
            
            if isInBackground {
                BackgroundSecurityView()
                    .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isInBackground = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isInBackground = false
            }
        }
    }
}

extension View {
    func backgroundSecurity() -> some View {
        modifier(BackgroundSecurityModifier())
    }
}