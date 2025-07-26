# Notes to MCP Resource and Tool Mapping

## Overview

This document details how the existing NotesService data model maps to MCP resources and tools, ensuring all current functionality is preserved while enabling richer interactions.

## Data Model Transformation

### 1. Questions → MCP Resources

Current NotesService questions become queryable MCP resources:

| NotesService Question | MCP Resource URI | Resource Type |
|----------------------|------------------|---------------|
| "Is this the right address?" | `homegraph://house/address` | House Info |
| "What should I call this house?" | `homegraph://house/name` | House Info |
| "What's your name?" | `homegraph://user/profile` | User Info |
| Category questions | `homegraph://question/[category]/[id]` | Q&A Resource |

### 2. Notes → Graph Entities

Notes transform into rich graph entities with relationships:

```swift
// Current Note structure
struct Note {
    let id: String
    let questionId: String
    let answer: String
    let timestamp: Date
    let metadata: [String: Any]?
}

// New Graph Entity
struct HomeEntity {
    let id: String
    let version: String
    let entityType: EntityType  // .note, .room, .device, etc.
    let parentVersions: [String]
    let content: [String: Any]  // Rich content including original note data
    let userId: String
    let createdAt: Date
    let sourceType: SourceType  // .manual, .homekit, .imported
}
```

### 3. Metadata Preservation

All existing metadata is preserved and enhanced:

```json
{
  "legacy_metadata": {
    // Original metadata from NotesService
    "voiceRecordingURL": "...",
    "imageURL": "...",
    "customData": {}
  },
  "graph_metadata": {
    "relationships": ["located_in", "references"],
    "tags": ["weather", "maintenance", "preference"],
    "confidence": 0.95,
    "source": "user_input"
  }
}
```

## MCP Resource Mappings

### House Information Resources

```swift
// Resource: homegraph://house/info
{
  "uri": "homegraph://house/info",
  "name": "House Information",
  "description": "Core information about the house",
  "mimeType": "application/json",
  "contents": {
    "name": "My Home",  // From "What should I call this house?"
    "address": "123 Main St",  // From "Is this the right address?"
    "created": "2024-01-15",
    "rooms": 12,
    "devices": 47,
    "lastUpdated": "2024-01-20"
  }
}
```

### User Profile Resources

```swift
// Resource: homegraph://user/profile
{
  "uri": "homegraph://user/profile",
  "name": "User Profile",
  "description": "User preferences and information",
  "contents": {
    "name": "John",  // From "What's your name?"
    "preferences": {
      "temperature": "72F",
      "lighting": "warm",
      "notifications": true
    }
  }
}
```

### Q&A Resources

Each question/answer pair becomes a resource:

```swift
// Resource: homegraph://qa/maintenance/hvac_filter
{
  "uri": "homegraph://qa/maintenance/hvac_filter",
  "name": "HVAC Filter Replacement",
  "category": "maintenance",
  "question": "When should I replace the HVAC filter?",
  "answer": "Every 3 months, last replaced on October 15",
  "metadata": {
    "nextDue": "2024-01-15",
    "reminderSet": true
  }
}
```

## MCP Tool Mappings

### 1. Query Tools

**Tool: search_notes**
```json
{
  "name": "search_notes",
  "description": "Search through all notes and Q&A pairs",
  "inputSchema": {
    "query": {
      "type": "string",
      "description": "Search query"
    },
    "category": {
      "type": "string",
      "enum": ["general", "maintenance", "emergency", "contacts"],
      "optional": true
    },
    "dateRange": {
      "type": "object",
      "properties": {
        "start": {"type": "string", "format": "date"},
        "end": {"type": "string", "format": "date"}
      },
      "optional": true
    }
  }
}
```

**Tool: get_answer**
```json
{
  "name": "get_answer",
  "description": "Get the answer to a specific question",
  "inputSchema": {
    "questionId": {
      "type": "string",
      "description": "The question ID or text"
    }
  }
}
```

### 2. Update Tools

**Tool: update_note**
```json
{
  "name": "update_note",
  "description": "Update an existing note or answer",
  "inputSchema": {
    "noteId": {
      "type": "string",
      "description": "The note or question ID"
    },
    "answer": {
      "type": "string",
      "description": "New answer text"
    },
    "metadata": {
      "type": "object",
      "optional": true
    }
  }
}
```

### 3. Context Tools

**Tool: get_conversation_context**
```json
{
  "name": "get_conversation_context",
  "description": "Get relevant context for natural conversation",
  "inputSchema": {
    "topic": {
      "type": "string",
      "description": "Conversation topic or intent"
    },
    "includeHistory": {
      "type": "boolean",
      "default": true
    }
  }
}
```

## Special Mappings

### Weather Summaries

Weather summaries auto-saved as notes become specialized resources:

```swift
// Resource: homegraph://weather/summary/2024_01_15
{
  "uri": "homegraph://weather/summary/2024_01_15",
  "name": "Weather Summary - Jan 15, 2024",
  "contents": {
    "summary": "Partly cloudy, high of 72°F",
    "details": "...",
    "relatedActions": [
      "Windows can be opened",
      "AC can be reduced"
    ]
  }
}
```

### Room-Specific Notes

Notes attached to rooms become room entity properties:

```swift
// Resource: homegraph://room/kitchen
{
  "uri": "homegraph://room/kitchen",
  "name": "Kitchen",
  "contents": {
    "homekitData": {...},
    "userNotes": [
      {
        "id": "note_123",
        "content": "Dishwasher runs best on eco mode",
        "created": "2024-01-10"
      }
    ]
  }
}
```

## Migration Process

### Phase 1: Parallel Operation
1. NotesService continues to work normally
2. New MCP server reads from NotesService data
3. All writes go to both systems

### Phase 2: Read Migration
1. UI components switch to MCP resources
2. NotesService becomes read-only
3. Validation of data consistency

### Phase 3: Write Migration
1. All writes go through MCP server
2. NotesService deprecated but available
3. Background sync ensures consistency

### Phase 4: Cleanup
1. Remove NotesService dependencies
2. Archive old data format
3. Complete migration

## Backwards Compatibility

### API Compatibility Layer

```swift
// Compatibility extension for existing code
extension HomeGraphMCPService {
    // Mimics NotesService.shared.getNote(for:)
    func getNote(for questionId: String) async throws -> String? {
        let request = MCPToolRequest(
            method: "get_answer",
            params: ["questionId": questionId]
        )
        let response = try await handleToolCall(request)
        return response.content.first?.text
    }
    
    // Mimics NotesService.shared.saveNote(_:for:)
    func saveNote(_ answer: String, for questionId: String) async throws {
        let request = MCPToolRequest(
            method: "update_note",
            params: [
                "noteId": questionId,
                "answer": answer
            ]
        )
        _ = try await handleToolCall(request)
    }
}
```

This ensures existing code continues to work during migration.