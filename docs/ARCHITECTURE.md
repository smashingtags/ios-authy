# Architecture Documentation

## Overview

The iOS Identity Provider Authentication App follows a clean MVVM (Model-View-ViewModel) architecture with clear separation of concerns and protocol-oriented design for testability and maintainability.

## Architecture Layers

### 1. Presentation Layer (Views)

**SwiftUI Views** handle user interface presentation and user interactions:

- `ContentView`: Main coordinator that switches between authentication states
- `LoginView`: Username/password authentication interface
- `MainAppView`: Post-authentication user interface
- `BiometricSetupView`: Smart biometric authentication setup prompting
- Supporting views: `LoadingView`, `ErrorView`

**ViewModels** manage presentation logic and state:

- `LoginViewModel`: Handles login form validation and authentication requests
- State management through `@Published` properties and Combine framework

### 2. Business Logic Layer (Services & Managers)

**AuthenticationManager**: Central coordinator for all authentication operations
- Manages authentication state transitions
- Coordinates between different services
- Handles token refresh and session management with 30-minute inactivity timeout
- Implements network connectivity monitoring
- Manages app lifecycle events for foreground/background transitions
- Tracks user activity and automatically logs out inactive sessions

**Services** handle external communication:
- `IdentityProviderService`: OAuth 2.0/OpenID Connect implementation
- `NetworkManager`: HTTP communication with error handling and SSL validation

**Managers** handle system-level operations:
- `KeychainManager`: Secure token storage using iOS Keychain Services
- `BiometricManager`: Face ID/Touch ID/Optic ID authentication with user preference management
- `ConfigurationManager`: Identity provider configuration loading and validation

### 3. Data Layer (Models)

**Core Models**:
- `User`: User profile information
- `AuthTokens`: OAuth tokens with expiration handling
- `IdentityProvider`: Provider configuration
- `Credentials`: Authentication credentials

**Network Models**:
- Request/Response models for OAuth flows
- Error types for different failure scenarios

## Design Patterns

### Protocol-Oriented Programming

All major components are defined with protocols for:
- **Testability**: Easy mocking for unit tests
- **Flexibility**: Different implementations for different environments
- **Dependency Injection**: Loose coupling between components

```swift
protocol KeychainManagerProtocol {
    func store<T: Codable>(_ item: T, forKey key: String) throws
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
}
```

### Dependency Injection

Components receive their dependencies through initializers:

```swift
class AuthenticationManager {
    init(
        keychainManager: KeychainManagerProtocol = KeychainManager(),
        biometricManager: BiometricManagerProtocol = BiometricManager(),
        // ... other dependencies
    )
}
```

### Observer Pattern

Uses Combine framework for reactive programming:
- `@Published` properties for state changes
- Network connectivity monitoring
- Automatic UI updates

### State Machine

Authentication state is managed through a clear state machine:

```swift
enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated(User)
    case biometricPrompt
    case error(AuthenticationError)
}
```

## Data Flow

### Authentication Flow

1. **User Input** → LoginView captures credentials
2. **Validation** → LoginViewModel validates input
3. **Authentication** → AuthenticationManager coordinates authentication
4. **Network Request** → IdentityProviderService makes OAuth request
5. **Token Storage** → KeychainManager stores tokens securely
6. **State Update** → AuthenticationManager updates state
7. **UI Update** → ContentView switches to authenticated state

### Token Refresh Flow

1. **Timer Trigger** → Scheduled refresh before expiration
2. **Refresh Request** → IdentityProviderService refreshes tokens
3. **Token Update** → KeychainManager updates stored tokens
4. **Schedule Next** → Timer scheduled for next refresh
5. **Session Reset** → User activity timer reset after successful refresh

### Session Management Flow

1. **User Activity** → Any user interaction refreshes activity timestamp
2. **Timeout Timer** → 30-minute countdown timer started/reset
3. **Inactivity Check** → Timer expiration triggers inactivity check
4. **Automatic Logout** → User logged out if inactive for 30 minutes
5. **App Lifecycle** → Foreground transition triggers token refresh check

## Security Architecture

### Token Storage

- **iOS Keychain**: All sensitive data stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **Encryption**: Automatic encryption by iOS Keychain Services
- **Access Control**: App-specific keychain items

### Network Security

- **HTTPS Only**: All network requests require HTTPS
- **Certificate Validation**: SSL certificate validation enabled
- **Request Timeout**: Configurable timeouts to prevent hanging requests

### Biometric Security

- **Local Authentication**: Uses iOS LocalAuthentication framework
- **User Preferences**: Persistent storage of biometric authentication preferences
- **Smart Setup**: Intelligent prompting for biometric setup on first use
- **Fallback**: Password authentication when biometrics fail
- **Privacy**: Biometric data never leaves the device

## Error Handling Strategy

### Centralized Error Types

```swift
enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case networkError(Error)
    case serverError(Int, String?)
    case tokenExpired
    // ... other error types
}
```

### Error Propagation

- **Async/Await**: Clean error propagation through async functions
- **Result Types**: Where appropriate for optional error handling
- **Localized Messages**: User-friendly error descriptions

### Recovery Mechanisms

- **Automatic Retry**: Network requests with exponential backoff
- **Token Refresh**: Automatic token refresh on expiration
- **Fallback Authentication**: Biometric → Password fallback

## Testing Strategy

### Unit Testing

- **Protocol Mocking**: Easy mocking through protocols
- **Isolated Testing**: Each component tested in isolation
- **State Testing**: Authentication state transitions
- **Component Validation**: Individual manager and service testing

### Integration Testing

The app includes comprehensive integration tests that verify complete system behavior:

#### Session Management Integration Tests
- **Complete Session Lifecycle**: Tests full authentication lifecycle with various token states
- **Token State Scenarios**: Valid tokens, expired tokens, successful refresh, failed refresh
- **Biometric Integration**: End-to-end biometric authentication with session management
- **Foreground Token Refresh**: Automatic token refresh scenarios when app returns to foreground
- **Session Timeout Validation**: User activity tracking and inactivity timeout testing
- **Authentication-to-Logout Flow**: Complete user journey from login to logout

#### Key Integration Test Coverage
```swift
// Example integration test structure
class SessionManagementIntegrationTest: XCTestCase {
    func testCompleteSessionLifecycleWithValidTokens() async
    func testSessionLifecycleWithExpiredTokensAndSuccessfulRefresh() async
    func testSessionLifecycleWithBiometricAuthentication() async
    func testForegroundTokenRefreshIntegration() async
    func testCompleteAuthenticationToLogoutFlow() async
}
```

#### Mock-Based Testing
- **Real Component Interactions**: Tests use actual component implementations with mocked dependencies
- **Dependency Injection**: Comprehensive mocking of external dependencies (keychain, network, biometrics)
- **State Verification**: Validates proper state transitions and data persistence
- **Error Scenario Testing**: Comprehensive error handling and recovery testing

### UI Testing

- **User Interactions**: Login form interactions and validation
- **Navigation Testing**: State-based navigation between authentication states
- **Accessibility**: VoiceOver and Dynamic Type support
- **Biometric UI Testing**: Biometric setup and authentication flows

## Performance Considerations

### Memory Management

- **Weak References**: Prevent retain cycles in closures
- **Automatic Reference Counting**: Proper ARC usage
- **Resource Cleanup**: Timer invalidation and cancellable cleanup

### Network Optimization

- **Connection Reuse**: URLSession connection pooling
- **Request Caching**: Appropriate cache policies
- **Background Tasks**: Proper background task handling

### UI Performance

- **Main Actor**: UI updates on main thread
- **Lazy Loading**: Efficient view loading
- **Animation Performance**: Smooth state transitions

## Scalability

### Multi-Provider Support

- **Configuration-Driven**: Providers defined in `IdentityProviders.plist`
- **Dynamic Loading**: Runtime provider selection from configured providers
- **Demo Providers**: Pre-configured Keycloak and Auth0 demo providers
- **Extensible**: Easy addition of new providers through configuration

### Feature Extension

- **Modular Design**: Clear component boundaries
- **Protocol Extensions**: Easy feature additions
- **Configuration Options**: Flexible app behavior

This architecture provides a solid foundation for a secure, maintainable, and scalable iOS authentication application.