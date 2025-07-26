# CoreML Integration Plan for HomeGraph MCP

## Overview

This document outlines how CoreML will be integrated with the HomeGraph MCP server to enable natural conversation about the house. The integration transforms the current rule-based system into an intelligent, context-aware conversational interface.

## Current State Analysis

### Existing Components
- **ConversationRecognizer**: Rule-based intent matching
- **QuestionFlowCoordinator**: State machine for Q&A flow
- **HouseThought**: Simple emotion/category structure
- **No CoreML models** currently integrated

### Planned Enhancement

Transform the conversation system to use CoreML for:
1. Intent classification
2. Entity extraction
3. Context understanding
4. Natural response generation

## CoreML Models Architecture

### 1. Intent Classification Model

```swift
// Input features
struct ConversationInput {
    let utterance: String
    let currentRoom: String?
    let timeOfDay: Date
    let recentCommands: [String]
    let houseContext: HouseContext
}

// Output predictions
struct IntentPrediction {
    let intent: ConversationIntent
    let confidence: Float
    let entities: [ExtractedEntity]
    let suggestedMCPTools: [String]
}

enum ConversationIntent: String {
    case queryDevice = "query_device"
    case controlDevice = "control_device"
    case getRoomInfo = "get_room_info"
    case searchNotes = "search_notes"
    case askQuestion = "ask_question"
    case updateInfo = "update_info"
    case navigation = "navigation"
    case emergency = "emergency"
}
```

### 2. Entity Extraction Model

```swift
struct ExtractedEntity {
    let text: String
    let type: EntityType
    let confidence: Float
    let mcpResourceURI: String?
}

enum EntityType {
    case room(String)
    case device(String)
    case person(String)
    case time(DateComponents)
    case action(String)
    case attribute(String, Any)
}
```

### 3. Context Understanding Model

```swift
class ConversationContextModel {
    // Maintains conversation state across turns
    private var contextWindow: [ConversationTurn] = []
    
    func predictNextContext(
        currentUtterance: String,
        mcpResources: [MCPResource]
    ) -> ConversationContext {
        // Use CoreML to understand context shifts
        // and maintain coherent conversation
    }
}
```

## Integration with MCP Server

### 1. Request Flow

```
User Input → Speech Recognition → CoreML Pipeline → MCP Tool Selection → Response
     ↓                                    ↓                   ↓
"Turn on kitchen lights"         Intent: controlDevice    Tool: device_control
                                Entity: kitchen_lights    Resource: homegraph://device/kitchen_lights
```

### 2. CoreML-MCP Bridge

```swift
class CoreMLMCPBridge {
    private let intentClassifier: IntentClassificationModel
    private let entityExtractor: EntityExtractionModel
    private let mcpServer: HomeGraphMCPService
    
    func processUtterance(_ text: String) async throws -> ConversationResponse {
        // 1. Classify intent
        let intent = try await intentClassifier.classify(text)
        
        // 2. Extract entities
        let entities = try await entityExtractor.extract(from: text)
        
        // 3. Map to MCP tools/resources
        let mcpMapping = mapToMCP(intent: intent, entities: entities)
        
        // 4. Execute via MCP
        if intent.confidence > 0.8 {
            // High confidence - execute locally
            return try await executeLocal(mcpMapping)
        } else {
            // Low confidence - gather context for LLM
            let context = try await gatherContext(mcpMapping)
            return try await executeLLM(text, context: context)
        }
    }
    
    private func mapToMCP(
        intent: IntentPrediction,
        entities: [ExtractedEntity]
    ) -> MCPMapping {
        // Intelligent mapping from ML predictions to MCP tools
        switch intent.intent {
        case .queryDevice:
            return MCPMapping(
                tool: "find_device_controls",
                params: ["device_name": entities.first?.text ?? ""],
                resources: entities.compactMap { $0.mcpResourceURI }
            )
        case .controlDevice:
            // Map to appropriate control tool
        case .getRoomInfo:
            // Map to room query tools
        // ... other cases
        }
    }
}
```

### 3. Natural Conversation Enhancement

```swift
extension ConversationRecognizer {
    // Enhanced version using CoreML
    func generateEnhancedHouseThought(
        from utterance: String,
        using bridge: CoreMLMCPBridge
    ) async throws -> EnhancedHouseThought {
        // Get ML predictions
        let response = try await bridge.processUtterance(utterance)
        
        // Build enhanced thought
        return EnhancedHouseThought(
            originalThought: generateHouseThought(from: utterance),
            mlPredictions: response.predictions,
            mcpResources: response.relevantResources,
            suggestedActions: response.actions,
            confidence: response.confidence,
            requiresLLM: response.confidence < 0.8
        )
    }
}
```

## Training Data Strategy

### 1. Initial Training Set

Use existing conversation patterns and house-specific vocabulary:

```json
{
  "training_examples": [
    {
      "text": "What's the temperature in the bedroom?",
      "intent": "query_device",
      "entities": [
        {"text": "temperature", "type": "attribute"},
        {"text": "bedroom", "type": "room"}
      ],
      "mcp_tool": "get_devices_in_room",
      "mcp_params": {"room_name": "bedroom", "filter": "temperature_sensor"}
    },
    {
      "text": "Turn off all the lights",
      "intent": "control_device",
      "entities": [
        {"text": "turn off", "type": "action"},
        {"text": "all the lights", "type": "device_group"}
      ],
      "mcp_tool": "control_devices",
      "mcp_params": {"action": "turn_off", "device_type": "light"}
    }
  ]
}
```

### 2. Continuous Learning

```swift
class MLTrainingCollector {
    func collectTrainingData(
        utterance: String,
        prediction: IntentPrediction,
        actualOutcome: ConversationOutcome,
        userFeedback: UserFeedback?
    ) {
        // Store for model improvement
        let trainingExample = TrainingExample(
            input: utterance,
            predictedIntent: prediction.intent,
            actualIntent: actualOutcome.intent,
            success: actualOutcome.success,
            userSatisfaction: userFeedback?.rating
        )
        
        // Queue for federated learning
        trainingQueue.append(trainingExample)
    }
}
```

## Implementation Phases

### Phase 1: Intent Classification (Week 1-2)
1. Create training data from existing patterns
2. Train basic intent classification model
3. Integrate with ConversationRecognizer
4. A/B test against rule-based system

### Phase 2: Entity Extraction (Week 3-4)
1. Annotate entities in training data
2. Train NER model for house entities
3. Map entities to MCP resources
4. Test extraction accuracy

### Phase 3: Context Understanding (Week 5-6)
1. Implement conversation memory
2. Train context continuation model
3. Handle multi-turn conversations
4. Test coherence over sessions

### Phase 4: Full Integration (Week 7-8)
1. Complete CoreML-MCP bridge
2. Implement confidence thresholds
3. Add LLM fallback mechanism
4. Deploy with feature flags

## Natural Conversation Examples

### Before (Rule-based)
```
User: "Is it too hot in here?"
System: "I don't understand that command."
```

### After (CoreML-enhanced)
```
User: "Is it too hot in here?"
System: "The living room is currently 78°F, which is 6 degrees above your preferred temperature. Would you like me to adjust the thermostat?"

[CoreML identified:
- Intent: query_device + evaluate_comfort
- Entities: implicit current room, temperature attribute
- Context: comfort evaluation needed
- MCP Tools: get_room_temperature, get_user_preferences, suggest_actions]
```

### Complex Multi-turn Example
```
User: "Check if all the doors are locked"
System: "I've checked all 4 doors. The front door and back door are locked. The garage side door and patio door are unlocked. Would you like me to show you which rooms they're in?"

User: "Yes, and are there any lights on near them?"
System: "The garage side door is in the garage, which has 2 lights currently on. The patio door is in the family room, where the overhead light is off but the table lamp is on. Would you like me to turn off these lights?"

[CoreML maintains context across turns, understanding "them" refers to unlocked doors]
```

## Performance Metrics

### Target Metrics
- Intent classification accuracy: >95%
- Entity extraction F1 score: >90%
- Local processing rate: >80% (reduce LLM calls)
- Response latency: <200ms for local, <2s with LLM
- User satisfaction: >4.5/5 rating

### Monitoring
```swift
class MLPerformanceMonitor {
    func trackPrediction(
        model: String,
        prediction: Any,
        latency: TimeInterval,
        outcome: PredictionOutcome
    ) {
        // Track for optimization
        metrics.record(
            model: model,
            accuracy: outcome.accurate,
            latency: latency,
            confidence: outcome.confidence
        )
    }
}
```

## Privacy Considerations

1. All CoreML models run on-device
2. No utterances sent to cloud without consent
3. Training data anonymized and aggregated
4. User can opt-out of improvement program
5. Local model personalization stays on device

## Future Enhancements

1. **Multi-modal Input**: Combine voice with gesture recognition
2. **Proactive Suggestions**: Predict needs based on patterns
3. **Emotional Intelligence**: Detect and respond to user mood
4. **Personalization**: Adapt to individual speech patterns
5. **Multilingual Support**: Extend to multiple languages