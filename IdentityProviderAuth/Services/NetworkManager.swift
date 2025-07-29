import Foundation
import Network

protocol NetworkManagerProtocol {
    func performRequest<T: Codable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T
    func performRequest(_ request: NetworkRequest) async throws -> Data
    var isConnected: Bool { get }
}

class NetworkManager: NetworkManagerProtocol, ObservableObject {
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        
        self.session = URLSession(configuration: configuration)
        
        startNetworkMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    func performRequest<T: Codable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T {
        let data = try await performRequest(request)
        
        do {
            return try JSONDecoder().decode(responseType, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    func performRequest(_ request: NetworkRequest) async throws -> Data {
        guard isConnected else {
            throw NetworkError.noInternetConnection
        }
        
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        
        // Set headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set body for POST requests
        if let body = request.body {
            urlRequest.httpBody = body
        }
        
        // Ensure HTTPS
        guard request.url.scheme == "https" else {
            throw NetworkError.sslError
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidURL
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.httpError(httpResponse.statusCode, data)
            }
            
            return data
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw NetworkError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.noInternetConnection
            case .serverCertificateUntrusted, .secureConnectionFailed:
                throw NetworkError.sslError
            default:
                throw NetworkError.httpError(error.errorCode, nil)
            }
        } catch {
            throw error
        }
    }
}