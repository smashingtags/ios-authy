import Foundation

protocol ConfigurationManagerProtocol {
    func loadProviders() throws -> [IdentityProvider]
    func getDefaultProvider() throws -> IdentityProvider
    func validateProvider(_ provider: IdentityProvider) throws
}

class ConfigurationManager: ConfigurationManagerProtocol {
    private let providersFileName = "IdentityProviders"
    
    func loadProviders() throws -> [IdentityProvider] {
        guard let url = Bundle.main.url(forResource: providersFileName, withExtension: "plist") else {
            throw AuthenticationError.configurationError("IdentityProviders.plist not found")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            throw AuthenticationError.configurationError("Failed to read IdentityProviders.plist")
        }
        
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
            throw AuthenticationError.configurationError("Failed to parse IdentityProviders.plist: \(error.localizedDescription)")
        }
    }
    
    func getDefaultProvider() throws -> IdentityProvider {
        let providers = try loadProviders()
        
        if let defaultProvider = providers.first(where: { $0.isDefault }) {
            return defaultProvider
        }
        
        guard let firstProvider = providers.first else {
            throw AuthenticationError.configurationError("No identity providers available")
        }
        
        return firstProvider
    }
    
    func validateProvider(_ provider: IdentityProvider) throws {
        // Validate URLs are HTTPS
        guard provider.authorizationEndpoint.scheme == "https" else {
            throw AuthenticationError.configurationError("Authorization endpoint must use HTTPS")
        }
        
        guard provider.tokenEndpoint.scheme == "https" else {
            throw AuthenticationError.configurationError("Token endpoint must use HTTPS")
        }
        
        if let userInfoEndpoint = provider.userInfoEndpoint {
            guard userInfoEndpoint.scheme == "https" else {
                throw AuthenticationError.configurationError("User info endpoint must use HTTPS")
            }
        }
        
        // Validate required fields
        guard !provider.id.isEmpty else {
            throw AuthenticationError.configurationError("Provider ID cannot be empty")
        }
        
        guard !provider.name.isEmpty else {
            throw AuthenticationError.configurationError("Provider name cannot be empty")
        }
        
        guard !provider.clientId.isEmpty else {
            throw AuthenticationError.configurationError("Client ID cannot be empty")
        }
        
        guard !provider.scope.isEmpty else {
            throw AuthenticationError.configurationError("Scope cannot be empty")
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