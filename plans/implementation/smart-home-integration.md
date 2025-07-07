# Smart Home Integration: API Integration and Data Models

This document consolidates the API integration strategy and data model design for seamless smart home device control and house consciousness communication.

## Overview

The smart home integration layer provides secure, efficient communication between the iOS app and the house consciousness backend, while managing local data persistence and real-time synchronization across all connected devices.

## API Integration Architecture

### Base Configuration
- **Production Base URL**: `https://api.consciousness.local/v1`
- **Development Base URL**: `http://localhost:8000/api/v1`
- **Demo Endpoints**: `/api/*` (non-authenticated for demo purposes)
- **WebSocket URL**: `/api/v1/realtime` (authenticated) or `/ws` (demo)

### Core API Endpoints

#### Authentication
```
POST /api/v1/auth/login
Request: {username: String, password: String}
Response: {access_token: String, token_type: String, expires_in: Int}
```

#### Consciousness System
```
GET  /api/v1/consciousness/status
GET  /api/v1/consciousness/emotions
POST /api/v1/consciousness/query
```

#### Device Management
```
GET  /api/v1/devices
GET  /api/v1/devices/{device_id}
PUT  /api/v1/devices/{device_id}/control
POST /api/v1/devices/batch-control
```

#### Memory System
```
GET  /api/v1/memory
POST /api/v1/memory
```

#### Interview System
```
POST /api/v1/interview/start
POST /api/v1/interview/{interview_id}/message
GET  /api/v1/interview/{interview_id}/status
```

#### Digital Twin & Predictions
```
GET  /api/v1/twins
POST /api/v1/twins
POST /api/v1/predictions/what-if
```

#### Real-time WebSocket Events
- `consciousness_query`: Query results and responses
- `device_update`: Device state changes
- `batch_device_update`: Multiple device updates
- `interview_update`: Interview progress
- `status_update`: System status updates

## Network Layer Architecture

### Core Networking Components
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

### Endpoint Definition Pattern
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

### Service Layer Pattern
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

## Authentication and Security

### JWT Token Management
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

### Authentication Flow
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

### Security Measures
- Store sensitive data in iOS Keychain
- Certificate pinning for production environments
- Biometric authentication for app access
- Encrypted local storage for cached data
- App Transport Security (ATS) compliance

## Core Data Models

### Consciousness Entities

#### ConsciousnessState
```swift
@Model
class ConsciousnessState {
    @Attribute(.unique) var id: UUID
    var status: ConsciousnessStatus
    var awarenessLevel: Double
    var lastUpdate: Date
    var syncStatus: SyncStatus
    
    // Relationships
    var emotionalState: EmotionalState?
    var activeDevices: [Device]
    var memories: [Memory]
}

enum ConsciousnessStatus: String, Codable, CaseIterable {
    case active
    case inactive
    case processing
    case sleeping
}
```

#### EmotionalState
```swift
@Model
class EmotionalState {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    
    // Core emotions (0.0 - 1.0)
    var happiness: Double
    var worry: Double
    var boredom: Double
    var excitement: Double
    
    // Derived properties
    var primaryEmotion: String
    var intensity: Double
    var confidence: Double
    
    // Metadata
    var triggerEvent: String?
    var context: [String: Any]?
    var reasoning: String?
    
    // Computed properties
    var emotionVector: [Double] {
        [happiness, worry, boredom, excitement]
    }
    
    var arousal: Double {
        (excitement + worry) / 2.0
    }
    
    var valence: Double {
        (happiness - worry + excitement - boredom) / 2.0
    }
}
```

#### Memory
```swift
@Model
class Memory {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var lastAccessed: Date?
    
    // Classification
    var memoryType: MemoryType
    var category: String
    var importance: Double
    
    // Content
    var title: String
    var content: String
    var details: [String: Any]
    
    // Metadata
    var source: MemorySource
    var confidence: Double
    var accessCount: Int
    
    // Associations
    var tags: [String]
    var relatedDevices: [Device]
    var experience: Experience?
}

enum MemoryType: String, Codable, CaseIterable {
    case episodic    // Events and experiences
    case semantic    // Facts and knowledge
    case procedural  // How to do things
}

enum MemorySource: String, Codable, CaseIterable {
    case sensor
    case userInteraction
    case internal
    case learned
}
```

### Device Entities

#### Device
```swift
@Model
class Device {
    @Attribute(.unique) var id: UUID
    var deviceId: String  // Backend ID
    
    // User information
    var userName: String
    var userDescription: String?
    var location: String?
    
    // Device identification
    var detectedBrand: String?
    var detectedModel: String?
    var integrationType: String
    var deviceClass: DeviceClass
    
    // Connection
    var connectionMethod: ConnectionMethod
    var requiresHub: Bool
    var hubId: UUID?
    
    // Capabilities
    var supportedFeatures: [String]
    var capabilities: [String: Any]
    
    // Status
    var status: DeviceStatus
    var currentState: DeviceState
    var lastSeen: Date?
    
    // Discovery
    var discoveryMethod: DiscoveryMethod
    var discoveryConfidence: Double
    
    // Relationships
    var room: Room?
    var entities: [DeviceEntity]
    var sensorReadings: [SensorReading]
    var controlActions: [ControlAction]
}

enum DeviceClass: String, Codable, CaseIterable {
    case light
    case sensor
    case climate
    case security
    case entertainment
    case appliance
    case hub
    case other
}

enum DeviceStatus: String, Codable, CaseIterable {
    case online
    case offline
    case unknown
    case error
}

enum ConnectionMethod: String, Codable, CaseIterable {
    case wifi
    case zigbee
    case zwave
    case bluetooth
    case cloud
    case local
}
```

#### DeviceEntity
```swift
@Model
class DeviceEntity {
    @Attribute(.unique) var id: UUID
    var entityId: String  // e.g., "sensor.living_room_temp"
    var uniqueId: String
    
    // Properties
    var name: String
    var entityType: EntityType
    var deviceClass: String?
    
    // State
    var state: String?
    var attributes: [String: Any]
    var unitOfMeasurement: String?
    
    // Configuration
    var icon: String?
    var isEnabled: Bool
    
    // Relationship
    var device: Device
}

enum EntityType: String, Codable, CaseIterable {
    case sensor
    case binarySensor
    case light
    case switch
    case climate
    case cover
    case fan
    case lock
    case media
}
```

#### DeviceState
```swift
struct DeviceState: Codable {
    var power: PowerState?
    var brightness: Int?  // 0-100
    var color: Color?
    var temperature: Temperature?
    var humidity: Double?
    var motion: Bool?
    var openClosed: OpenClosedState?
    var locked: Bool?
    var customAttributes: [String: Any]
    
    struct Color: Codable {
        var hue: Double      // 0-360
        var saturation: Double  // 0-100
        var temperature: Int?   // Kelvin
    }
    
    struct Temperature: Codable {
        var current: Double
        var target: Double?
        var unit: TemperatureUnit
    }
}

enum PowerState: String, Codable {
    case on
    case off
    case standby
}

enum TemperatureUnit: String, Codable {
    case celsius
    case fahrenheit
}
```

### House Structure Entities

#### House
```swift
@Model
class House {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String?
    
    // Physical properties
    var squareFootage: Double?
    var numberOfRooms: Int
    var numberOfFloors: Int
    
    // Configuration
    var timezone: TimeZone
    var preferences: HousePreferences
    var capabilities: [String]
    
    // Relationships
    var rooms: [Room]
    var people: [Person]
    var devices: [Device]
}

struct HousePreferences: Codable {
    var defaultTemperature: Double
    var energySavingMode: Bool
    var securityLevel: SecurityLevel
    var quietHours: DateInterval?
    var vacationMode: Bool
}

enum SecurityLevel: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case maximum
}
```

#### Room
```swift
@Model
class Room {
    @Attribute(.unique) var id: UUID
    var name: String
    var roomType: RoomType
    var floor: Int
    
    // Physical properties
    var squareFootage: Double?
    var ceilingHeight: Double?
    var windowCount: Int
    var doorCount: Int
    
    // Environmental preferences
    var preferredTemperature: Double?
    var preferredHumidity: Double?
    var lightingPreferences: LightingPreferences
    
    // Relationships
    var house: House
    var devices: [Device]
    var activities: [Activity]
}

enum RoomType: String, Codable, CaseIterable {
    case bedroom
    case bathroom
    case kitchen
    case livingRoom
    case diningRoom
    case office
    case garage
    case basement
    case attic
    case hallway
    case other
}

struct LightingPreferences: Codable {
    var defaultBrightness: Int  // 0-100
    var colorTemperature: Int?  // Kelvin
    var automaticControl: Bool
    var motionActivated: Bool
}
```

## Request/Response DTOs

### Request DTOs
```swift
// Authentication
struct LoginRequest: Encodable {
    let username: String
    let password: String
}

// Consciousness
struct ConsciousnessQueryRequest: Encodable {
    let query: String
    let context: [String: Any]?
    let includeDevices: Bool
}

// Device Control
struct DeviceControlRequest: Encodable {
    let action: String
    let value: Any?
    let transitionTime: Int?
}

struct BatchDeviceControlRequest: Encodable {
    let devices: [DeviceControlCommand]
}

struct DeviceControlCommand: Encodable {
    let deviceId: String
    let action: String
    let value: Any?
}

// Memory
struct MemoryEntryRequest: Encodable {
    let type: String
    let content: String
    let context: [String: Any]?
}

// Interview
struct InterviewStartRequest: Encodable {
    let houseId: String
}

struct InterviewMessageRequest: Encodable {
    let message: String
}
```

### Response DTOs
```swift
// Authentication
struct AuthTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
}

// Consciousness
struct ConsciousnessStatusResponse: Decodable {
    let status: String
    let awarenessLevel: Double
    let emotionalState: EmotionalStateDTO
    let activeDevices: Int
    let saflaLoops: Int
    let lastUpdate: Date
}

struct ConsciousnessQueryResponse: Decodable {
    let response: String
    let confidence: Double
    let context: [String: Any]?
    let suggestedActions: [SuggestedAction]?
}

// Devices
struct DeviceListResponse: Decodable {
    let devices: [DeviceDTO]
    let total: Int
    let filtersApplied: [String: Any]?
}

struct DeviceDTO: Decodable {
    let id: String
    let userName: String
    let userDescription: String?
    let location: String?
    let deviceClass: String
    let status: String
    let currentState: [String: Any]
    let supportedFeatures: [String]
    let capabilities: [String: Any]
}

// Real-time Events
struct WebSocketEvent: Decodable {
    let type: String
    let data: [String: Any]
    let timestamp: Date
}
```

## Error Handling and Retry Strategies

### Error Types
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

### Retry Policy
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

### Circuit Breaker Pattern
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

## Data Synchronization and Persistence

### Local Storage Strategy

#### Core Data Stack Configuration
```swift
class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ConsciousnessModel")
        
        // Enable automatic migration
        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, 
                                forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, 
                                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}
```

#### Caching Strategy
```swift
protocol CachePolicy {
    var ttl: TimeInterval { get }
    var maxSize: Int { get }
    var priority: CachePriority { get }
}

enum CachePriority: Int {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
}

class CacheManager {
    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let diskCache: DiskCache
    
    func cache<T: Codable>(_ object: T, for key: String, policy: CachePolicy) {
        let entry = CacheEntry(
            data: object,
            expiresAt: Date().addingTimeInterval(policy.ttl),
            priority: policy.priority
        )
        
        // Memory cache
        memoryCache.setObject(entry, forKey: key as NSString)
        
        // Disk cache for high priority items
        if policy.priority >= .high {
            diskCache.store(entry, for: key)
        }
    }
    
    func retrieve<T: Codable>(_ type: T.Type, for key: String) -> T? {
        // Check memory cache first
        if let entry = memoryCache.object(forKey: key as NSString),
           entry.isValid {
            return entry.data as? T
        }
        
        // Check disk cache
        if let entry = diskCache.retrieve(for: key),
           entry.isValid {
            memoryCache.setObject(entry, forKey: key as NSString)
            return entry.data as? T
        }
        
        return nil
    }
}
```

### Sync Engine Architecture
```swift
protocol SyncEngineProtocol {
    func startSync()
    func stopSync()
    func syncNow() async throws
    func resolveConflict(_ conflict: SyncConflict) async throws -> Resolution
}

class SyncEngine: SyncEngineProtocol {
    private let localStore: PersistenceController
    private let remoteAPI: APIClientProtocol
    private let conflictResolver: ConflictResolverProtocol
    
    private var syncTimer: Timer?
    private let syncQueue = DispatchQueue(label: "com.c11s.sync", qos: .background)
    
    func startSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                try? await self.syncNow()
            }
        }
        
        // Listen for remote changes via WebSocket
        subscribeToRemoteChanges()
    }
    
    func syncNow() async throws {
        // 1. Fetch local changes
        let localChanges = try await fetchLocalChanges()
        
        // 2. Push local changes
        try await pushChanges(localChanges)
        
        // 3. Fetch remote changes
        let remoteChanges = try await fetchRemoteChanges()
        
        // 4. Merge remote changes
        try await mergeChanges(remoteChanges)
        
        // 5. Update sync status
        updateSyncStatus()
    }
}
```

### Conflict Resolution
```swift
enum ConflictResolution {
    case useLocal
    case useRemote
    case merge(resolved: Any)
    case askUser
}

struct SyncConflict {
    let entityType: String
    let entityId: String
    let localVersion: Any
    let remoteVersion: Any
    let localTimestamp: Date
    let remoteTimestamp: Date
}

class ConflictResolver: ConflictResolverProtocol {
    func resolveConflict(_ conflict: SyncConflict) async throws -> ConflictResolution {
        // Check if auto-resolution is possible
        if canAutoResolve(conflict) {
            return autoResolve(conflict)
        }
        
        // Otherwise, queue for user resolution
        return .askUser
    }
    
    private func canAutoResolve(_ conflict: SyncConflict) -> Bool {
        // Simple timestamp-based resolution for non-critical data
        switch conflict.entityType {
        case "DeviceState", "SensorReading":
            return true  // Always use most recent
        case "Scene", "Memory":
            return false  // Require user input
        default:
            return false
        }
    }
}
```

## Offline Capabilities

### Offline Mode Detection
```swift
class NetworkReachability: ObservableObject {
    @Published var isOnline = true
    @Published var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(from: path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }
}
```

### Offline Queue Management
```swift
class OfflineQueueManager {
    private var pendingOperations: [OfflineOperation] = []
    
    func enqueue(_ operation: OfflineOperation) {
        pendingOperations.append(operation)
        persistQueue()
    }
    
    func processPendingOperations() async {
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        for operation in operations {
            do {
                try await executeOperation(operation)
            } catch {
                // Re-queue failed operations
                if operation.retryCount < 3 {
                    var retriedOperation = operation
                    retriedOperation.retryCount += 1
                    enqueue(retriedOperation)
                }
            }
        }
    }
}

struct OfflineOperation: Codable {
    let id: UUID
    let type: OperationType
    let timestamp: Date
    let data: Data
    var retryCount: Int = 0
}

enum OperationType: String, Codable {
    case deviceControl
    case sceneExecution
    case memoryCreation
    case queryLogging
}
```

### Offline Data Access
```swift
protocol OfflineDataProviderProtocol {
    func getDevices() -> [Device]
    func getScenes() -> [Scene]
    func getRecentMemories(limit: Int) -> [Memory]
    func canExecuteOffline(_ action: ControlAction) -> Bool
}

class OfflineDataProvider: OfflineDataProviderProtocol {
    private let persistenceController: PersistenceController
    
    func canExecuteOffline(_ action: ControlAction) -> Bool {
        // Check if action can be executed locally
        switch action.actionType {
        case "toggle", "setBrightness", "setColor":
            // Can queue for later execution
            return true
        case "query", "analyze":
            // Requires online connection
            return false
        default:
            return false
        }
    }
}
```

## Performance Optimization

### Data Prefetching
```swift
class DataPrefetchManager {
    func prefetchData(for context: ViewContext) {
        switch context {
        case .deviceList:
            prefetchDevices()
            prefetchRecentEvents()
        case .consciousness:
            prefetchEmotionalHistory()
            prefetchMemories()
        case .automation:
            prefetchScenes()
            prefetchSchedules()
        }
    }
}
```

### Memory Management
```swift
class MemoryPressureHandler {
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        // Clear caches
        CacheManager.shared.clearMemoryCache()
        
        // Release non-essential data
        DataStore.shared.releaseNonEssentialData()
        
        // Reduce image quality
        ImageCache.shared.reduceCacheQuality()
    }
}
```

## Security and Encryption

### Data Encryption
```swift
class DataEncryption {
    private let key = SymmetricKey(size: .bits256)
    
    func encrypt<T: Codable>(_ object: T) throws -> Data {
        let data = try JSONEncoder().encode(object)
        let sealed = try AES.GCM.seal(data, using: key)
        return sealed.combined ?? Data()
    }
    
    func decrypt<T: Codable>(_ data: Data, to type: T.Type) throws -> T {
        let sealed = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealed, using: key)
        return try JSONDecoder().decode(type, from: decrypted)
    }
}
```

### Access Control
```swift
class DataAccessControl {
    func canAccess(_ entity: Any, user: Person) -> Bool {
        switch entity {
        case let device as Device:
            return canAccessDevice(device, user: user)
        case let memory as Memory:
            return canAccessMemory(memory, user: user)
        default:
            return false
        }
    }
    
    private func canAccessDevice(_ device: Device, user: Person) -> Bool {
        // Check user role and device permissions
        switch user.role {
        case .owner:
            return true
        case .resident:
            return !device.isSecurityDevice
        case .guest:
            return device.isGuestAccessible
        default:
            return false
        }
    }
}
```

## Testing Strategy

### Mock Network Layer
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

### API Response Fixtures
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

### Integration Test Scenarios
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

## Performance Considerations

1. **Request Deduplication**: Prevent duplicate requests for the same resource
2. **Response Caching**: Cache responses with appropriate TTL
3. **Batch Operations**: Group multiple device controls into single request
4. **Connection Pooling**: Reuse HTTP connections
5. **Background Session**: Support background uploads/downloads
6. **Progressive Loading**: Implement pagination for large datasets

## Implementation Timeline

### Phase 1: Network Foundation (Weeks 1-2)
- Core networking layer implementation
- Authentication system setup
- Basic error handling

### Phase 2: Data Models (Weeks 2-3)
- Core Data stack implementation
- Entity model definitions
- Basic CRUD operations

### Phase 3: API Integration (Weeks 3-4)
- REST API client completion
- WebSocket integration
- Real-time synchronization

### Phase 4: Sync Engine (Weeks 4-5)
- Data synchronization implementation
- Conflict resolution system
- Offline queue management

### Phase 5: Security & Performance (Weeks 5-6)
- Security measures implementation
- Performance optimization
- Comprehensive testing

## Success Metrics

- API response time < 500ms for 95th percentile
- Token refresh success rate > 99.9%
- Network error recovery rate > 95%
- Zero security vulnerabilities in network layer
- 100% test coverage for critical paths
- Core Data operations < 10ms for 95th percentile
- Sync completion < 5 seconds for typical data set
- Offline mode functionality > 90% of features
- Zero data loss during sync conflicts
- Memory usage < 50MB for typical usage

---

*This document consolidates API integration and data model strategies. It will be updated as implementation progresses and requirements evolve.*