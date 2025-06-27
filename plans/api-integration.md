# API Integration Plan for c11s-house-ios

## Executive Summary
This document outlines the integration strategy for connecting the iOS house consciousness app with the backend consciousness system APIs. The plan follows Test-Driven Development (TDD) principles and leverages modern Swift networking patterns.

## API Endpoint Analysis and Mapping

### Base Configuration
- **Production Base URL**: `https://api.consciousness.local/v1`
- **Development Base URL**: `http://localhost:8000/api/v1`
- **Demo Endpoints**: `/api/*` (non-authenticated for demo purposes)
- **WebSocket URL**: `/api/v1/realtime` (authenticated) or `/ws` (demo)

### Core API Endpoints

#### 1. Authentication
```
POST /api/v1/auth/login
Request: {username: String, password: String}
Response: {access_token: String, token_type: String, expires_in: Int}
```

#### 2. Consciousness System
```
GET  /api/v1/consciousness/status
GET  /api/v1/consciousness/emotions
POST /api/v1/consciousness/query
```

#### 3. Device Management
```
GET  /api/v1/devices
GET  /api/v1/devices/{device_id}
PUT  /api/v1/devices/{device_id}/control
POST /api/v1/devices/batch-control
```

#### 4. Memory System
```
GET  /api/v1/memory
POST /api/v1/memory
```

#### 5. Interview System
```
POST /api/v1/interview/start
POST /api/v1/interview/{interview_id}/message
GET  /api/v1/interview/{interview_id}/status
```

#### 6. Digital Twin & Predictions
```
GET  /api/v1/twins
POST /api/v1/twins
POST /api/v1/predictions/what-if
```

#### 7. Real-time WebSocket Events
- `consciousness_query`: Query results and responses
- `device_update`: Device state changes
- `batch_device_update`: Multiple device updates
- `interview_update`: Interview progress
- `status_update`: System status updates

## Network Layer Architecture

### 1. Core Networking Components

```swift
// NetworkConfiguration.swift
protocol NetworkConfiguration {
    var baseURL: URL { get }
    var headers: [String: String] { get }
    var timeout: TimeInterval { get }
}

// NetworkManager.swift
protocol NetworkManagerProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func requestRaw(_ endpoint: Endpoint) async throws -> Data
    func upload(_ endpoint: Endpoint, data: Data) async throws -> Data
}

// WebSocketManager.swift
protocol WebSocketManagerProtocol {
    func connect() async throws
    func disconnect()
    func send<T: Encodable>(_ message: T) async throws
    func subscribe<T: Decodable>(to eventType: String) -> AsyncStream<T>
}
```

### 2. Endpoint Definition Pattern

```swift
enum ConsciousnessEndpoint {
    case status
    case emotions(timeRange: String, includeHistory: Bool)
    case query(request: ConsciousnessQuery)
}

extension ConsciousnessEndpoint: Endpoint {
    var path: String {
        switch self {
        case .status: return "/consciousness/status"
        case .emotions: return "/consciousness/emotions"
        case .query: return "/consciousness/query"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .status, .emotions: return .get
        case .query: return .post
        }
    }
}
```

### 3. Service Layer Pattern

```swift
protocol ConsciousnessServiceProtocol {
    func getStatus() async throws -> ConsciousnessStatus
    func getEmotions(timeRange: String, includeHistory: Bool) async throws -> EmotionalState
    func query(_ request: ConsciousnessQuery) async throws -> ConsciousnessResponse
}

class ConsciousnessService: ConsciousnessServiceProtocol {
    private let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }
}
```

## Authentication and Security Approach

### 1. JWT Token Management

```swift
protocol TokenManagerProtocol {
    func saveToken(_ token: String) async throws
    func getToken() async -> String?
    func refreshToken() async throws -> String
    func clearToken() async
}

@propertyWrapper
struct SecurelyStored<T> {
    private let key: String
    private let keychain = KeychainManager.shared
    
    var wrappedValue: T? {
        get { keychain.get(key, type: T.self) }
        set { 
            if let value = newValue {
                keychain.set(value, for: key)
            } else {
                keychain.delete(key)
            }
        }
    }
}
```

### 2. Authentication Flow

```swift
protocol AuthenticationServiceProtocol {
    var isAuthenticated: Bool { get }
    func login(username: String, password: String) async throws -> AuthToken
    func logout() async
    func refreshTokenIfNeeded() async throws
}

// Automatic token refresh interceptor
class AuthenticationInterceptor: NetworkInterceptor {
    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let token = await tokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    func recover(from error: NetworkError) async throws -> RecoveryAction {
        if case .unauthorized = error {
            try await authService.refreshTokenIfNeeded()
            return .retry
        }
        return .propagate
    }
}
```

### 3. Security Measures
- Store sensitive data in iOS Keychain
- Certificate pinning for production environments
- Biometric authentication for app access
- Encrypted local storage for cached data
- App Transport Security (ATS) compliance

## Request/Response Models

### 1. Base Response Structure

```swift
struct APIResponse<T: Decodable>: Decodable {
    let data: T?
    let error: APIError?
    let timestamp: Date
    let requestId: String?
}

struct APIError: Decodable, LocalizedError {
    let code: String
    let message: String
    let details: [String: Any]?
    
    var errorDescription: String? {
        return message
    }
}
```

### 2. Core Data Transfer Objects (DTOs)

```swift
// Consciousness DTOs
struct ConsciousnessQuery: Encodable {
    let query: String
    let context: [String: Any]?
    let includeDevices: Bool
}

struct ConsciousnessStatus: Decodable {
    let status: String
    let awarenessLevel: Double
    let emotionalState: EmotionalState
    let activeDevices: Int
    let saflaLoops: Int
    let lastUpdate: Date
}

// Device DTOs
struct DeviceControl: Encodable {
    let action: String
    let value: Any?
    let transitionTime: Int?
}

struct Device: Decodable, Identifiable {
    let id: String
    let userName: String
    let userDescription: String?
    let location: String?
    let deviceClass: String
    let status: DeviceStatus
    let currentState: [String: Any]
    let supportedFeatures: [String]
}
```

## Error Handling and Retry Strategies

### 1. Error Types

```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case noConnection
    case timeout
    case unauthorized
    case serverError(code: Int, message: String)
    case decodingError(Error)
    case apiError(APIError)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .unauthorized:
            return "Authentication required"
        case .serverError(_, let message):
            return message
        case .apiError(let error):
            return error.message
        default:
            return "An unexpected error occurred"
        }
    }
}
```

### 2. Retry Policy

```swift
struct RetryPolicy {
    let maxAttempts: Int
    let backoffMultiplier: Double
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    
    static let `default` = RetryPolicy(
        maxAttempts: 3,
        backoffMultiplier: 2.0,
        initialDelay: 1.0,
        maxDelay: 30.0
    )
    
    static let aggressive = RetryPolicy(
        maxAttempts: 5,
        backoffMultiplier: 1.5,
        initialDelay: 0.5,
        maxDelay: 10.0
    )
}

extension NetworkManager {
    func requestWithRetry<T: Decodable>(
        _ endpoint: Endpoint,
        policy: RetryPolicy = .default
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<policy.maxAttempts {
            do {
                return try await request(endpoint)
            } catch {
                lastError = error
                
                if !isRetriableError(error) || attempt == policy.maxAttempts - 1 {
                    throw error
                }
                
                let delay = min(
                    policy.initialDelay * pow(policy.backoffMultiplier, Double(attempt)),
                    policy.maxDelay
                )
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? NetworkError.unknown
    }
}
```

### 3. Circuit Breaker Pattern

```swift
actor CircuitBreaker {
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let threshold: Int
    private let timeout: TimeInterval
    
    enum State {
        case closed
        case open
        case halfOpen
    }
    
    private var state: State = .closed
    
    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        switch state {
        case .open:
            if shouldAttemptReset() {
                state = .halfOpen
            } else {
                throw NetworkError.circuitBreakerOpen
            }
        case .halfOpen, .closed:
            break
        }
        
        do {
            let result = try await operation()
            recordSuccess()
            return result
        } catch {
            recordFailure()
            throw error
        }
    }
}
```

## Network Monitoring and Analytics

```swift
protocol NetworkMonitorProtocol {
    var isConnected: Bool { get }
    var connectionType: ConnectionType { get }
    func startMonitoring()
    func stopMonitoring()
}

struct NetworkMetrics {
    let endpoint: String
    let method: String
    let statusCode: Int
    let duration: TimeInterval
    let requestSize: Int
    let responseSize: Int
    let error: Error?
}

protocol NetworkAnalyticsProtocol {
    func track(_ metrics: NetworkMetrics)
    func trackError(_ error: NetworkError, endpoint: String)
}
```

## Testing Strategy

### 1. Mock Network Layer

```swift
class MockNetworkManager: NetworkManagerProtocol {
    var responses: [String: Result<Data, Error>] = [:]
    var requestsReceived: [(endpoint: Endpoint, date: Date)] = []
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        requestsReceived.append((endpoint, Date()))
        
        guard let result = responses[endpoint.path] else {
            throw NetworkError.notFound
        }
        
        switch result {
        case .success(let data):
            return try JSONDecoder().decode(T.self, from: data)
        case .failure(let error):
            throw error
        }
    }
}
```

### 2. API Response Fixtures

```swift
enum APIFixture {
    static let consciousnessStatus = """
    {
        "status": "active",
        "awarenessLevel": 0.85,
        "emotionalState": {
            "primary_emotion": "content",
            "arousal": 0.3,
            "valence": 0.7
        },
        "activeDevices": 12,
        "saflaLoops": 3,
        "lastUpdate": "2025-06-27T10:00:00Z"
    }
    """.data(using: .utf8)!
}
```

### 3. Integration Test Scenarios

```swift
class ConsciousnessAPIIntegrationTests: XCTestCase {
    func testAuthenticationFlow() async throws {
        // Test login
        let token = try await authService.login(username: "test", password: "test")
        XCTAssertNotNil(token)
        
        // Test authenticated request
        let status = try await consciousnessService.getStatus()
        XCTAssertEqual(status.status, "active")
        
        // Test token refresh
        try await authService.refreshTokenIfNeeded()
    }
    
    func testNetworkErrorHandling() async throws {
        // Test retry on timeout
        networkManager.simulateTimeout()
        
        do {
            _ = try await consciousnessService.getStatus()
            XCTFail("Expected timeout error")
        } catch NetworkError.timeout {
            // Expected
        }
    }
}
```

## Performance Considerations

1. **Request Deduplication**: Prevent duplicate requests for the same resource
2. **Response Caching**: Cache responses with appropriate TTL
3. **Batch Operations**: Group multiple device controls into single request
4. **Connection Pooling**: Reuse HTTP connections
5. **Background Session**: Support background uploads/downloads
6. **Progressive Loading**: Implement pagination for large datasets

## Migration Path

1. **Phase 1**: Implement core networking layer with mock data
2. **Phase 2**: Add authentication and security features
3. **Phase 3**: Integrate WebSocket for real-time updates
4. **Phase 4**: Add offline support and synchronization
5. **Phase 5**: Performance optimization and monitoring

## Success Metrics

- API response time < 500ms for 95th percentile
- Token refresh success rate > 99.9%
- Network error recovery rate > 95%
- Zero security vulnerabilities in network layer
- 100% test coverage for critical paths