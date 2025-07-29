import Foundation

protocol IdentityProviderServiceProtocol {
    func authenticate(credentials: Credentials, provider: IdentityProvider) async throws -> AuthTokens
    func refreshToken(_ refreshToken: String, provider: IdentityProvider) async throws -> AuthTokens
    func getUserInfo(accessToken: String, provider: IdentityProvider) async throws -> User
}

class IdentityProviderService: IdentityProviderServiceProtocol {
    private let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol = NetworkManager()) {
        self.networkManager = networkManager
    }
    
    func authenticate(credentials: Credentials, provider: IdentityProvider) async throws -> AuthTokens {
        let tokenRequest = TokenRequest(
            grantType: "password",
            username: credentials.username,
            password: credentials.password,
            clientId: provider.clientId,
            scope: provider.scope
        )
        
        let requestBody = try createFormURLEncodedBody(from: tokenRequest)
        
        let networkRequest = NetworkRequest(
            url: provider.tokenEndpoint,
            method: .POST,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json"
            ],
            body: requestBody
        )
        
        do {
            let tokenResponse = try await networkManager.performRequest(networkRequest, responseType: TokenResponse.self)
            
            return AuthTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                tokenType: tokenResponse.tokenType,
                expiresIn: tokenResponse.expiresIn,
                scope: tokenResponse.scope,
                idToken: tokenResponse.idToken,
                issuedAt: Date()
            )
        } catch let networkError as NetworkError {
            switch networkError {
            case .httpError(401, _):
                throw AuthenticationError.invalidCredentials
            case .httpError(let code, let data):
                let message = data.flatMap { String(data: $0, encoding: .utf8) }
                throw AuthenticationError.serverError(code, message)
            default:
                throw AuthenticationError.networkError(networkError)
            }
        } catch {
            throw AuthenticationError.unknownError(error)
        }
    }
    
    func refreshToken(_ refreshToken: String, provider: IdentityProvider) async throws -> AuthTokens {
        let refreshRequest = RefreshTokenRequest(
            grantType: "refresh_token",
            refreshToken: refreshToken,
            clientId: provider.clientId
        )
        
        let requestBody = try createFormURLEncodedBody(from: refreshRequest)
        
        let networkRequest = NetworkRequest(
            url: provider.tokenEndpoint,
            method: .POST,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json"
            ],
            body: requestBody
        )
        
        do {
            let tokenResponse = try await networkManager.performRequest(networkRequest, responseType: TokenResponse.self)
            
            return AuthTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken ?? refreshToken,
                tokenType: tokenResponse.tokenType,
                expiresIn: tokenResponse.expiresIn,
                scope: tokenResponse.scope,
                idToken: tokenResponse.idToken,
                issuedAt: Date()
            )
        } catch let networkError as NetworkError {
            switch networkError {
            case .httpError(401, _):
                throw AuthenticationError.tokenExpired
            case .httpError(let code, let data):
                let message = data.flatMap { String(data: $0, encoding: .utf8) }
                throw AuthenticationError.serverError(code, message)
            default:
                throw AuthenticationError.networkError(networkError)
            }
        } catch {
            throw AuthenticationError.unknownError(error)
        }
    }
    
    func getUserInfo(accessToken: String, provider: IdentityProvider) async throws -> User {
        guard let userInfoEndpoint = provider.userInfoEndpoint else {
            // Create user from token if no userinfo endpoint
            return User(
                id: UUID().uuidString,
                username: "user",
                email: nil,
                displayName: nil,
                provider: provider.id
            )
        }
        
        let networkRequest = NetworkRequest(
            url: userInfoEndpoint,
            method: .GET,
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Accept": "application/json"
            ]
        )
        
        do {
            let userInfoResponse = try await networkManager.performRequest(networkRequest, responseType: UserInfoResponse.self)
            
            return User(
                id: userInfoResponse.sub,
                username: userInfoResponse.preferredUsername ?? userInfoResponse.sub,
                email: userInfoResponse.email,
                displayName: userInfoResponse.name,
                provider: provider.id
            )
        } catch let networkError as NetworkError {
            switch networkError {
            case .httpError(401, _):
                throw AuthenticationError.tokenExpired
            case .httpError(let code, let data):
                let message = data.flatMap { String(data: $0, encoding: .utf8) }
                throw AuthenticationError.serverError(code, message)
            default:
                throw AuthenticationError.networkError(networkError)
            }
        } catch {
            throw AuthenticationError.unknownError(error)
        }
    }
    
    private func createFormURLEncodedBody<T: Codable>(from object: T) throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        let formComponents = dictionary.compactMap { key, value -> String? in
            guard let stringValue = value as? String else { return nil }
            return "\(key)=\(stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        
        return formComponents.joined(separator: "&").data(using: .utf8) ?? Data()
    }
}