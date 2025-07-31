# iOS Identity Provider Authentication App

A native iOS application that provides secure authentication through configurable identity providers using OAuth 2.0 and OpenID Connect protocols.

## Features

- **Native iOS Authentication**: Clean SwiftUI interface with username/password login
- **OAuth 2.0 & OpenID Connect**: Support for standard authentication protocols
- **Secure Token Storage**: Uses iOS Keychain Services for secure token management
- **Biometric Authentication**: Face ID/Touch ID/Optic ID support with user preference management
- **Multi-Provider Support**: Configure multiple identity providers
- **Automatic Token Refresh**: Seamless session management with proactive token renewal
- **Session Management**: 30-minute inactivity timeout with automatic logout
- **App Lifecycle Handling**: Automatic token refresh on app foreground and background security
- **Network Resilience**: Handles connectivity issues and service unavailability
- **Security First**: HTTPS-only communication, screen capture prevention
- **Smart Biometric Setup**: Intelligent prompting for biometric authentication setup

## Architecture

The app follows MVVM (Model-View-ViewModel) architecture with the following key components:

- **Models**: Data structures for authentication, network requests, and configuration
- **Services**: Authentication manager, identity provider service, network manager
- **Managers**: Keychain, biometric, and configuration managers
- **Views**: SwiftUI views for login, main app, and error states
- **ViewModels**: Business logic for UI components

## Project Structure

```
IdentityProviderAuth/
├── App/
│   └── IdentityProviderAuthApp.swift    # App entry point
├── Models/
│   ├── AuthenticationModels.swift       # Auth data models
│   └── NetworkModels.swift              # Network request/response models
├── Services/
│   ├── AuthenticationManager.swift      # Central auth coordinator
│   ├── IdentityProviderService.swift    # OAuth/OIDC implementation
│   └── NetworkManager.swift             # HTTP communication
├── Managers/
│   ├── KeychainManager.swift            # Secure token storage
│   ├── BiometricManager.swift           # Face ID/Touch ID/Optic ID
│   └── ConfigurationManager.swift       # Provider configuration
├── Views/
│   ├── ContentView.swift                # Main app coordinator
│   ├── LoginView.swift                  # Authentication UI
│   ├── MainAppView.swift                # Post-auth interface
│   ├── BiometricSetupView.swift         # Biometric setup prompting
│   └── BackgroundSecurityView.swift     # Background app security
├── Configuration/
│   └── IdentityProviders.plist          # Provider configurations (Keycloak & Auth0 demos)
├── Assets.xcassets/                     # App icons, colors, images
└── Preview Content/                     # SwiftUI preview assets
```

## Setup Instructions

### 1. Configure Identity Providers

Edit `IdentityProviderAuth/Configuration/IdentityProviders.plist` to add your identity providers:

```xml
<dict>
    <key>id</key>
    <string>your-provider-id</string>
    <key>name</key>
    <string>provider-name</string>
    <key>displayName</key>
    <string>Provider Display Name</string>
    <key>authorizationEndpoint</key>
    <string>https://your-provider.com/auth</string>
    <key>tokenEndpoint</key>
    <string>https://your-provider.com/token</string>
    <key>userInfoEndpoint</key>
    <string>https://your-provider.com/userinfo</string>
    <key>clientId</key>
    <string>your-client-id</string>
    <key>scope</key>
    <string>openid profile email</string>
    <key>isDefault</key>
    <true/>
</dict>
```

### 2. Build and Run

1. Open the project in Xcode
2. Select your target device or simulator
3. Build and run the project (⌘+R)

### 3. Testing

The app includes comprehensive test coverage with both unit and integration tests:

#### Test Structure
- **Unit Tests**: Individual component testing with mocked dependencies
- **Integration Tests**: End-to-end testing with real component interactions
- **Session Management Tests**: Comprehensive testing of authentication lifecycle
- **Keychain Manager Tests**: Complete keychain storage operations testing with real and mock implementations

#### Key Test Coverage
- Complete session lifecycle with various token states (valid, expired, refresh scenarios)
- Biometric authentication integration with session management
- Foreground token refresh with different expiration states
- Session timeout and user activity tracking validation
- Authentication-to-logout flow integration testing
- Error handling and recovery scenarios
- Mock-based testing for isolated component verification
- Comprehensive keychain operations testing with real and mock implementations

#### Integration Test Features
The `SessionManagementIntegrationTest` class provides comprehensive end-to-end testing:
- **Real Component Interactions**: Tests use actual component implementations with mocked dependencies
- **Complete Session Flows**: Validates entire authentication lifecycle from login to logout
- **Token State Management**: Tests all token scenarios (valid, expired, refresh success/failure)
- **Biometric Integration**: End-to-end biometric authentication with session management
- **App Lifecycle Testing**: Foreground/background transitions and token refresh scenarios
- **Error Recovery Testing**: Comprehensive error handling and recovery validation

#### Keychain Manager Test Features
The `KeychainManagerTests` class provides comprehensive keychain storage testing:
- **CRUD Operations Testing**: Complete testing of store, retrieve, delete, and deleteAll operations
- **Data Type Support**: Tests with AuthTokens, User, and IdentityProvider models
- **Error Handling**: Comprehensive error scenario testing and proper error propagation
- **Service Isolation**: Verification that different keychain services are properly isolated
- **Mock Integration**: MockKeychainManager with error simulation for isolated testing
- **Real vs Mock Consistency**: Integration tests ensuring mock behavior matches real keychain operations

#### Demo Providers for Testing

**Keycloak Demo (Default)**
- **Provider**: Keycloak Demo Server
- **Endpoint**: `https://demo.keycloak.org`
- **Client ID**: `demo-client`
- **Test Credentials**: Available on Keycloak demo site

**Auth0 Demo**
- **Provider**: Auth0 Demo (requires configuration)
- **Endpoint**: `https://dev-example.auth0.com`
- **Client ID**: Update with your Auth0 client ID
- **Configuration**: Replace with your Auth0 domain and client details

#### Running Tests

```bash
# Run all tests
xcodebuild test -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuth -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test suite
xcodebuild test -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuth -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IdentityProviderAuthTests/SessionManagementIntegrationTest

# Run keychain manager tests
xcodebuild test -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuth -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IdentityProviderAuthTests/KeychainManagerTests

# Run tests in Xcode
# Product > Test (⌘+U)
```

#### Test Architecture
The test suite includes three main categories:
- **KeychainManagerTests**: Comprehensive testing of secure storage operations with both real and mock implementations
- **SessionManagementIntegrationTest**: End-to-end authentication lifecycle testing
- **BiometricManagerTests**: Biometric authentication flow testing

Each test class includes both positive and negative test cases, error simulation, and integration scenarios to ensure robust functionality.

## Usage

### Authentication Flow

1. **Launch**: App checks for existing valid tokens
2. **Biometric Prompt**: If available and previously enabled by user
3. **Login Screen**: Username/password authentication with optional biometric fallback
4. **Provider Selection**: Choose from configured providers (if multiple)
5. **Biometric Setup**: Smart prompting for first-time biometric setup
6. **Main App**: Access authenticated features with biometric toggle
7. **Session Management**: 30-minute inactivity timeout with automatic logout
8. **Automatic Refresh**: Tokens refreshed automatically before expiration

### Security Features

- **Keychain Storage**: All tokens stored securely in iOS Keychain
- **HTTPS Only**: All network communication uses TLS
- **Biometric Protection**: Optional Face ID/Touch ID/Optic ID authentication
- **Screen Protection**: Prevents screenshots of sensitive screens
- **Session Management**: 30-minute inactivity timeout with automatic logout
- **App Lifecycle Security**: Automatic token refresh on foreground, secure background handling

### Biometric Authentication Features

- **Smart Setup Prompting**: Intelligent first-time setup that respects user choice
- **User Preference Management**: Persistent storage of biometric authentication preferences
- **Flexible Control**: Users can enable/disable biometric authentication at any time
- **Automatic Fallback**: Seamless fallback to password authentication when biometrics fail
- **Device Support**: Full support for Face ID, Touch ID, and Optic ID
- **Privacy First**: Biometric data never leaves the device

### Session Management Features

- **Inactivity Timeout**: Automatic logout after 30 minutes of user inactivity
- **Activity Tracking**: User interactions automatically reset the inactivity timer
- **App Lifecycle Handling**: Automatic token refresh when app returns to foreground
- **Background Security**: Session timeout continues running when app is in background
- **Proactive Token Refresh**: Tokens refreshed automatically when close to expiration
- **Secure Cleanup**: Proper cleanup of timers and resources on logout

## Configuration Options

### Identity Provider Settings

- `id`: Unique identifier for the provider
- `name`: Internal name for the provider
- `displayName`: User-facing name
- `authorizationEndpoint`: OAuth authorization URL
- `tokenEndpoint`: Token exchange URL
- `userInfoEndpoint`: User information URL (optional)
- `clientId`: OAuth client identifier
- `scope`: Requested OAuth scopes
- `isDefault`: Whether this is the default provider

### Security Requirements

- All endpoints must use HTTPS
- Client credentials should be configured securely
- Providers must support OAuth 2.0 Resource Owner Password Credentials flow
- OpenID Connect support recommended for user information

## Development

### Building

```bash
# Open in Xcode
open IdentityProviderAuth.xcodeproj

# Build from command line
xcodebuild -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuth build

# Run tests
xcodebuild test -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuth -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for device
xcodebuild -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuth -destination 'generic/platform=iOS' build
```

### Dependencies

- **Foundation**: Core Swift functionality
- **SwiftUI**: User interface framework
- **Security**: Keychain Services for secure token storage
- **LocalAuthentication**: Biometric authentication (Face ID/Touch ID/Optic ID)
- **Network**: Connectivity monitoring and HTTPS communication
- **Combine**: Reactive programming for state management

### Project Configuration

- **iOS Deployment Target**: iOS 17.0+
- **Swift Version**: 5.0
- **Xcode Version**: 15.0+
- **Bundle Identifier**: `com.example.IdentityProviderAuth`
- **Face ID Usage**: Configured with appropriate usage description
- **Supported Orientations**: Portrait and Landscape (iPhone and iPad)

## Troubleshooting

### Common Issues

1. **Configuration Errors**: Verify IdentityProviders.plist format and HTTPS URLs
2. **Network Issues**: Check internet connectivity and provider availability
3. **Keychain Errors**: May require app reinstall during development
4. **Biometric Failures**: Ensure device supports and has biometrics configured



### Error Messages

- "Invalid username or password": Check credentials and provider configuration
- "Network error": Verify internet connection and provider endpoints
- "Configuration error": Check IdentityProviders.plist format
- "Token expired": Automatic refresh failed, re-authentication required
- "Session timeout": User was inactive for 30 minutes and automatically logged out

## Documentation

For comprehensive information about this project, see the documentation in the `docs/` folder:

- **[Architecture Documentation](docs/ARCHITECTURE.md)**: Detailed architecture overview, design patterns, and component interactions
- **[Installation Guide](docs/INSTALLATION.md)**: Complete setup and configuration instructions
- **[Security Documentation](docs/SECURITY.md)**: Comprehensive security implementation details
- **[Project Status](docs/PROJECT_STATUS.md)**: Current implementation status and production readiness

## License

This project is provided as a reference implementation for iOS identity provider authentication.
## Troubleshooting

### Common Issues

**Build Errors**
- Ensure Xcode version compatibility
- Check iOS deployment target settings
- Verify code signing configuration

**Authentication Failures**
- Verify identity provider configuration
- Check network connectivity
- Review server-side OAuth settings

**Keychain Issues**
- Reset iOS Simulator if testing
- Check keychain access group configuration
- Verify app bundle identifier

## Recent Updates

The Xcode project file has been updated to include:
- Complete test target configuration with all test files
- Proper build phases for unit and integration tests
- Updated project structure reflecting all implemented components
- Full integration test suite for session management and biometric authentication

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

[Add your license information here]

## Support

For support and questions:
- Review the troubleshooting section
- Check the project issues
- Contact the development team

---

**Note**: This is an enterprise authentication application. Ensure proper security review and compliance with your organization's security policies before deployment.