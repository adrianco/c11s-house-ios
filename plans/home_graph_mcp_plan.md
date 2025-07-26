# HomeGraph MCP Implementation Plan

## Overview
Replace the complex CoreData Notes service with a clean, versioned knowledge graph storage system that integrates HomeKit data with additional smart home context. This will serve as the foundation for an MCP server providing intelligent home assistance.

## Phase 1: Core Storage Foundation

### 1.1 SQLite Schema Design
```sql
-- Main entity storage with immutable versioning
CREATE TABLE entities (
    id TEXT NOT NULL,           -- UUID for entity
    version TEXT NOT NULL,      -- ISO8601 timestamp + user_id
    entity_type TEXT NOT NULL,  -- "room", "device", "accessory", "procedure", "manual"
    parent_versions TEXT,       -- JSON array of parent version IDs
    content TEXT NOT NULL,      -- JSON blob with entity data
    user_id TEXT NOT NULL,      -- User who created this version
    created_at INTEGER NOT NULL, -- Unix timestamp
    source_type TEXT,           -- "homekit", "manual", "imported"
    PRIMARY KEY (id, version)
);

-- Fast lookup indices
CREATE INDEX idx_entities_type ON entities(entity_type);
CREATE INDEX idx_entities_user ON entities(user_id);
CREATE INDEX idx_entities_created ON entities(created_at);

-- Relationship storage for graph traversal
CREATE TABLE relationships (
    id TEXT PRIMARY KEY,
    from_entity_id TEXT NOT NULL,
    to_entity_id TEXT NOT NULL,
    relationship_type TEXT NOT NULL, -- "located_in", "controls", "connects_to"
    from_version TEXT NOT NULL,
    to_version TEXT NOT NULL,
    properties TEXT,                 -- JSON blob for relationship metadata
    created_at INTEGER NOT NULL,
    FOREIGN KEY (from_entity_id, from_version) REFERENCES entities(id, version),
    FOREIGN KEY (to_entity_id, to_version) REFERENCES entities(id, version)
);

CREATE INDEX idx_relationships_from ON relationships(from_entity_id);
CREATE INDEX idx_relationships_to ON relationships(to_entity_id);
CREATE INDEX idx_relationships_type ON relationships(relationship_type);

-- Sync metadata for distributed updates
CREATE TABLE sync_state (
    user_id TEXT PRIMARY KEY,
    last_sync_version TEXT,
    vector_clock TEXT           -- JSON object tracking version vectors
);

-- Binary content storage (images, PDFs, etc.)
CREATE TABLE binary_content (
    id TEXT PRIMARY KEY,
    entity_id TEXT NOT NULL,
    entity_version TEXT NOT NULL,
    content_type TEXT NOT NULL, -- MIME type
    file_name TEXT,
    data BLOB NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (entity_id, entity_version) REFERENCES entities(id, version)
);
```

### 1.2 Swift Data Models
```swift
// Core entity representation
struct HomeEntity {
    let id: String
    let version: String
    let entityType: EntityType
    let parentVersions: [String]
    let content: [String: Any]
    let userId: String
    let createdAt: Date
    let sourceType: SourceType
}

enum EntityType: String, CaseIterable {
    case room = "room"
    case device = "device" 
    case accessory = "accessory"
    case procedure = "procedure"
    case manual = "manual"
    case zone = "zone"
    case door = "door"
}

enum SourceType: String {
    case homekit = "homekit"
    case manual = "manual"
    case imported = "imported"
}

// Relationship between entities
struct EntityRelationship {
    let id: String
    let fromEntityId: String
    let toEntityId: String
    let relationshipType: RelationshipType
    let fromVersion: String
    let toVersion: String
    let properties: [String: Any]
    let createdAt: Date
}

enum RelationshipType: String, CaseIterable {
    case locatedIn = "located_in"
    case controls = "controls"
    case connectsTo = "connects_to"
    case partOf = "part_of"
    case manages = "manages"
}
```

## Phase 2: HomeKit Integration Bridge

### 2.1 HomeKit Data Extraction
Create a service that converts existing HomeKit data into graph entities:

```swift
class HomeKitGraphBridge {
    func extractHomeKitData() -> [HomeEntity] {
        var entities: [HomeEntity] = []
        
        // Extract home as root entity
        for home in homeManager.homes {
            entities.append(createHomeEntity(from: home))
            
            // Extract rooms
            for room in home.rooms {
                entities.append(createRoomEntity(from: room, homeId: home.uniqueIdentifier))
                
                // Extract accessories in each room
                for accessory in room.accessories {
                    entities.append(createAccessoryEntity(from: accessory, roomId: room.uniqueIdentifier))
                    
                    // Extract services for each accessory
                    for service in accessory.services {
                        entities.append(createServiceEntity(from: service, accessoryId: accessory.uniqueIdentifier))
                    }
                }
            }
        }
        
        return entities
    }
    
    private func createRoomEntity(from room: HMRoom, homeId: UUID) -> HomeEntity {
        let content: [String: Any] = [
            "name": room.name,
            "homekit_identifier": room.uniqueIdentifier.uuidString,
            "home_id": homeId.uuidString
        ]
        
        return HomeEntity(
            id: room.uniqueIdentifier.uuidString,
            version: generateVersion(),
            entityType: .room,
            parentVersions: [],
            content: content,
            userId: getCurrentUserId(),
            createdAt: Date(),
            sourceType: .homekit
        )
    }
    
    // Similar methods for accessories, services, etc.
}
```

### 2.2 Relationship Extraction
```swift
extension HomeKitGraphBridge {
    func extractRelationships() -> [EntityRelationship] {
        var relationships: [EntityRelationship] = []
        
        for home in homeManager.homes {
            for room in home.rooms {
                for accessory in room.accessories {
                    // Create "located_in" relationship
                    relationships.append(EntityRelationship(
                        id: UUID().uuidString,
                        fromEntityId: accessory.uniqueIdentifier.uuidString,
                        toEntityId: room.uniqueIdentifier.uuidString,
                        relationshipType: .locatedIn,
                        fromVersion: latestVersion(for: accessory.uniqueIdentifier.uuidString),
                        toVersion: latestVersion(for: room.uniqueIdentifier.uuidString),
                        properties: [:],
                        createdAt: Date()
                    ))
                }
            }
        }
        
        return relationships
    }
}
```

## Phase 3: Storage Layer Implementation

### 3.1 SQLite Manager
```swift
class HomeGraphStorage {
    private let dbQueue: DatabaseQueue
    
    init(databaseURL: URL) throws {
        dbQueue = try DatabaseQueue(path: databaseURL.path)
        try setupDatabase()
    }
    
    func store(entity: HomeEntity) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO entities (id, version, entity_type, parent_versions, content, user_id, created_at, source_type)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    entity.id,
                    entity.version,
                    entity.entityType.rawValue,
                    try JSONSerialization.data(withJSONObject: entity.parentVersions),
                    try JSONSerialization.data(withJSONObject: entity.content),
                    entity.userId,
                    entity.createdAt.timeIntervalSince1970,
                    entity.sourceType.rawValue
                ])
        }
    }
    
    func fetchEntities(ofType type: EntityType) throws -> [HomeEntity] {
        return try dbQueue.read { db in
            // Implementation for fetching latest versions
        }
    }
}
```

### 3.2 In-Memory Graph Layer
```swift
class HomeGraph {
    private var entities: [String: HomeEntity] = [:]
    private var relationshipsBySource: [String: [EntityRelationship]] = [:]
    private var relationshipsByTarget: [String: [EntityRelationship]] = [:]
    
    func loadFromStorage(_ storage: HomeGraphStorage) throws {
        // Load all latest entity versions
        for entityType in EntityType.allCases {
            let entities = try storage.fetchEntities(ofType: entityType)
            for entity in entities {
                self.entities[entity.id] = entity
            }
        }
        
        // Load and index relationships
        let relationships = try storage.fetchAllRelationships()
        indexRelationships(relationships)
    }
    
    func entitiesInRoom(_ roomId: String) -> [HomeEntity] {
        guard let roomRelationships = relationshipsByTarget[roomId] else { return [] }
        
        return roomRelationships
            .filter { $0.relationshipType == .locatedIn }
            .compactMap { entities[$0.fromEntityId] }
    }
    
    func devicesControlling(_ entityId: String) -> [HomeEntity] {
        guard let controlRelationships = relationshipsByTarget[entityId] else { return [] }
        
        return controlRelationships
            .filter { $0.relationshipType == .controls }
            .compactMap { entities[$0.fromEntityId] }
    }
}
```

## Phase 4: MCP Server Implementation

### 4.1 Core MCP Server
```swift
protocol MCPServer {
    func handleResourceRequest(_ request: MCPResourceRequest) async throws -> MCPResourceResponse
    func handleToolCall(_ request: MCPToolRequest) async throws -> MCPToolResponse
    func handlePromptRequest(_ request: MCPPromptRequest) async throws -> MCPPromptResponse
}

class HomeGraphMCPServer: MCPServer {
    private let graph: HomeGraph
    
    init(graph: HomeGraph) {
        self.graph = graph
    }
    
    func handleResourceRequest(_ request: MCPResourceRequest) async throws -> MCPResourceResponse {
        // Parse URI like "homegraph://device/kitchen_lights"
        let components = parseResourceURI(request.uri)
        
        switch components.type {
        case "device":
            if let device = graph.entities[components.id] {
                return MCPResourceResponse(
                    contents: [.text(formatDeviceInfo(device))]
                )
            }
        case "room":
            if let room = graph.entities[components.id] {
                let devicesInRoom = graph.entitiesInRoom(components.id)
                return MCPResourceResponse(
                    contents: [.text(formatRoomInfo(room, devices: devicesInRoom))]
                )
            }
        }
        
        throw MCPError.resourceNotFound
    }
}
```

### 4.2 MCP Tools
```swift
extension HomeGraphMCPServer {
    func registerTools() -> [MCPTool] {
        return [
            MCPTool(
                name: "get_devices_in_room",
                description: "Get all devices located in a specific room",
                inputSchema: [
                    "room_name": ["type": "string", "description": "Name of the room"]
                ]
            ) { [weak self] arguments in
                guard let self = self,
                      let roomName = arguments["room_name"] as? String else {
                    throw MCPError.invalidArguments
                }
                
                let room = self.graph.entities.values.first { entity in
                    entity.entityType == .room && 
                    (entity.content["name"] as? String) == roomName
                }
                
                guard let room = room else {
                    return MCPToolResponse(content: [.text("Room '\(roomName)' not found")])
                }
                
                let devices = self.graph.entitiesInRoom(room.id)
                let deviceList = devices.map { device in
                    "\(device.content["name"] as? String ?? "Unknown"): \(device.content["type"] as? String ?? "Unknown type")"
                }.joined(separator: "\n")
                
                return MCPToolResponse(content: [.text("Devices in \(roomName):\n\(deviceList)")])
            },
            
            MCPTool(
                name: "find_device_controls",
                description: "Get available controls and current state for a device",
                inputSchema: [
                    "device_name": ["type": "string", "description": "Name of the device"]
                ]
            ) { [weak self] arguments in
                // Implementation for device controls
            },
            
            MCPTool(
                name: "get_room_connections", 
                description: "Find doors and passages between rooms",
                inputSchema: [
                    "from_room": ["type": "string", "description": "Starting room name"],
                    "to_room": ["type": "string", "description": "Destination room name", "required": false]
                ]
            ) { [weak self] arguments in
                // Implementation for room navigation
            }
        ]
    }
}
```

## Phase 5: Integration Points

### 5.1 Conversational Interface Integration
```swift
class ConversationManager {
    private let mcpServer: HomeGraphMCPServer
    private let intentClassifier: CoreMLIntentClassifier
    
    func processUserMessage(_ message: String) async throws -> String {
        // Use CoreML to classify intent and extract entities
        let intent = try intentClassifier.classify(message)
        
        if intent.confidence > 0.8 && intent.canHandleLocally {
            // Handle with MCP tools directly
            let toolResult = try await mcpServer.handleToolCall(intent.mcpToolRequest)
            return formatResponse(toolResult)
        } else {
            // Send to Claude/ChatGPT with MCP context
            let relevantContext = try await gatherMCPContext(for: intent)
            return try await callExternalLLM(message: message, context: relevantContext)
        }
    }
    
    private func gatherMCPContext(for intent: ClassifiedIntent) async throws -> String {
        // Use MCP tools to gather relevant context
        // Only include data relevant to the user's intent
    }
}
```

### 5.2 Location & Weather Integration
```swift
extension HomeGraphMCPServer {
    func addContextualTools() {
        // Tools that combine location, weather, and home state
        registerTool("suggest_actions_for_weather") { arguments in
            let currentWeather = self.weatherService.currentConditions
            let currentRoom = self.locationService.currentRoom
            
            // Use graph to find relevant devices and suggest actions
        }
    }
}
```

## Implementation Timeline

### Week 1-2: Foundation
- Implement SQLite schema and basic storage layer
- Create HomeKit bridge for data extraction
- Test with simple entity storage and retrieval

### Week 3-4: Graph Layer & MCP Server
- Build in-memory graph with relationship indexing  
- Implement core MCP server with essential tools
- Test graph queries and relationship traversal

### Week 5-6: Integration & Intelligence
- Connect MCP server to existing conversational interface
- Implement CoreML intent classification for local processing
- Add external LLM fallback with context summarization
- Replace CoreData Notes service with HomeGraph storage

### Week 7-8: Polish & Enhancement
- Add binary content storage for device images/manuals
- Performance optimization and comprehensive testing
- Prepare foundation for distributed sync implementation

## Success Metrics
- [ ] All HomeKit data successfully imported as graph entities
- [ ] Fast in-memory queries (< 50ms for typical requests)
- [ ] MCP tools provide accurate device and room information
- [ ] Successful integration with conversational interface
- [ ] CoreData Notes system cleanly replaced
- [ ] Offline functionality maintained
- [ ] Foundation ready for distributed sync implementation

## Future Extensions
- Sync layer for multi-user distributed updates
- Procedures and workflow storage
- Device manual and image management
- Advanced graph algorithms (shortest path, centrality)
- Integration with additional smart home platforms