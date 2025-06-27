# Data Models Plan for c11s-house-ios

## Executive Summary
This document defines the core data models, persistence strategy, and synchronization approach for the iOS house consciousness app. The architecture follows MVVM pattern with Core Data for local storage and Combine for reactive data flow.

## Core Data Entities

### 1. Consciousness Entities

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
        // Calculate arousal from emotion vector
        (excitement + worry) / 2.0
    }
    
    var valence: Double {
        // Calculate valence (positive/negative)
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

### 2. Device Entities

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

### 3. House Structure Entities

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

#### Person
```swift
@Model
class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    var role: PersonRole
    
    // Preferences
    var preferences: PersonPreferences
    var schedule: Schedule?
    
    // Presence
    var isPresent: Bool
    var lastSeen: Date?
    var currentLocation: Room?
    
    // Relationships
    var house: House
    var favoriteScenes: [Scene]
}

enum PersonRole: String, Codable, CaseIterable {
    case owner
    case resident
    case guest
    case child
    case pet
}

struct PersonPreferences: Codable {
    var wakeUpTime: Date?
    var bedTime: Date?
    var preferredTemperature: Double
    var lightSensitivity: LightSensitivity
    var notificationPreferences: NotificationPreferences
}
```

### 4. Activity and Event Entities

#### Activity
```swift
@Model
class Activity {
    @Attribute(.unique) var id: UUID
    var type: ActivityType
    var name: String
    var description: String?
    
    // Timing
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval?
    
    // Context
    var participants: [Person]
    var devicesInvolved: [Device]
    var location: Room?
    
    // Data
    var activityData: [String: Any]
    var outcomes: [String: Any]
}

enum ActivityType: String, Codable, CaseIterable {
    case sleep
    case work
    case entertainment
    case cooking
    case cleaning
    case exercise
    case social
    case other
}
```

#### Event
```swift
@Model
class Event {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    
    // Classification
    var eventType: EventType
    var category: String
    var severity: EventSeverity
    
    // Details
    var title: String
    var description: String
    var source: String
    
    // Data
    var eventData: [String: Any]
    var context: [String: Any]
    
    // Processing
    var isProcessed: Bool
    var processedAt: Date?
    
    // Relationships
    var triggeringDevice: Device?
    var resultingActions: [ControlAction]
}

enum EventType: String, Codable, CaseIterable {
    case sensor
    case control
    case system
    case user
    case automation
    case error
}

enum EventSeverity: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case critical
}
```

### 5. Control and Automation Entities

#### ControlAction
```swift
@Model
class ControlAction {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    
    // Action details
    var actionType: String
    var command: String
    var parameters: [String: Any]
    
    // Execution
    var status: ActionStatus
    var executedAt: Date?
    var completedAt: Date?
    
    // Results
    var result: [String: Any]?
    var errorMessage: String?
    
    // Relationships
    var device: Device
    var triggeringEvent: Event?
    var scene: Scene?
}

enum ActionStatus: String, Codable, CaseIterable {
    case pending
    case executing
    case completed
    case failed
    case cancelled
}
```

#### Scene
```swift
@Model
class Scene {
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var icon: String?
    
    // Configuration
    var actions: [SceneAction]
    var triggers: [SceneTrigger]
    var conditions: [SceneCondition]
    
    // Metadata
    var isEnabled: Bool
    var lastExecuted: Date?
    var executionCount: Int
    
    // Relationships
    var creator: Person?
    var room: Room?
}

struct SceneAction: Codable {
    var deviceId: UUID
    var action: String
    var parameters: [String: Any]
    var delay: TimeInterval?
}

struct SceneTrigger: Codable {
    var type: TriggerType
    var parameters: [String: Any]
}

enum TriggerType: String, Codable {
    case time
    case sunset
    case sunrise
    case deviceState
    case presence
    case manual
}
```

## API Request/Response DTOs

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

## Local Storage Strategy

### 1. Core Data Stack Configuration

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

### 2. Data Migration Strategy

```swift
class DataMigrationManager {
    func performMigrationIfNeeded() {
        let currentVersion = UserDefaults.standard.integer(forKey: "DataModelVersion")
        let targetVersion = 3  // Current model version
        
        if currentVersion < targetVersion {
            migrate(from: currentVersion, to: targetVersion)
        }
    }
    
    private func migrate(from: Int, to: Int) {
        // Perform incremental migrations
        for version in (from + 1)...to {
            switch version {
            case 2:
                migrateToV2()
            case 3:
                migrateToV3()
            default:
                break
            }
        }
        
        UserDefaults.standard.set(to, forKey: "DataModelVersion")
    }
}
```

### 3. Caching Strategy

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

## Data Synchronization Approach

### 1. Sync Engine Architecture

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

### 2. Conflict Resolution

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

### 3. Offline Queue Management

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

## Offline Capabilities

### 1. Offline Mode Detection

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

### 2. Offline Data Access

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

### 3. Smart Sync Strategies

```swift
enum SyncStrategy {
    case immediate      // Sync as soon as online
    case batched       // Batch sync every N minutes
    case lowPriority   // Sync during low usage
    case wifiOnly      // Only sync on WiFi
    
    var priority: OperationQueuePriority {
        switch self {
        case .immediate: return .veryHigh
        case .batched: return .normal
        case .lowPriority: return .low
        case .wifiOnly: return .normal
        }
    }
}

class SmartSyncManager {
    func determineSyncStrategy(for dataType: DataType) -> SyncStrategy {
        switch dataType {
        case .deviceState, .controlAction:
            return .immediate
        case .sensorReading:
            return .batched
        case .memory, .event:
            return .lowPriority
        case .mediaContent:
            return .wifiOnly
        }
    }
}
```

## Performance Optimization

### 1. Lazy Loading

```swift
@propertyWrapper
struct LazyLoaded<T> {
    private var loader: () -> T
    private var value: T?
    
    init(loader: @escaping () -> T) {
        self.loader = loader
    }
    
    var wrappedValue: T {
        mutating get {
            if value == nil {
                value = loader()
            }
            return value!
        }
    }
}
```

### 2. Data Prefetching

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

### 3. Memory Management

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

## Data Security

### 1. Encryption

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

### 2. Access Control

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

## Testing Approach

### 1. Unit Tests for Models

```swift
class DeviceModelTests: XCTestCase {
    func testDeviceStateEncoding() throws {
        let state = DeviceState(
            power: .on,
            brightness: 75,
            color: DeviceState.Color(hue: 180, saturation: 50, temperature: 3000)
        )
        
        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(DeviceState.self, from: encoded)
        
        XCTAssertEqual(decoded.power, .on)
        XCTAssertEqual(decoded.brightness, 75)
        XCTAssertEqual(decoded.color?.hue, 180)
    }
}
```

### 2. Core Data Tests

```swift
class CoreDataTests: XCTestCase {
    var container: NSPersistentContainer!
    
    override func setUp() {
        container = NSPersistentContainer(name: "TestModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
    }
    
    func testDevicePersistence() throws {
        let context = container.viewContext
        let device = Device(context: context)
        device.userName = "Living Room Light"
        device.deviceClass = .light
        
        try context.save()
        
        let request = Device.fetchRequest()
        let devices = try context.fetch(request)
        
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices.first?.userName, "Living Room Light")
    }
}
```

### 3. Sync Tests

```swift
class SyncEngineTests: XCTestCase {
    func testConflictResolution() async throws {
        let conflict = SyncConflict(
            entityType: "Device",
            entityId: "123",
            localVersion: localDevice,
            remoteVersion: remoteDevice,
            localTimestamp: Date(),
            remoteTimestamp: Date().addingTimeInterval(-60)
        )
        
        let resolution = try await conflictResolver.resolveConflict(conflict)
        XCTAssertEqual(resolution, .useLocal)  // Local is newer
    }
}
```

## Migration Roadmap

### Phase 1: Core Models (Week 1-2)
- Implement base entity models
- Set up Core Data stack
- Create DTO mappings

### Phase 2: Persistence Layer (Week 2-3)
- Implement local storage
- Add caching layer
- Create data access layer

### Phase 3: Sync Engine (Week 3-4)
- Build sync infrastructure
- Implement conflict resolution
- Add offline queue

### Phase 4: Security & Optimization (Week 4-5)
- Add encryption
- Implement access control
- Optimize performance

### Phase 5: Testing & Refinement (Week 5-6)
- Complete test coverage
- Performance testing
- Bug fixes and optimization

## Success Metrics

- Core Data operations < 10ms for 95th percentile
- Sync completion < 5 seconds for typical data set
- Offline mode functionality > 90% of features
- Zero data loss during sync conflicts
- Memory usage < 50MB for typical usage