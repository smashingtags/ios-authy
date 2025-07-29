# Technology Stack

## Platform & Language
- **Platform**: iOS (native)
- **Language**: Swift
- **UI Framework**: SwiftUI (primary) with UIKit support
- **Architecture**: MVVM (Model-View-ViewModel)

## Core Frameworks
- **Foundation**: Core Swift functionality
- **Security**: Keychain Services for secure token storage
- **LocalAuthentication**: Biometric authentication (Face ID/Touch ID)
- **Network**: URLSession for HTTPS communication
- **Combine**: Reactive programming for data binding

## Authentication Protocols
- **OAuth 2.0**: Resource Owner Password Credentials flow
- **OpenID Connect**: Identity layer on top of OAuth 2.0
- **HTTPS**: All network communication must use TLS

## Development Tools
- **Xcode**: Primary IDE for iOS development
- **Swift Package Manager**: Dependency management (preferred)
- **CocoaPods/Carthage**: Alternative dependency managers if needed

## Testing Frameworks
- **XCTest**: Unit and integration testing
- **XCUITest**: UI automation testing
- **Quick/Nimble**: BDD-style testing (optional)

## Security Requirements
- All sensitive data stored in iOS Keychain with appropriate access controls
- Certificate pinning for enhanced network security
- Screen capture prevention for sensitive views
- Automatic screen obscuring when app enters background

## Common Commands

### Build & Run
```bash
# Open project in Xcode
open YourProject.xcodeproj

# Build from command line
xcodebuild -project YourProject.xcodeproj -scheme YourScheme build

# Run tests
xcodebuild test -project YourProject.xcodeproj -scheme YourScheme -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Package Management
```bash
# Add Swift Package dependency
# File > Add Package Dependencies in Xcode

# Install CocoaPods (if used)
pod install

# Update dependencies
pod update
```

### Code Quality
```bash
# SwiftLint (if configured)
swiftlint

# SwiftFormat (if configured)
swiftformat .
```