# Voice Interface Implementation Plan

## Overview
This document outlines the voice interface design and implementation strategy for the c11s-house-ios app, focusing on natural voice interactions with the house consciousness system.

## Architecture

### Core Components

```swift
// VoiceInterfaceManager.swift
protocol VoiceInterfaceProtocol {
    func startListening() async throws
    func stopListening()
    func processVoiceInput(_ text: String) async throws -> HouseResponse
    func synthesizeSpeech(_ response: HouseResponse) async throws
}

// ConversationStateManager.swift
protocol ConversationStateProtocol {
    var currentContext: ConversationContext { get }
    func updateContext(with input: String, response: HouseResponse)
    func resetContext()
    func saveConversationHistory()
}
```

## Speech Recognition Implementation

### 1. Core Speech Framework Integration

```swift
import Speech
import AVFoundation

class SpeechRecognitionService: NSObject {
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Configuration for house-specific vocabulary
    private let customVocabulary = [
        "consciousness", "awareness", "room mode",
        "energy", "ambiance", "presence"
    ]
}
```

### 2. Continuous Listening Mode

- **Wake Word Detection**: "Hey House" or "House"
- **Active Listening Duration**: 30 seconds max per interaction
- **Background Noise Filtering**: Adaptive noise cancellation
- **Multi-language Support**: Initially English, expandable architecture

### 3. Test Scenarios for Speech Recognition

```swift
// SpeechRecognitionTests.swift
class SpeechRecognitionTests: XCTestCase {
    
    func testWakeWordDetection() async throws {
        // Given: Mock audio input with wake word
        let mockAudio = MockAudioGenerator.generateWakeWord("Hey House")
        
        // When: Process audio
        let detected = await speechService.detectWakeWord(mockAudio)
        
        // Then: Wake word should be detected
        XCTAssertTrue(detected)
    }
    
    func testNoiseFiltering() async throws {
        // Given: Voice input with background noise
        let noisyAudio = MockAudioGenerator.generateNoisyInput(
            speech: "Turn on living room lights",
            noiseLevel: 0.3
        )
        
        // When: Process recognition
        let result = await speechService.recognize(noisyAudio)
        
        // Then: Should extract correct text
        XCTAssertEqual(result.text, "Turn on living room lights")
    }
    
    func testAccentVariations() async throws {
        // Test various accent patterns
        let accents = ["american", "british", "australian", "indian"]
        
        for accent in accents {
            let audio = MockAudioGenerator.generateAccentedSpeech(
                text: "Set bedroom to sleep mode",
                accent: accent
            )
            
            let result = await speechService.recognize(audio)
            XCTAssertTrue(result.confidence > 0.8)
        }
    }
}
```

## Natural Language Processing Approach

### 1. Intent Classification

```swift
enum HouseIntent {
    case roomControl(room: String, action: RoomAction)
    case queryStatus(entity: String)
    case setMode(mode: HouseMode)
    case scheduleAction(action: String, time: Date)
    case conversational(topic: String)
    case emergency(type: EmergencyType)
}

struct IntentClassifier {
    func classify(_ input: String) async -> (intent: HouseIntent, confidence: Float)
}
```

### 2. Context Understanding

- **Multi-turn Conversations**: Track conversation history
- **Pronoun Resolution**: "Turn it off" → resolve "it" from context
- **Implicit References**: "Make it warmer" → infer room from user location
- **Temporal Context**: "Like yesterday" → retrieve previous settings

### 3. NLP Test Fixtures

```swift
// NLPTestFixtures.swift
struct NLPTestCase {
    let input: String
    let context: ConversationContext?
    let expectedIntent: HouseIntent
    let expectedEntities: [String: Any]
}

let nlpTestCases = [
    NLPTestCase(
        input: "Turn on the lights in the living room",
        context: nil,
        expectedIntent: .roomControl(room: "living room", action: .lightsOn),
        expectedEntities: ["room": "living room", "device": "lights", "action": "on"]
    ),
    NLPTestCase(
        input: "Make it brighter",
        context: ConversationContext(lastRoom: "bedroom", lastDevice: "lights"),
        expectedIntent: .roomControl(room: "bedroom", action: .adjustBrightness(increase: true)),
        expectedEntities: ["adjustment": "brighter", "implicit_device": "lights"]
    )
]
```

## Voice Synthesis and Feedback Design

### 1. Response Personality

```swift
struct VoicePersonality {
    let tone: VoiceTone = .friendly
    let speed: Float = 1.0
    let pitch: Float = 1.0
    let formality: Formality = .casual
    
    // Adaptive personality based on context
    func adjust(for context: ConversationContext) -> VoicePersonality {
        if context.isEmergency {
            return VoicePersonality(tone: .alert, speed: 1.2, pitch: 1.1, formality: .direct)
        }
        return self
    }
}
```

### 2. Response Types

- **Confirmation**: Brief acknowledgments ("Sure", "Done", "Got it")
- **Status Updates**: Informative responses with relevant details
- **Clarification**: Asking for more information when needed
- **Suggestions**: Proactive recommendations based on patterns
- **Error Feedback**: Gentle corrections with alternatives

### 3. Audio Feedback Patterns

```swift
enum AudioFeedback {
    case chime(type: ChimeType)
    case haptic(pattern: HapticPattern)
    case visual(animation: VisualFeedback)
    
    enum ChimeType {
        case listening
        case processing
        case success
        case error
        case notification
    }
}
```

## Conversation State Management

### 1. State Machine Design

```swift
enum ConversationState {
    case idle
    case awaitingWakeWord
    case listening
    case processing
    case responding
    case awaitingFollowUp
    case error(Error)
}

class ConversationStateMachine {
    private(set) var currentState: ConversationState = .idle
    private var stateHistory: [ConversationState] = []
    private var contextWindow: TimeInterval = 30.0
    
    func transition(to newState: ConversationState) {
        stateHistory.append(currentState)
        currentState = newState
        notifyStateChange()
    }
}
```

### 2. Context Persistence

```swift
struct ConversationContext: Codable {
    let sessionId: UUID
    let startTime: Date
    var interactions: [Interaction]
    var userPreferences: UserPreferences
    var environmentalContext: EnvironmentalContext
    
    struct Interaction: Codable {
        let timestamp: Date
        let userInput: String
        let houseResponse: String
        let intent: String
        let entities: [String: String]
        let success: Bool
    }
}
```

### 3. Memory Integration

- **Short-term Memory**: Current session context (in-memory)
- **Long-term Memory**: User preferences and patterns (persisted)
- **Episodic Memory**: Specific interaction histories
- **Semantic Memory**: Learned associations and routines

## Error Handling and Fallback Strategies

### 1. Error Categories

```swift
enum VoiceInterfaceError: Error {
    case speechRecognitionFailed(reason: String)
    case networkUnavailable
    case intentNotUnderstood(input: String)
    case deviceNotResponding(device: String)
    case permissionDenied(permission: PermissionType)
    case timeout(operation: String)
}
```

### 2. Graceful Degradation

```swift
protocol FallbackStrategy {
    func handle(error: VoiceInterfaceError) async -> RecoveryAction
}

struct VoiceFallbackHandler: FallbackStrategy {
    func handle(error: VoiceInterfaceError) async -> RecoveryAction {
        switch error {
        case .speechRecognitionFailed:
            return .retryWithVisualPrompt
        case .networkUnavailable:
            return .switchToOfflineMode
        case .intentNotUnderstood(let input):
            return .requestClarification(suggestions: generateSuggestions(for: input))
        case .deviceNotResponding(let device):
            return .notifyAndOfferAlternative(device: device)
        case .permissionDenied(let permission):
            return .guideToSettings(permission: permission)
        case .timeout:
            return .askToContinue
        }
    }
}
```

### 3. Recovery Flows

- **Retry Logic**: Up to 3 attempts with increasing wait times
- **Alternative Input**: Offer text input when voice fails
- **Offline Capabilities**: Basic commands work without internet
- **User Education**: Gentle guidance for better interactions

### 4. Test-Driven Error Scenarios

```swift
// ErrorHandlingTests.swift
class ErrorHandlingTests: XCTestCase {
    
    func testNetworkFailureRecovery() async {
        // Given: Network is unavailable
        networkMock.simulateFailure()
        
        // When: User gives command
        let result = await voiceInterface.processCommand("Turn on lights")
        
        // Then: Should use offline mode
        XCTAssertEqual(result.mode, .offline)
        XCTAssertTrue(result.success)
    }
    
    func testAmbiguousInputClarification() async {
        // Given: Ambiguous input
        let input = "Turn it on" // No context
        
        // When: Process input
        let result = await voiceInterface.processVoiceInput(input)
        
        // Then: Should ask for clarification
        XCTAssertEqual(result.type, .clarificationRequest)
        XCTAssertTrue(result.suggestions.count > 0)
    }
}
```

## Performance Considerations

### 1. Latency Targets
- Wake word detection: < 200ms
- Speech-to-text: < 500ms
- Intent processing: < 100ms
- Response generation: < 300ms
- Total interaction: < 1.5s

### 2. Resource Management
- Audio buffer size: 10 seconds rolling
- Memory footprint: < 50MB active
- Battery optimization: Pause recognition when not needed
- Background processing: Limited to active sessions

## Accessibility Features

### 1. Visual Feedback
- Waveform visualization during speech
- Text display of recognized commands
- Visual indicators for system state

### 2. Haptic Feedback
- Confirmation vibrations
- Error patterns
- State change notifications

### 3. Adjustable Parameters
- Speech recognition sensitivity
- Response speech rate
- Volume normalization
- High contrast mode support

## Security and Privacy

### 1. Local Processing
- On-device speech recognition when possible
- Encrypted communication with backend
- No audio recording without explicit consent

### 2. Data Handling
- Audio data deleted after processing
- Conversation history encrypted at rest
- User control over data retention

### 3. Permission Management
- Microphone access requests
- Clear privacy explanations
- Granular control settings