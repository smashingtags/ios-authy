# Project Structure

## Root Directory Organization
```
/
├── .kiro/                    # Kiro AI assistant configuration
│   ├── specs/               # Feature specifications and design docs
│   └── steering/            # AI assistant steering rules
├── YourApp/                 # Main iOS application source code
├── YourAppTests/            # Unit and integration tests
├── YourAppUITests/          # UI automation tests
└── YourApp.xcodeproj        # Xcode project file
```

## Source Code Structure (YourApp/)
```
YourApp/
├── App/
│   ├── AppDelegate.swift           # App lifecycle management
│   ├── SceneDelegate.swift         # Scene lifecycle (if using UIKit)
│   └── YourAppApp.swift           # SwiftUI app entry point
├── Models/
│   ├── AuthenticationModels.swift  # Auth-related data models
│   ├── NetworkModels.swift         # Network request/response models
│   └── ConfigurationModels.swift   # Identity provider configurations
├── Services/
│   ├── AuthenticationManager.swift # Central auth coordinator
│   ├── IdentityProviderService.swift # OAuth/OIDC implementation
│   ├── NetworkManager.swift        # HTTP communication layer
│   └── ConfigurationManager.swift  # Provider config management
├── Managers/
│   ├── KeychainManager.swift       # Secure token storage
│   └── BiometricManager.swift      # Face ID/Touch ID handling
├── ViewModels/
│   ├── LoginViewModel.swift        # Login screen business logic
│   └── MainAppViewModel.swift      # Main app state management
├── Views/
│   ├── LoginView.swift             # Authentication UI
│   ├── MainAppView.swift           # Post-auth interface
│   └── Components/                 # Reusable UI components
│       ├── LoadingIndicator.swift
│       ├── ErrorAlert.swift
│       └── SecureTextField.swift
├── Extensions/
│   ├── String+Extensions.swift     # String utilities
│   ├── View+Extensions.swift       # SwiftUI view helpers
│   └── Error+Extensions.swift      # Error handling utilities
├── Resources/
│   ├── Assets.xcassets            # Images, colors, icons
│   ├── Localizable.strings        # Localized text
│   └── Info.plist                 # App configuration
└── Configuration/
    └── IdentityProviders.plist    # Provider configurations
```

## Architecture Patterns

### MVVM Implementation
- **Models**: Data structures and business entities
- **Views**: SwiftUI views for UI presentation
- **ViewModels**: Business logic and state management
- **Services**: External API communication and data processing
- **Managers**: System-level operations (keychain, biometrics)

### Protocol-Oriented Design
- All major components defined with protocols for testability
- Dependency injection for loose coupling
- Mock implementations for unit testing

### Error Handling Strategy
- Centralized error types in Models/
- Localized error messages in Resources/
- Consistent error propagation through async/await

## File Naming Conventions
- **Swift files**: PascalCase (e.g., `AuthenticationManager.swift`)
- **Test files**: Original name + `Tests` (e.g., `AuthenticationManagerTests.swift`)
- **UI components**: Descriptive names ending in purpose (e.g., `LoginView.swift`)
- **Extensions**: Original type + `Extensions` (e.g., `String+Extensions.swift`)

## Testing Structure
```
YourAppTests/
├── Models/                    # Model unit tests
├── Services/                  # Service layer tests
├── Managers/                  # Manager component tests
├── ViewModels/                # ViewModel logic tests
├── Mocks/                     # Mock implementations
└── TestHelpers/               # Testing utilities

YourAppUITests/
├── LoginFlowTests.swift       # Authentication UI tests
├── MainAppFlowTests.swift     # Post-auth UI tests
└── AccessibilityTests.swift   # Accessibility compliance tests
```

## Configuration Management
- Identity provider configs in `Configuration/IdentityProviders.plist`
- App settings in `Info.plist`
- Build configurations for different environments (Debug/Release)
- Sensitive values (client secrets) managed through build settings or external config