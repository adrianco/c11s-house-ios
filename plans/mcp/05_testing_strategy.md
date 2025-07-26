# HomeGraph MCP Testing Strategy

## Overview

This document outlines the comprehensive testing strategy for the HomeGraph MCP implementation, ensuring quality, reliability, and safe incremental deployment.

## Testing Philosophy

### Core Principles
1. **Test in Isolation**: Each component tested independently
2. **Mock External Dependencies**: Use mocks for HomeKit, CoreML
3. **Incremental Validation**: Test each phase before proceeding
4. **Performance First**: Benchmark from the start
5. **User Safety**: No production impact during testing

## Test Categories

### 1. Unit Tests

#### Storage Layer Tests
```swift
// HomeGraphStorageTests.swift
class HomeGraphStorageTests: XCTestCase {
    var storage: HomeGraphStorage!
    
    override func setUp() {
        // Use in-memory database for tests
        storage = HomeGraphStorage(inMemory: true)
    }
    
    func testEntityCRUD() async throws {
        // Test Create
        let entity = HomeEntity(/* ... */)
        try await storage.store(entity: entity)
        
        // Test Read
        let retrieved = try await storage.fetchEntity(id: entity.id)
        XCTAssertEqual(retrieved?.id, entity.id)
        
        // Test Update (new version)
        let updated = entity.withNewVersion()
        try await storage.store(entity: updated)
        
        // Test Delete (soft delete via versioning)
        let versions = try await storage.fetchVersions(for: entity.id)
        XCTAssertEqual(versions.count, 2)
    }
    
    func testConcurrentAccess() async throws {
        // Test concurrent writes don't corrupt
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let entity = HomeEntity(id: "concurrent-\(i)")
                    try? await self.storage.store(entity: entity)
                }
            }
        }
        
        let count = try await storage.countEntities()
        XCTAssertEqual(count, 100)
    }
}
```

#### Graph Layer Tests
```swift
// HomeGraphTests.swift
class HomeGraphTests: XCTestCase {
    func testGraphQueries() async throws {
        let graph = HomeGraph()
        
        // Setup test data
        await graph.addTestData()
        
        // Test room queries
        let devices = await graph.entitiesInRoom("kitchen")
        XCTAssertEqual(devices.count, 5)
        
        // Test relationship traversal
        let controllers = await graph.devicesControlling("kitchen_lights")
        XCTAssertTrue(controllers.contains { $0.name == "Kitchen Switch" })
    }
    
    func testGraphPerformance() async throws {
        let graph = HomeGraph()
        await graph.addLargeTestDataset() // 1000+ entities
        
        measure {
            let devices = await graph.entitiesInRoom("master_bedroom")
            XCTAssertNotNil(devices)
        }
    }
}
```

### 2. Integration Tests

#### HomeKit Bridge Tests
```swift
// HomeKitBridgeTests.swift
class HomeKitBridgeTests: XCTestCase {
    var mockHomeManager: MockHMHomeManager!
    var bridge: HomeKitGraphBridge!
    
    func testHomeKitExtraction() async throws {
        // Setup mock HomeKit data
        mockHomeManager.addMockHome(
            name: "Test Home",
            rooms: ["Kitchen", "Bedroom"],
            accessories: createMockAccessories()
        )
        
        // Extract data
        let entities = try await bridge.extractHomeKitData()
        
        // Verify extraction
        XCTAssertEqual(entities.filter { $0.entityType == .room }.count, 2)
        XCTAssertTrue(entities.contains { $0.content["name"] as? String == "Kitchen" })
    }
}
```

#### MCP Protocol Tests
```swift
// MCPProtocolTests.swift
class MCPProtocolTests: XCTestCase {
    var mcpServer: HomeGraphMCPService!
    
    func testResourceRequests() async throws {
        // Test valid resource
        let request = MCPResourceRequest(uri: "homegraph://room/kitchen")
        let response = try await mcpServer.handleResourceRequest(request)
        XCTAssertFalse(response.contents.isEmpty)
        
        // Test invalid resource
        let invalidRequest = MCPResourceRequest(uri: "homegraph://invalid/path")
        do {
            _ = try await mcpServer.handleResourceRequest(invalidRequest)
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(error is MCPError)
        }
    }
    
    func testToolExecution() async throws {
        // Test get_devices_in_room
        let request = MCPToolRequest(
            method: "get_devices_in_room",
            params: ["room_name": "Kitchen"]
        )
        let response = try await mcpServer.handleToolCall(request)
        XCTAssertTrue(response.content.first?.text?.contains("Kitchen") ?? false)
    }
}
```

### 3. End-to-End Tests

#### Conversation Flow Tests
```swift
// ConversationE2ETests.swift
class ConversationE2ETests: XCTestCase {
    func testNaturalConversation() async throws {
        let system = TestSystem()
        await system.setupCompleteEnvironment()
        
        // Test conversation flow
        let response1 = await system.processUtterance("What lights are on?")
        XCTAssertTrue(response1.contains("lights"))
        
        let response2 = await system.processUtterance("Turn off the kitchen ones")
        XCTAssertTrue(response2.contains("kitchen"))
        XCTAssertTrue(response2.contains("off"))
        
        // Verify state change
        let kitchenLights = await system.getDeviceState("kitchen_lights")
        XCTAssertFalse(kitchenLights.isOn)
    }
}
```

### 4. Performance Tests

#### Benchmark Suite
```swift
// PerformanceBenchmarks.swift
class PerformanceBenchmarks: XCTestCase {
    func testStoragePerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            // Storage operations
        }
    }
    
    func testGraphQueryPerformance() {
        let options = XCTMeasureOptions()
        options.iterationCount = 100
        
        measure(options: options) {
            // Graph queries
        }
    }
    
    func testMCPResponseTime() {
        measure {
            // MCP request/response cycle
        }
    }
}
```

## Testing Phases

### Phase 1: Foundation Testing
**Week 1-2 Focus**

Checklist:
- [ ] SQLite schema creation
- [ ] Entity CRUD operations  
- [ ] Concurrent access handling
- [ ] Memory usage under 10MB
- [ ] Query performance <5ms

Test Data:
```swift
struct TestDataGenerator {
    static func minimalHome() -> [HomeEntity] {
        // 1 home, 5 rooms, 20 devices
    }
    
    static func typicalHome() -> [HomeEntity] {
        // 1 home, 12 rooms, 50 devices, 100 notes
    }
    
    static func complexHome() -> [HomeEntity] {
        // 2 homes, 25 rooms, 150 devices, 500 notes
    }
}
```

### Phase 2: HomeKit Integration Testing
**Week 2-3 Focus**

Mock Strategy:
```swift
class MockHMHomeManager: HMHomeManager {
    var mockHomes: [MockHMHome] = []
    
    override var homes: [HMHome] {
        return mockHomes
    }
}

class MockHMHome: HMHome {
    var mockRooms: [MockHMRoom] = []
    var mockName: String
    
    override var rooms: [HMRoom] {
        return mockRooms
    }
}
```

### Phase 3: Graph Performance Testing
**Week 3-4 Focus**

Performance Targets:
- Simple queries: <10ms
- Complex traversals: <50ms  
- Memory usage: <50MB for typical home
- Cache hit rate: >90%

### Phase 4: MCP Protocol Testing
**Week 4-5 Focus**

Protocol Compliance:
- [ ] All resource URIs resolve
- [ ] Tool parameter validation
- [ ] Error responses correct format
- [ ] Async operations handled
- [ ] Thread safety verified

### Phase 5: Migration Testing
**Week 5-6 Focus**

Migration Scenarios:
1. **Empty State**: Fresh install
2. **Minimal Data**: Few notes
3. **Typical Usage**: ~100 notes
4. **Heavy Usage**: 1000+ notes
5. **Corrupted Data**: Handle gracefully

Validation:
```swift
class MigrationValidator {
    func validateMigration(
        original: NotesStoreData,
        migrated: [HomeEntity]
    ) -> MigrationReport {
        // Compare counts
        // Verify content
        // Check metadata
        // Validate relationships
    }
}
```

### Phase 6: CoreML Testing
**Week 6-7 Focus**

ML Model Testing:
- [ ] Model loads correctly
- [ ] Inference time <100ms
- [ ] Memory usage acceptable
- [ ] Accuracy >90%
- [ ] Fallback works

Test Cases:
```swift
struct MLTestCases {
    static let intents = [
        ("Turn on the lights", .controlDevice, ["lights"]),
        ("What's the temperature?", .queryDevice, ["temperature"]),
        ("Is the door locked?", .queryDevice, ["door", "locked"]),
        // ... 100+ test cases
    ]
}
```

### Phase 7: UI Testing
**Week 7-8 Focus**

UI Test Suite:
```swift
class HomeGraphUITests: XCTestCase {
    func testNotesViewTransition() {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to notes
        app.tabBars.buttons["Notes"].tap()
        
        // Verify data loads
        XCTAssertTrue(app.tables.cells.count > 0)
        
        // Test interaction
        app.tables.cells.firstMatch.tap()
        XCTAssertTrue(app.textViews.firstMatch.exists)
    }
}
```

## Test Environment Setup

### CI/CD Pipeline
```yaml
# .github/workflows/test.yml
name: HomeGraph Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Unit Tests
        run: |
          xcodebuild test -scheme HomeGraph-Unit
      - name: Run Integration Tests
        run: |
          xcodebuild test -scheme HomeGraph-Integration
      - name: Run Performance Tests
        run: |
          xcodebuild test -scheme HomeGraph-Performance
      - name: Generate Coverage Report
        run: |
          xcrun llvm-cov report
```

### Test Data Management
```swift
protocol TestDataProvider {
    func provideTestHome() -> MockHMHome
    func provideTestNotes() -> [Note]
    func provideTestGraph() -> HomeGraph
}

class TestDataManager: TestDataProvider {
    static let shared = TestDataManager()
    
    private let testDataURL = Bundle.test.url(
        forResource: "TestData",
        withExtension: "json"
    )!
}
```

## Rollback Testing

### Rollback Scenarios
1. **Feature Flag Disable**: Instant rollback
2. **Data Corruption**: Restore from backup
3. **Performance Degradation**: Revert deployment
4. **Critical Bug**: Emergency hotfix

### Rollback Validation
```swift
class RollbackTests: XCTestCase {
    func testFeatureFlagRollback() async {
        // Enable new system
        FeatureFlags.shared.set(.useHomeGraphMCP, true)
        
        // Simulate issue
        // Disable flag
        FeatureFlags.shared.set(.useHomeGraphMCP, false)
        
        // Verify old system works
        let notes = try await NotesService.shared.getAllNotes()
        XCTAssertFalse(notes.isEmpty)
    }
}
```

## Monitoring & Observability

### Test Metrics
```swift
struct TestMetrics {
    let testName: String
    let duration: TimeInterval
    let memoryUsage: Int
    let assertions: Int
    let coverage: Double
}

class TestReporter {
    func generateReport(metrics: [TestMetrics]) -> TestReport {
        // Aggregate metrics
        // Identify trends
        // Flag regressions
    }
}
```

### Production Monitoring
- Error rates by component
- Performance metrics (p50, p90, p99)
- Memory usage trends
- User engagement metrics
- Crash reports

## Success Criteria

### Per-Phase Gates
Each phase must meet criteria before proceeding:

1. **Unit Tests**: 100% pass, >90% coverage
2. **Integration Tests**: 100% pass
3. **Performance Tests**: Meet all targets
4. **E2E Tests**: All scenarios pass
5. **Migration Tests**: Zero data loss
6. **UI Tests**: No regressions

### Overall Success Metrics
- Total test coverage: >90%
- Performance improvement: >20%
- Zero critical bugs
- Smooth user transition
- Positive user feedback

## Continuous Improvement

### Test Maintenance
- Weekly test review
- Monthly performance baseline update
- Quarterly test refactoring
- Annual test strategy review

### Feedback Loop
```swift
class TestFeedbackCollector {
    func collectFeedback(
        from source: FeedbackSource,
        about component: Component
    ) -> Feedback {
        // Collect from:
        // - Automated tests
        // - Manual QA
        // - User reports
        // - Crash analytics
    }
}
```

This comprehensive testing strategy ensures the HomeGraph MCP implementation is robust, performant, and user-safe throughout the migration process.