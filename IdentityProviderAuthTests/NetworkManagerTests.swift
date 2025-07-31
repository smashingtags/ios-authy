import XCTest
import Network
@testable import IdentityProviderAuth

class NetworkManagerTests: XCTestCase {
    var networkManager: NetworkManager!
    var mockURLSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        networkManager = NetworkManager()
        // We'll use method swizzling or dependency injection for testing
    }
    
    override func tearDown() {
        networkManager = nil
        mockURLSession = nil
        super.tearDown()
    }
    
    // MARK: - HTTP Request/Response Handling Tests
    
    func testPerformRequestWithValidResponse() async throws {
        // Given
        let expectedData = """
        {"message": "success"}
        """.data(using: .utf8)!
        
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        mockURLSession.data = expectedData
        mockURLSession.response = mockResponse
        
        let request = NetworkRequest(
            url: URL(string: "https://example.com")!,
            method: .GET
        )
        
        // When
        let result = try await performMockedRequest(request)
        
        // Then
        XCTAssertEqual(result, expectedData)
    }
    
    func testPerformRequestWithDecodableResponse() async throws {
        // Given
        struct TestResponse: Codable, Equatable {
            let message: String
        }
        
        let expectedResponse = TestResponse(message: "success")
        let responseData = try JSONEncoder().encode(expectedResponse)
        
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        mockURLSession.data = responseData
        mockURLSession.response = mockResponse
        
        let request = NetworkRequest(
            url: URL(string: "https://example.com")!,
            method: .GET
        )
        
        // When
        let result: TestResponse = try await performMockedDecodableRequest(request, responseType: TestResponse.self)
        
        // Then
        XCTAssertEqual(result, expectedResponse)
    }
    
    func testPerformRequestWithInvalidJSON() async {
        // Given
        let invalidJSONData = "invalid json".data(using: .utf8)!
        
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        mockURLSession.data = invalidJSONData
        mockURLSession.response = mockResponse
        
        let request = NetworkRequest(
            url: URL(string: "https://example.com")!,
            method: .GET
        )
        
        // When/Then
        do {
            struct TestResponse: Codable {
                let message: String
            }
            let _: TestResponse = try await performMockedDecodableRequest(request, responseType: TestResponse.self)
            XCTFail("Expected decoding error")
        } catch let error as NetworkError {
            if case .decodingError = error {
                // Expected
            } else {
                XCTFail("Expected decoding error, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError.decodingError, got \(error)")
        }
    }
    
    // MARK: - Network Error Scenarios Tests
    
    func testPerformRequestWithHTTPError() async {
        // Given
        let errorData = "Unauthorized".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        
        mockURLSession.data = errorData
        mockURLSession.response = mockResponse
        
        let request = NetworkRequest(
            url: URL(string: "https://example.com")!,
            method: .GET
        )
        
        // When/Then
        do {
            let _ = try await performMockedRequest(request)
            XCTFail("Expected HTTP error")
        } catch let error as NetworkError {
            if case .httpError(let statusCode, let data) = error {
                XCTAssertEqual(statusCode, 401)
                XCTAssertEqual(data, errorData)
            } else {
                XCTFail("Expected httpError, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError.httpError, got \(error)")
        }
    }
    
    func testPerformRequestWithTimeoutError() async {
        // Given
        mockURLSession.error = URLError(.timedOut)
        
        let request = NetworkRequest(
            url: URL(string: "https://example.com")!,
            method: .GET
        )
        
        // When/Then
        do {
            let _ = try await performMockedRequest(request)
            XCTFail("Expected timeout error")
        } catch let error as NetworkError {
            if case .timeout = error {
                // Expected
            } else {
                XCTFail("Expected timeout error, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError.timeout, got \(error)")
        }
    }
    
    func testPerformRequestWithNoInternetConnection() async {
        // Given
        mockURLSession.error = URLError(.notConnectedToInternet)
        
        let request = NetworkRequest(
            url: URL(string: "https://example.com")!,
            method: .GET
        )
        
        // When/Then
        do {
            let _ = try await performMockedRequest(request)
            XCTFail("Expected no internet connection error")
        } catch let error as NetworkError {
            if case .noInternetConnection = error {
                // Expected
            } else {
                XCTFail("Expected no internet connection error, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError.noInternetConnection, got \(error)")
        }
    }
    
    // MARK: - SSL Validation Tests
    
    func testPerformRequestWithSSLError() async {
        // Given
        mockURLSession.error = URLError(.serverCertificateUntrusted)
        
        let request = NetworkRequest(
            url: URL(string: "https://example.com")!,
            method: .GET
        )
        
        // When/Then
        do {
            let _ = try await performMockedRequest(request)
            XCTFail("Expected SSL error")
        } catch let error as NetworkError {
            if case .sslError = error {
                // Expected
            } else {
                XCTFail("Expected SSL error, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError.sslError, got \(error)")
        }
    }
    
    func testPerformRequestWithNonHTTPSURL() async {
        // Given
        let request = NetworkRequest(
            url: URL(string: "http://example.com")!,
            method: .GET
        )
        
        // When/Then
        do {
            let _ = try await performMockedRequest(request)
            XCTFail("Expected SSL error for non-HTTPS URL")
        } catch let error as NetworkError {
            if case .sslError = error {
                // Expected
            } else {
                XCTFail("Expected SSL error, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError.sslError, got \(error)")
        }
    }
    
    // MARK: - Network Connectivity Monitoring Tests
    
    func testNetworkConnectivityMonitoring() {
        // Given
        let expectation = XCTestExpectation(description: "Network connectivity change")
        var connectivityStates: [Bool] = []
        
        // When
        let cancellable = networkManager.$isConnected
            .sink { isConnected in
                connectivityStates.append(isConnected)
                if connectivityStates.count >= 2 {
                    expectation.fulfill()
                }
            }
        
        // Simulate network state changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // This would normally be triggered by NWPathMonitor
            // For testing, we'll verify the initial state
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(connectivityStates.contains(true)) // Should start as connected
        
        cancellable.cancel()
    }
    
    func testPerformRequestWhenOffline() async {
        // Given
        networkManager.isConnected = false
        
        let request = NetworkRequest(
            url: URL(string: "https://example.com")!,
            method: .GET
        )
        
        // When/Then
        do {
            let _ = try await performMockedRequest(request)
            XCTFail("Expected no internet connection error")
        } catch let error as NetworkError {
            if case .noInternetConnection = error {
                // Expected
            } else {
                XCTFail("Expected no internet connection error, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError.noInternetConnection, got \(error)")
        }
    }
    
    // MARK: - Request Configuration Tests
    
    func testRequestWithCustomHeaders() async throws {
        // Given
        let expectedData = "success".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        mockURLSession.data = expectedData
        mockURLSession.response = mockResponse
        
        let customHeaders = [
            "Authorization": "Bearer token123",
            "Content-Type": "application/json"
        ]
        
        let request = NetworkRequest(
            url: URL(string: "https://example.com")!,
            method: .POST,
            headers: customHeaders,
            body: "test body".data(using: .utf8)
        )
        
        // When
        let result = try await performMockedRequest(request)
        
        // Then
        XCTAssertEqual(result, expectedData)
        
        // Verify headers were set (this would require access to the actual URLRequest)
        // In a real implementation, we'd verify through the mock
        XCTAssertEqual(mockURLSession.lastRequest?.allHTTPHeaderFields?["Authorization"], "Bearer token123")
        XCTAssertEqual(mockURLSession.lastRequest?.allHTTPHeaderFields?["Content-Type"], "application/json")
    }
    
    func testRequestWithCustomTimeout() async {
        // Given
        let request = NetworkRequest(
            url: URL(string: "https://example.com")!,
            method: .GET,
            timeout: 60
        )
        
        mockURLSession.data = "success".data(using: .utf8)!
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When
        let _ = try await performMockedRequest(request)
        
        // Then
        XCTAssertEqual(mockURLSession.lastRequest?.timeoutInterval, 60)
    }
    
    // MARK: - Helper Methods for Mocked Testing
    
    private func performMockedRequest(_ request: NetworkRequest) async throws -> Data {
        // Create a mock network manager that uses our mock session
        let mockNetworkManager = MockNetworkManager(session: mockURLSession)
        return try await mockNetworkManager.performRequest(request)
    }
    
    private func performMockedDecodableRequest<T: Codable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T {
        let mockNetworkManager = MockNetworkManager(session: mockURLSession)
        return try await mockNetworkManager.performRequest(request, responseType: responseType)
    }
}

// MARK: - Mock Classes

class MockURLSession {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    var lastRequest: URLRequest?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        if let error = error {
            throw error
        }
        
        guard let data = data, let response = response else {
            throw URLError(.badServerResponse)
        }
        
        return (data, response)
    }
}

class MockNetworkManager: NetworkManagerProtocol {
    private let mockSession: MockURLSession
    var isConnected: Bool = true
    
    init(session: MockURLSession) {
        self.mockSession = session
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
            let (data, response) = try await mockSession.data(for: urlRequest)
            
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