# HomeGraph MCP Server Architecture Overview

## Executive Summary

This document outlines the architecture for replacing the existing NotesService with a Model Context Protocol (MCP) server that provides intelligent home assistance capabilities. The new system will integrate with CoreML for natural language processing and expose home data through standardized MCP resources and tools.

## Key Architectural Decisions

### 1. Conforming to Swift MCP Patterns

Based on analysis of existing MCP implementations in the codebase, the HomeGraph MCP server will follow these Swift conventions:

```swift
protocol HomeGraphMCPServiceProtocol: MCPServiceProtocol {
    func handleResourceRequest(_ request: MCPResourceRequest) async throws -> MCPResourceResponse
    func handleToolCall(_ request: MCPToolRequest) async throws -> MCPToolResponse
    func handlePromptRequest(_ request: MCPPromptRequest) async throws -> MCPPromptResponse
}

class HomeGraphMCPService: HomeGraphMCPServiceProtocol {
    // Implementation following existing service patterns
}
```

### 2. Service Container Integration

The MCP server will integrate with the existing ServiceContainer pattern:

```swift
extension ServiceContainer {
    lazy var homeGraphMCP: HomeGraphMCPServiceProtocol = {
        HomeGraphMCPService(
            storage: homeGraphStorage,
            graph: homeGraph,
            coreMLIntegration: coreMLService
        )
    }()
}
```

### 3. Data Model Architecture

#### From Notes to Graph

The current NotesService uses a flat key-value structure. The new HomeGraph uses a rich graph model:

**Current (NotesService)**:
- Questions with categories
- Notes as answers
- Metadata dictionary
- Version for migration

**New (HomeGraph)**:
- Entities (rooms, devices, procedures)
- Relationships (located_in, controls)
- Immutable versioning
- Rich metadata support

### 4. Storage Architecture

```
┌─────────────────────────────────────────────────┐
│                MCP Server Layer                  │
│  ┌───────────┐ ┌────────────┐ ┌──────────────┐ │
│  │ Resources │ │   Tools    │ │   Prompts    │ │
│  └─────┬─────┘ └──────┬─────┘ └──────┬───────┘ │
│        │              │               │         │
│  ┌─────┴──────────────┴───────────────┴──────┐ │
│  │         HomeGraphMCPService               │ │
│  └────────────────┬───────────────────────────┘ │
└───────────────────┼─────────────────────────────┘
                    │
┌───────────────────┼─────────────────────────────┐
│                   │    Business Logic            │
│  ┌────────────────┴───────────────────────────┐ │
│  │            HomeGraph (In-Memory)            │ │
│  │  - Entity Cache                             │ │
│  │  - Relationship Index                       │ │
│  │  - Query Optimization                       │ │
│  └────────────────┬───────────────────────────┘ │
└───────────────────┼─────────────────────────────┘
                    │
┌───────────────────┼─────────────────────────────┐
│                   │    Storage Layer             │
│  ┌────────────────┴───────────────────────────┐ │
│  │         HomeGraphStorage (SQLite)           │ │
│  │  - Entities Table                           │ │
│  │  - Relationships Table                      │ │
│  │  - Binary Content Table                     │ │
│  │  - Sync State Table                         │ │
│  └─────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘
```

### 5. CoreML Integration Architecture

```
┌──────────────────────────────────────────────────┐
│           ConversationRecognizer                  │
│  ┌─────────────────┐  ┌─────────────────────┐   │
│  │  Speech Input   │  │  CoreML Models      │   │
│  └────────┬────────┘  └──────────┬──────────┘   │
│           │                      │               │
│  ┌────────┴──────────────────────┴────────────┐ │
│  │         Intent Classification              │ │
│  │  - Local Processing (high confidence)      │ │
│  │  - MCP Context Gathering                   │ │
│  │  - External LLM Fallback                   │ │
│  └────────────────┬───────────────────────────┘ │
└───────────────────┼──────────────────────────────┘
                    │
                    ▼
         ┌─────────────────────┐
         │  HomeGraphMCPServer │
         └─────────────────────┘
```

### 6. Resource URI Scheme

Resources follow the pattern: `homegraph://[type]/[identifier]`

Examples:
- `homegraph://room/living_room`
- `homegraph://device/kitchen_lights`
- `homegraph://procedure/bedtime_routine`
- `homegraph://manual/dishwasher_guide`
- `homegraph://note/weather_summary_2024_01_15`

### 7. Tool Registry

The MCP server exposes these primary tools:

1. **Query Tools**:
   - `get_devices_in_room` - List all devices in a specific room
   - `find_device_controls` - Get available controls for a device
   - `get_room_connections` - Find passages between rooms

2. **Knowledge Tools**:
   - `search_notes` - Search through migrated notes content
   - `get_house_info` - Retrieve house-level information
   - `find_procedures` - Search for procedures and routines

3. **Action Tools**:
   - `suggest_actions` - Context-aware action suggestions
   - `explain_device` - Get detailed device information
   - `navigate_house` - Path finding between rooms

### 8. Error Handling

Following Swift conventions, errors are handled with:

```swift
enum HomeGraphMCPError: Error, LocalizedError, UserFriendlyError {
    case entityNotFound(String)
    case invalidURI(String)
    case storageError(Error)
    case graphNotLoaded
    
    var errorDescription: String? {
        switch self {
        case .entityNotFound(let id):
            return "Could not find entity with ID: \(id)"
        case .invalidURI(let uri):
            return "Invalid resource URI: \(uri)"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .graphNotLoaded:
            return "Home graph is not loaded"
        }
    }
    
    var userFriendlyMessage: String {
        // User-friendly messages for UI display
    }
}
```

### 9. Concurrency Model

- All MCP methods use async/await
- Thread-safe with actors for storage operations
- @MainActor for UI-related updates
- Combine publishers for reactive updates

### 10. Migration Strategy

The system supports parallel operation during migration:

1. NotesService remains active (read-only mode)
2. HomeGraphMCPServer handles new requests
3. Migration service syncs data in background
4. Gradual cutover with feature flags

## Next Steps

See the following documents for detailed implementation:
- [02_notes_to_mcp_mapping.md](02_notes_to_mcp_mapping.md) - Data mapping details
- [03_coreml_integration_plan.md](03_coreml_integration_plan.md) - ML integration
- [04_implementation_phases.md](04_implementation_phases.md) - Step-by-step plan
- [05_testing_strategy.md](05_testing_strategy.md) - Testing approach