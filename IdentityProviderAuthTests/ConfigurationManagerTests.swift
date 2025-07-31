import XCTest
@testable import IdentityProviderAuth

class ConfigurationManagerTests: XCTestCase {
    var configurationManager: ConfigurationManager!
    var mockBundle: MockBundle!
    
    override func setUp() {
        super.setUp()
        mockBundle = MockBundle()
        configurationManager = TestableConfigurationManager(bundle: mockBundle)
    }
    
    override func tearDown() {
        configurationManager = nil
        mockBundle = nil
        super.tearDown()
    }
    
    // MARK: - Provider Configuration Loading Tests
    
    func testLoadProvidersWithValidConfiguration() throws {
        // Given
        let validPlistData = createValidPlistData()
        mockBundle.mockPlistData = validPlistData
        
        // When
        let providers = try configurationManager.loadProviders()
        
        // Then
        XCTAssertEqual(providers.count, 2)
        
        let keycloakProvider = providers.first { $0.id == "keycloak-demo" }
        XCTAssertNotNil(keycloakProvider)
        XCTAssertEqual(keycloakProvider?.name, "keycloak")
        XCTAssertEqual(keycloakProvider?.displayName, "Keycloak Demo")
        XCTAssertEqual(keycloakProvider?.clientId, "demo-client")
        XCTAssertEqual(keycloakProvider?.scope, "openid profile email")
        XCTAssertTrue(keycloakProvider?.isDefault ?? false)
        
        let auth0Provider = providers.first { $0.id == "auth0-demo" }
        XCTAssertNotNil(auth0Provider)
        XCTAssertEqual(auth0Provider?.name, "auth0")
        XCTAssertEqual(auth0Provider?.displayName, "Auth0 Demo")
        XCTAssertFalse(auth0Provider?.isDefault ?? true)
    }
    
    func testLoadProvidersWithMissingPlistFile() {
        // Given
        mockBundle.shouldReturnNilURL = true
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.loadProviders()) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("IdentityProviders.plist not found"))
        }
    }
    
    func testLoadProvidersWithInvalidPlistData() {
        // Given
        mockBundle.mockPlistData = "invalid plist data".data(using: .utf8)!
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.loadProviders()) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Failed to parse IdentityProviders.plist"))
        }
    }
    
    func testLoadProvidersWithEmptyConfiguration() {
        // Given
        let emptyPlistData = try! PropertyListSerialization.data(fromPropertyList: [], format: .xml, options: 0)
        mockBundle.mockPlistData = emptyPlistData
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.loadProviders()) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("No identity providers configured"))
        }
    }
    
    func testLoadProvidersWithMissingRequiredFields() {
        // Given
        let invalidProviderData = [
            [
                "id": "incomplete-provider",
                "name": "Incomplete Provider"
                // Missing required fields
            ]
        ]
        let plistData = try! PropertyListSerialization.data(fromPropertyList: invalidProviderData, format: .xml, options: 0)
        mockBundle.mockPlistData = plistData
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.loadProviders()) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Missing required provider configuration fields"))
        }
    }
    
    func testLoadProvidersWithInvalidURLs() {
        // Given
        let invalidURLProviderData = [
            [
                "id": "invalid-url-provider",
                "name": "Invalid URL Provider",
                "displayName": "Invalid URL Provider",
                "authorizationEndpoint": "not-a-valid-url",
                "tokenEndpoint": "also-not-valid",
                "clientId": "test-client",
                "scope": "openid profile",
                "isDefault": false
            ]
        ]
        let plistData = try! PropertyListSerialization.data(fromPropertyList: invalidURLProviderData, format: .xml, options: 0)
        mockBundle.mockPlistData = plistData
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.loadProviders()) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Invalid endpoint URLs"))
        }
    }
    
    // MARK: - Multiple Provider Support Tests
    
    func testLoadMultipleProviders() throws {
        // Given
        let multipleProvidersData = createValidPlistData()
        mockBundle.mockPlistData = multipleProvidersData
        
        // When
        let providers = try configurationManager.loadProviders()
        
        // Then
        XCTAssertEqual(providers.count, 2)
        
        let providerIds = providers.map { $0.id }
        XCTAssertTrue(providerIds.contains("keycloak-demo"))
        XCTAssertTrue(providerIds.contains("auth0-demo"))
    }
    
    func testGetDefaultProviderWithExplicitDefault() throws {
        // Given
        let validPlistData = createValidPlistData()
        mockBundle.mockPlistData = validPlistData
        
        // When
        let defaultProvider = try configurationManager.getDefaultProvider()
        
        // Then
        XCTAssertEqual(defaultProvider.id, "keycloak-demo")
        XCTAssertTrue(defaultProvider.isDefault)
    }
    
    func testGetDefaultProviderWithoutExplicitDefault() throws {
        // Given
        let providersWithoutDefault = [
            [
                "id": "provider1",
                "name": "Provider 1",
                "displayName": "Provider 1",
                "authorizationEndpoint": "https://example1.com/auth",
                "tokenEndpoint": "https://example1.com/token",
                "clientId": "client1",
                "scope": "openid profile",
                "isDefault": false
            ],
            [
                "id": "provider2",
                "name": "Provider 2",
                "displayName": "Provider 2",
                "authorizationEndpoint": "https://example2.com/auth",
                "tokenEndpoint": "https://example2.com/token",
                "clientId": "client2",
                "scope": "openid profile",
                "isDefault": false
            ]
        ]
        let plistData = try! PropertyListSerialization.data(fromPropertyList: providersWithoutDefault, format: .xml, options: 0)
        mockBundle.mockPlistData = plistData
        
        // When
        let defaultProvider = try configurationManager.getDefaultProvider()
        
        // Then
        XCTAssertEqual(defaultProvider.id, "provider1") // Should return first provider
    }
    
    func testGetDefaultProviderWithNoProviders() {
        // Given
        let emptyPlistData = try! PropertyListSerialization.data(fromPropertyList: [], format: .xml, options: 0)
        mockBundle.mockPlistData = emptyPlistData
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.getDefaultProvider()) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("No identity providers configured"))
        }
    }
    
    // MARK: - Configuration Validation Tests
    
    func testValidateProviderWithValidConfiguration() throws {
        // Given
        let validProvider = IdentityProvider(
            id: "valid-provider",
            name: "Valid Provider",
            displayName: "Valid Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: URL(string: "https://example.com/userinfo")!,
            clientId: "valid-client-id",
            scope: "openid profile",
            isDefault: true
        )
        
        // When/Then
        XCTAssertNoThrow(try configurationManager.validateProvider(validProvider))
    }
    
    func testValidateProviderWithNonHTTPSAuthEndpoint() {
        // Given
        let invalidProvider = IdentityProvider(
            id: "invalid-provider",
            name: "Invalid Provider",
            displayName: "Invalid Provider",
            authorizationEndpoint: URL(string: "http://example.com/auth")!, // HTTP instead of HTTPS
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: nil,
            clientId: "client-id",
            scope: "openid profile",
            isDefault: false
        )
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.validateProvider(invalidProvider)) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Authorization endpoint must use HTTPS"))
        }
    }
    
    func testValidateProviderWithNonHTTPSTokenEndpoint() {
        // Given
        let invalidProvider = IdentityProvider(
            id: "invalid-provider",
            name: "Invalid Provider",
            displayName: "Invalid Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "http://example.com/token")!, // HTTP instead of HTTPS
            userInfoEndpoint: nil,
            clientId: "client-id",
            scope: "openid profile",
            isDefault: false
        )
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.validateProvider(invalidProvider)) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Token endpoint must use HTTPS"))
        }
    }
    
    func testValidateProviderWithNonHTTPSUserInfoEndpoint() {
        // Given
        let invalidProvider = IdentityProvider(
            id: "invalid-provider",
            name: "Invalid Provider",
            displayName: "Invalid Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: URL(string: "http://example.com/userinfo")!, // HTTP instead of HTTPS
            clientId: "client-id",
            scope: "openid profile",
            isDefault: false
        )
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.validateProvider(invalidProvider)) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("User info endpoint must use HTTPS"))
        }
    }
    
    func testValidateProviderWithEmptyId() {
        // Given
        let invalidProvider = IdentityProvider(
            id: "", // Empty ID
            name: "Provider",
            displayName: "Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: nil,
            clientId: "client-id",
            scope: "openid profile",
            isDefault: false
        )
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.validateProvider(invalidProvider)) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Provider ID cannot be empty"))
        }
    }
    
    func testValidateProviderWithEmptyName() {
        // Given
        let invalidProvider = IdentityProvider(
            id: "provider-id",
            name: "", // Empty name
            displayName: "Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: nil,
            clientId: "client-id",
            scope: "openid profile",
            isDefault: false
        )
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.validateProvider(invalidProvider)) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Provider name cannot be empty"))
        }
    }
    
    func testValidateProviderWithEmptyClientId() {
        // Given
        let invalidProvider = IdentityProvider(
            id: "provider-id",
            name: "Provider",
            displayName: "Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: nil,
            clientId: "", // Empty client ID
            scope: "openid profile",
            isDefault: false
        )
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.validateProvider(invalidProvider)) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Client ID cannot be empty"))
        }
    }
    
    func testValidateProviderWithEmptyScope() {
        // Given
        let invalidProvider = IdentityProvider(
            id: "provider-id",
            name: "Provider",
            displayName: "Provider",
            authorizationEndpoint: URL(string: "https://example.com/auth")!,
            tokenEndpoint: URL(string: "https://example.com/token")!,
            userInfoEndpoint: nil,
            clientId: "client-id",
            scope: "", // Empty scope
            isDefault: false
        )
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.validateProvider(invalidProvider)) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Scope cannot be empty"))
        }
    }
    
    // MARK: - Configuration Error Handling Tests
    
    func testLoadProvidersWithInvalidProviderValidation() {
        // Given
        let invalidProviderData = [
            [
                "id": "invalid-provider",
                "name": "Invalid Provider",
                "displayName": "Invalid Provider",
                "authorizationEndpoint": "http://example.com/auth", // Invalid HTTPS
                "tokenEndpoint": "https://example.com/token",
                "clientId": "client-id",
                "scope": "openid profile",
                "isDefault": false
            ]
        ]
        let plistData = try! PropertyListSerialization.data(fromPropertyList: invalidProviderData, format: .xml, options: 0)
        mockBundle.mockPlistData = plistData
        
        // When/Then
        XCTAssertThrowsError(try configurationManager.loadProviders()) { error in
            guard let authError = error as? AuthenticationError,
                  case .configurationError(let message) = authError else {
                XCTFail("Expected configurationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Authorization endpoint must use HTTPS"))
        }
    }
    
    // MARK: - Helper Methods
    
    private func createValidPlistData() -> Data {
        let providersData = [
            [
                "id": "keycloak-demo",
                "name": "keycloak",
                "displayName": "Keycloak Demo",
                "authorizationEndpoint": "https://demo.keycloak.org/auth/realms/demo/protocol/openid-connect/auth",
                "tokenEndpoint": "https://demo.keycloak.org/auth/realms/demo/protocol/openid-connect/token",
                "userInfoEndpoint": "https://demo.keycloak.org/auth/realms/demo/protocol/openid-connect/userinfo",
                "clientId": "demo-client",
                "scope": "openid profile email",
                "isDefault": true
            ],
            [
                "id": "auth0-demo",
                "name": "auth0",
                "displayName": "Auth0 Demo",
                "authorizationEndpoint": "https://dev-example.auth0.com/authorize",
                "tokenEndpoint": "https://dev-example.auth0.com/oauth/token",
                "userInfoEndpoint": "https://dev-example.auth0.com/userinfo",
                "clientId": "your-client-id",
                "scope": "openid profile email",
                "isDefault": false
            ]
        ]
        
        return try! PropertyListSerialization.data(fromPropertyList: providersData, format: .xml, options: 0)
    }
}

// MARK: - Mock Classes

class MockBundle {
    var shouldReturnNilURL = false
    var mockPlistData: Data?
    
    func url(forResource name: String?, withExtension ext: String?) -> URL? {
        if shouldReturnNilURL {
            return nil
        }
        return URL(string: "file://mock/path/\(name ?? "").\(ext ?? "")")
    }
    
    func data(contentsOf url: URL) throws -> Data {
        guard let data = mockPlistData else {
            throw NSError(domain: "MockBundle", code: 1, userInfo: [NSLocalizedDescriptionKey: "No mock data provided"])
        }
        return data
    }
}

class TestableConfigurationManager: ConfigurationManager {
    private let mockBundle: MockBundle
    
    init(bundle: MockBundle) {
        self.mockBundle = bundle
        super.init()
    }
    
    override func loadProviders() throws -> [IdentityProvider] {
        guard let url = mockBundle.url(forResource: "IdentityProviders", withExtension: "plist") else {
            throw AuthenticationError.configurationError("IdentityProviders.plist not found")
        }
        
        let data = try mockBundle.data(contentsOf: url)
        
        do {
            let plistData = try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] ?? []
            let providers = try plistData.map { dict -> IdentityProvider in
                try parseProvider(from: dict)
            }
            
            guard !providers.isEmpty else {
                throw AuthenticationError.configurationError("No identity providers configured")
            }
            
            // Validate all providers
            for provider in providers {
                try validateProvider(provider)
            }
            
            return providers
        } catch {
            if error is AuthenticationError {
                throw error
            }
            throw AuthenticationError.configurationError("Failed to parse IdentityProviders.plist: \(error.localizedDescription)")
        }
    }
    
    private func parseProvider(from dict: [String: Any]) throws -> IdentityProvider {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let displayName = dict["displayName"] as? String,
              let authEndpointString = dict["authorizationEndpoint"] as? String,
              let tokenEndpointString = dict["tokenEndpoint"] as? String,
              let clientId = dict["clientId"] as? String,
              let scope = dict["scope"] as? String else {
            throw AuthenticationError.configurationError("Missing required provider configuration fields")
        }
        
        guard let authEndpoint = URL(string: authEndpointString),
              let tokenEndpoint = URL(string: tokenEndpointString) else {
            throw AuthenticationError.configurationError("Invalid endpoint URLs")
        }
        
        let userInfoEndpoint = (dict["userInfoEndpoint"] as? String).flatMap { URL(string: $0) }
        let isDefault = dict["isDefault"] as? Bool ?? false
        
        return IdentityProvider(
            id: id,
            name: name,
            displayName: displayName,
            authorizationEndpoint: authEndpoint,
            tokenEndpoint: tokenEndpoint,
            userInfoEndpoint: userInfoEndpoint,
            clientId: clientId,
            scope: scope,
            isDefault: isDefault
        )
    }
}