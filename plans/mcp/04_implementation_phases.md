# HomeGraph MCP Implementation Phases

## Overview

This document provides a detailed, incremental implementation plan for replacing NotesService with the HomeGraph MCP server. Each phase is designed to be independently testable with clear success criteria.

## Phase 1: Foundation (Week 1-2)

### Goals
- Establish core storage infrastructure
- Create basic data models
- Ensure database reliability

### Implementation Steps

#### 1.1 Create Storage Layer
```bash
# Files to create:
Services/Storage/HomeGraphStorage.swift
Services/Storage/HomeGraphModels.swift
Services/Storage/HomeGraphSchema.swift
```

#### 1.2 Implement Core Models
```swift
// HomeGraphModels.swift
struct HomeEntity: Codable {
    let id: String
    let version: String
    let entityType: EntityType
    let parentVersions: [String]
    let content: [String: Any]
    let userId: String
    let createdAt: Date
    let sourceType: SourceType
}

struct EntityRelationship: Codable {
    let id: String
    let fromEntityId: String
    let toEntityId: String
    let relationshipType: RelationshipType
    let fromVersion: String
    let toVersion: String
    let properties: [String: Any]?
    let createdAt: Date
}
```

#### 1.3 SQLite Schema Setup
```swift
// HomeGraphSchema.swift
extension HomeGraphStorage {
    func setupDatabase() throws {
        try db.write { db in
            // Create entities table
            try db.create(table: "entities") { t in
                t.column("id", .text).notNull()
                t.column("version", .text).notNull()
                t.column("entity_type", .text).notNull()
                // ... other columns
                t.primaryKey(["id", "version"])
            }
            
            // Create relationships table
            // Create indices
        }
    }
}
```

### Testing Checklist
- [ ] Database creation succeeds
- [ ] Entity CRUD operations work
- [ ] Concurrent access handled properly
- [ ] Version conflicts detected
- [ ] Indices improve query performance

### Success Criteria
- All unit tests pass
- Database operations < 50ms
- No data corruption under load

## Phase 2: HomeKit Bridge (Week 2-3)

### Goals
- Extract HomeKit data safely
- Convert to graph entities
- Build relationship mappings

### Implementation Steps

#### 2.1 Create HomeKit Bridge
```bash
# Files to create:
Services/HomeGraph/HomeKitGraphBridge.swift
Services/HomeGraph/HomeKitEntityMapper.swift
```

#### 2.2 Entity Extraction
```swift
// HomeKitGraphBridge.swift
class HomeKitGraphBridge {
    private let homeManager: HMHomeManager
    private let storage: HomeGraphStorage
    
    func extractAndStoreHomeKitData() async throws {
        // Extract homes, rooms, accessories
        // Convert to entities
        // Store in database
    }
}
```

#### 2.3 Relationship Building
```swift
extension HomeKitGraphBridge {
    func buildRelationships() async throws {
        // Create located_in relationships
        // Create controls relationships
        // Create connects_to relationships
    }
}
```

### Testing Checklist
- [ ] Mock HomeKit data properly
- [ ] All entities extracted correctly
- [ ] Relationships match HomeKit structure
- [ ] No data loss during conversion
- [ ] Handles missing/null values

### Success Criteria
- 100% HomeKit data captured
- Relationships accurately represent structure
- No impact on existing HomeKit functionality

## Phase 3: In-Memory Graph (Week 3-4)

### Goals
- Build efficient graph structure
- Implement fast queries
- Add caching layer

### Implementation Steps

#### 3.1 Create Graph Layer
```bash
# Files to create:
Services/HomeGraph/HomeGraph.swift
Services/HomeGraph/GraphQueryEngine.swift
Services/HomeGraph/GraphCache.swift
```

#### 3.2 Graph Implementation
```swift
// HomeGraph.swift
actor HomeGraph {
    private var entities: [String: HomeEntity] = [:]
    private var relationshipIndex: RelationshipIndex
    private let cache: GraphCache
    
    func loadFromStorage(_ storage: HomeGraphStorage) async throws {
        // Load entities
        // Build indices
        // Warm cache
    }
    
    func query(_ query: GraphQuery) async throws -> [HomeEntity] {
        // Execute graph queries
    }
}
```

### Testing Checklist
- [ ] Graph loads completely from storage
- [ ] Queries return correct results
- [ ] Cache improves performance
- [ ] Memory usage acceptable
- [ ] Thread-safe operations

### Success Criteria
- Query performance < 10ms
- Memory usage < 50MB for typical home
- 100% query accuracy

## Phase 4: MCP Server Core (Week 4-5)

### Goals
- Implement MCP protocol
- Create resource handlers
- Build tool registry

### Implementation Steps

#### 4.1 Create MCP Server
```bash
# Files to create:
Services/MCP/HomeGraphMCPService.swift
Services/MCP/HomeGraphMCPProtocol.swift
Services/MCP/MCPResourceHandlers.swift
Services/MCP/MCPToolHandlers.swift
```

#### 4.2 Protocol Implementation
```swift
// HomeGraphMCPService.swift
class HomeGraphMCPService: HomeGraphMCPServiceProtocol {
    private let graph: HomeGraph
    private let storage: HomeGraphStorage
    
    func handleResourceRequest(_ request: MCPResourceRequest) async throws -> MCPResourceResponse {
        // Parse URI
        // Query graph
        // Format response
    }
    
    func handleToolCall(_ request: MCPToolRequest) async throws -> MCPToolResponse {
        // Validate tool
        // Execute tool
        // Return results
    }
}
```

#### 4.3 Tool Implementation
```swift
// MCPToolHandlers.swift
extension HomeGraphMCPService {
    func registerTools() -> [MCPTool] {
        return [
            createTool("get_devices_in_room") { params in
                // Implementation
            },
            createTool("search_notes") { params in
                // Implementation
            }
            // ... more tools
        ]
    }
}
```

### Testing Checklist
- [ ] All resource URIs resolve correctly
- [ ] Tools execute with proper validation
- [ ] Error handling follows protocol
- [ ] Response format matches spec
- [ ] Performance meets targets

### Success Criteria
- 100% protocol compliance
- All tools functional
- Response time < 100ms

## Phase 5: Notes Migration (Week 5-6)

### Goals
- Migrate existing notes data
- Maintain compatibility
- Implement sync mechanism

### Implementation Steps

#### 5.1 Create Migration Service
```bash
# Files to create:
Services/Migration/NotesMigrationService.swift
Services/Migration/NotesCompatibilityLayer.swift
```

#### 5.2 Migration Implementation
```swift
// NotesMigrationService.swift
class NotesMigrationService {
    func migrateNotes() async throws {
        // Read from NotesService
        // Convert to entities
        // Preserve metadata
        // Store in HomeGraph
    }
}
```

#### 5.3 Compatibility Layer
```swift
// NotesCompatibilityLayer.swift
extension HomeGraphMCPService: NotesServiceProtocol {
    // Implement NotesService methods
    // Route to MCP internally
}
```

### Testing Checklist
- [ ] All notes migrated accurately
- [ ] Metadata preserved completely
- [ ] Existing code continues working
- [ ] No data loss
- [ ] Rollback possible

### Success Criteria
- 100% data migration
- Zero breaking changes
- Performance maintained

## Phase 6: CoreML Integration (Week 6-7)

### Goals
- Add ML models
- Enhance conversation flow
- Implement intent classification

### Implementation Steps

#### 6.1 Create ML Integration
```bash
# Files to create:
Services/ML/IntentClassifier.swift
Services/ML/EntityExtractor.swift
Services/ML/CoreMLMCPBridge.swift
Models/ConversationIntent.mlmodel
```

#### 6.2 Model Integration
```swift
// IntentClassifier.swift
class IntentClassifier {
    private let model: ConversationIntentModel
    
    func classify(_ utterance: String) async throws -> IntentPrediction {
        // Preprocess
        // Run model
        // Map to MCP tools
    }
}
```

### Testing Checklist
- [ ] Models load correctly
- [ ] Predictions accurate
- [ ] Fallback to rules works
- [ ] Performance acceptable
- [ ] Privacy maintained

### Success Criteria
- >90% intent accuracy
- <200ms prediction time
- Seamless integration

## Phase 7: UI Integration (Week 7-8)

### Goals
- Update UI components
- Switch to MCP data source
- Maintain UX quality

### Implementation Steps

#### 7.1 Update ViewModels
```swift
// Update existing ViewModels to use MCP
extension NotesViewModel {
    func loadNotes() async {
        // Use MCP instead of NotesService
    }
}
```

#### 7.2 Update Views
```swift
// Minimal changes to views
// Ensure reactive updates work
```

### Testing Checklist
- [ ] UI updates properly
- [ ] No visual regressions
- [ ] Performance maintained
- [ ] All features work
- [ ] Smooth transitions

### Success Criteria
- No user-visible changes
- Performance improved
- All features functional

## Phase 8: Cleanup & Optimization (Week 8)

### Goals
- Remove old code
- Optimize performance
- Complete documentation

### Implementation Steps

#### 8.1 Code Cleanup
- Remove NotesService (keep archived)
- Update dependencies
- Clean up migrations

#### 8.2 Performance Optimization
- Profile and optimize
- Add monitoring
- Tune caching

#### 8.3 Documentation
- Update API docs
- Create user guide
- Document architecture

### Success Criteria
- Code coverage >90%
- Performance targets met
- Documentation complete

## Rollout Strategy

### Feature Flags
```swift
enum FeatureFlag {
    case useHomeGraphMCP
    case enableCoreMLIntents
    case migrateNotesData
}
```

### Gradual Rollout
1. Internal testing (1 week)
2. 5% rollout (1 week)
3. 25% rollout (1 week)
4. 50% rollout (1 week)
5. 100% rollout

### Rollback Plan
1. Feature flags allow instant rollback
2. Data remains in both systems
3. Compatibility layer ensures continuity
4. Monitor error rates continuously

## Success Metrics

### Technical Metrics
- [ ] Query performance <50ms (p99)
- [ ] Memory usage <100MB
- [ ] Crash rate <0.1%
- [ ] Error rate <0.5%

### User Metrics
- [ ] Feature adoption >80%
- [ ] User satisfaction maintained
- [ ] Support tickets not increased
- [ ] Positive app reviews

## Risk Mitigation

### Identified Risks
1. **Data Loss**: Mitigated by parallel operation
2. **Performance**: Mitigated by caching and optimization
3. **Compatibility**: Mitigated by compatibility layer
4. **User Confusion**: Mitigated by maintaining UX

### Contingency Plans
1. Instant rollback via feature flags
2. Data recovery from backups
3. Hotfix process ready
4. Support team briefed