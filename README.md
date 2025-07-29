# iOS Identity Provider Authentication App

A native iOS application that provides secure authentication through configurable identity providers using OAuth 2.0 and OpenID Connect protocols.

## Features

- **Native iOS Authentication**: Clean SwiftUI interface with username/password login
- **OAuth 2.0 & OpenID Connect**: Support for standard authentication protocols
- **Secure Token Storage**: Uses iOS Keychain Services for secure token management
- **Biometric Authentication**: Face ID/Touch ID support for returning users
- **Multi-Provider Support**: Configure multiple identity providers
- **Automatic Token Refresh**: Seamless session management
- **Network Resilience**: Handles connectivity issues and service unavailability
- **Security First**: HTTPS-only communication, screen capture prevention

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
│   ├── BiometricManager.swift           # Face ID/Touch ID
│   └── ConfigurationManager.swift       # Provider configuration
├── Views/
│   ├── ContentView.swift                # Main app coordinator
│   ├── LoginView.swift                  # Authentication UI
│   └── MainAppView.swift                # Post-auth interface
└── Configuration/
    └── IdentityProviders.plist          # Provider configurations (Keycloak & Auth0 demos)
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

The app includes pre-configured demo providers for testing:

#### Keycloak Demo (Default)
- **Provider**: Keycloak Demo Server
- **Endpoint**: `https://demo.keycloak.org`
- **Client ID**: `demo-client`
- **Test Credentials**: Available on Keycloak demo site

#### Auth0 Demo
- **Provider**: Auth0 Demo (requires configuration)
- **Endpoint**: `https://dev-example.auth0.com`
- **Client ID**: Update with your Auth0 client ID
- **Configuration**: Replace with your Auth0 domain and client details

## Usage

### Authentication Flow

1. **Launch**: App checks for existing valid tokens
2. **Biometric Prompt**: If available and previously authenticated
3. **Login Screen**: Username/password authentication
4. **Provider Selection**: Choose from configured providers (if multiple)
5. **Main App**: Access authenticated features
6. **Automatic Refresh**: Tokens refreshed automatically

### Security Features

- **Keychain Storage**: All tokens stored securely in iOS Keychain
- **HTTPS Only**: All network communication uses TLS
- **Biometric Protection**: Optional Face ID/Touch ID authentication
- **Screen Protection**: Prevents screenshots of sensitive screens
- **Session Management**: Automatic logout on token expiration

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
```

### Dependencies

- **Foundation**: Core Swift functionality
- **SwiftUI**: User interface framework
- **Security**: Keychain Services
- **LocalAuthentication**: Biometric authentication
- **Network**: Connectivity monitoring
- **Combine**: Reactive programming

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