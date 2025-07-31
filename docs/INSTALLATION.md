# Installation Guide

## Prerequisites

### Development Environment
- **Xcode**: Version 14.0 or later
- **iOS Deployment Target**: iOS 15.0 or later
- **macOS**: macOS 12.0 (Monterey) or later
- **Swift**: Swift 5.7 or later

### Hardware Requirements
- **Mac**: Intel or Apple Silicon Mac for development
- **iOS Device**: iPhone or iPad for testing (optional, can use simulator)
- **Biometric Hardware**: Face ID or Touch ID capable device for biometric testing

## Installation Steps

### 1. Clone or Download Project

If you have the project in a repository:
```bash
git clone <repository-url>
cd ios-identity-provider-auth
```

Or if you have the project files, ensure they're organized in the structure shown in the README.

### 2. Open Project in Xcode

```bash
open IdentityProviderAuth.xcodeproj
```

Or launch Xcode and open the project file manually.

### 3. Configure Project Settings

#### Bundle Identifier
1. Select the project in Xcode navigator
2. Select the target under "TARGETS"
3. In the "General" tab, update the "Bundle Identifier" to your unique identifier:
   ```
   com.yourcompany.identityproviderauth
   ```

#### Signing & Capabilities
1. In the "Signing & Capabilities" tab
2. Select your development team
3. Ensure "Automatically manage signing" is checked
4. Add capabilities if needed:
   - **Keychain Sharing** (if sharing keychain with other apps)
   - **App Groups** (if using shared containers)

### 4. Configure Identity Providers

Edit `IdentityProviderAuth/Configuration/IdentityProviders.plist`:

#### For Testing with Keycloak Demo
The default configuration includes a Keycloak demo server. No changes needed for basic testing.

#### For Production Use
Replace the demo configuration with your actual identity provider:

```xml
<dict>
    <key>id</key>
    <string>your-provider-id</string>
    <key>name</key>
    <string>your-provider</string>
    <key>displayName</key>
    <string>Your Identity Provider</string>
    <key>authorizationEndpoint</key>
    <string>https://your-provider.com/auth/realms/your-realm/protocol/openid-connect/auth</string>
    <key>tokenEndpoint</key>
    <string>https://your-provider.com/auth/realms/your-realm/protocol/openid-connect/token</string>
    <key>userInfoEndpoint</key>
    <string>https://your-provider.com/auth/realms/your-realm/protocol/openid-connect/userinfo</string>
    <key>clientId</key>
    <string>your-client-id</string>
    <key>scope</key>
    <string>openid profile email</string>
    <key>isDefault</key>
    <true/>
</dict>
```

### 5. Build and Run

#### Using Xcode
1. Select your target device or simulator
2. Press `⌘+R` or click the "Run" button
3. The app will build and launch

#### Using Command Line
```bash
# Build the project
xcodebuild -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuth build

# Run on simulator
xcodebuild -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuth -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests
xcodebuild test -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuth -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Configuration Options

### App Transport Security (ATS)

If you need to connect to non-HTTPS endpoints during development (not recommended for production), you can modify `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>your-dev-server.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Warning**: Only use this for development. Production apps should use HTTPS only.

### Biometric Authentication

Biometric authentication requires the following in `Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>This app uses Face ID for secure authentication</string>
```

This is already included in the project configuration.

### Background App Refresh

For automatic token refresh in background, add to `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-processing</string>
</array>
```

## Testing Setup

### Unit Testing
The project includes unit tests that can be run with:
```bash
⌘+U in Xcode
# or
xcodebuild test -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuth
```

### UI Testing
UI tests can be run with:
```bash
# Select UI Test scheme and run
xcodebuild test -project IdentityProviderAuth.xcodeproj -scheme IdentityProviderAuthUITests
```

### Manual Testing

#### Test Credentials

**Keycloak Demo Server:**
- **URL**: https://demo.keycloak.org
- **Realm**: demo
- **Client ID**: demo-client
- **Test Credentials**: Create a test account on the demo server or use existing demo credentials

**Auth0 Demo:**
- **Configuration Required**: Update the Auth0 configuration with your own Auth0 domain and client ID
- **Test Credentials**: Use your Auth0 test account credentials

#### Biometric Testing
1. Enable Face ID/Touch ID in iOS Simulator:
   - Device → Face ID/Touch ID → Enrolled
2. Test biometric authentication flow
3. Test biometric setup prompting on first use
4. Test user preference management (enable/disable biometric auth)
5. Test fallback to password authentication
6. Test smart setup prompting behavior

#### Session Management Testing
1. Test 30-minute inactivity timeout
2. Test user activity tracking (interactions reset timer)
3. Test app lifecycle behavior (foreground/background)
4. Test automatic token refresh on app foreground
5. Test session timeout during background state

## Deployment

### Development Deployment
1. Connect iOS device via USB
2. Select device in Xcode
3. Build and run (⌘+R)
4. Trust developer certificate on device if prompted

### TestFlight Deployment
1. Archive the app (Product → Archive)
2. Upload to App Store Connect
3. Configure TestFlight testing
4. Distribute to internal/external testers

### App Store Deployment
1. Complete TestFlight testing
2. Submit for App Store review
3. Configure App Store listing
4. Release to App Store

## Troubleshooting

### Common Build Issues

#### Code Signing Errors
- Ensure development team is selected
- Check bundle identifier is unique
- Verify certificates are valid

#### Missing Dependencies
- Ensure all source files are included in target
- Check framework linking
- Verify iOS deployment target

#### Configuration Errors
- Validate IdentityProviders.plist format
- Check all required keys are present
- Ensure URLs are valid and use HTTPS

### Runtime Issues

#### Network Connectivity
- Verify internet connection
- Check identity provider endpoints are accessible
- Validate SSL certificates

#### Keychain Errors
- Reset iOS Simulator (Device → Erase All Content and Settings)
- For device testing, may need to delete and reinstall app
- Check keychain access permissions

#### Biometric Authentication
- Ensure biometrics are enrolled on device/simulator
- Check Face ID/Touch ID permissions
- Verify LocalAuthentication framework is linked
- Test biometric setup prompting flow
- Verify user preference persistence across app launches

#### Session Management
- Test inactivity timeout behavior (30 minutes)
- Verify user activity tracking resets timeout
- Check app lifecycle handling (foreground/background)
- Test automatic token refresh on app resume
- Verify secure logout on session timeout

### Debug Logging

Enable debug logging by adding to your scheme's environment variables:
```
OS_ACTIVITY_MODE = disable
```

Or add custom logging in the code:
```swift
#if DEBUG
print("Debug: Authentication state changed to \(state)")
#endif
```

## Performance Optimization

### Build Optimization
- Use Release configuration for performance testing
- Enable whole module optimization
- Consider bitcode settings for distribution

### Runtime Optimization
- Monitor memory usage during authentication flows
- Profile network requests for performance
- Test on various device configurations

## Security Considerations

### Development Security
- Never commit real client secrets to version control
- Use different configurations for development/production
- Regularly update dependencies for security patches

### Production Security
- Implement certificate pinning
- Enable additional security features
- Regular security audits and penetration testing

This installation guide should get you up and running with the iOS Identity Provider Authentication App. For additional support, refer to the other documentation files or create an issue in the project repository.