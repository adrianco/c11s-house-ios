# C11S House iOS - Developer Reference

## Quick Start for Developers

This document provides a comprehensive reference for developers working on the C11S House iOS app, including architecture patterns, service usage, and common development tasks.

## Architecture Overview

The app uses a **ServiceContainer + MVVM** pattern with SwiftUI, providing a clean and maintainable architecture while keeping complexity manageable.

### Key Components

1. **ServiceContainer**: Singleton dependency injection container
2. **Services**: Protocol-based services for core functionality
3. **ViewModels**: `@MainActor` classes with `@Published` properties
4. **Views**: SwiftUI views with environment object injection
5. **Models**: Codable data structures for persistence

## Core Services

### 1. AudioRecorderService

**Purpose**: Handles audio recording with real-time level monitoring.

**Usage**:
```swift
// Get from service container
let audioRecorder = ServiceContainer.shared.audioRecorder

// Start recording
try await audioRecorder.startRecording(configuration: config)

// Monitor audio levels
audioRecorder.audioLevelPublisher
    .sink { level in
        // Update UI with audio level
    }
    .store(in: &cancellables)

// Stop recording
let audioData = try await audioRecorder.stopRecording()
```

**Key Features**:
- Real-time audio level monitoring
- AVAudioEngine-based implementation
- Automatic cleanup of resources
- Combine publishers for reactive UI updates

### 2. TranscriptionService

**Purpose**: Converts audio data to text using Apple's Speech framework.

**Usage**:
```swift
let transcriptionService = ServiceContainer.shared.transcriptionService

let result = try await transcriptionService.transcribe(
    audioData: audioData,
    configuration: config
)

print("Transcribed text: \(result.text)")
print("Confidence: \(result.confidence)")
```

**Key Features**:
- Server-based and on-device transcription
- Confidence scores and alternatives
- Automatic language detection
- Error handling for edge cases

### 3. NotesService

**Purpose**: Manages house-related Q&A notes with persistence.

**Usage**:
```swift
let notesService = ServiceContainer.shared.notesService

// Load all notes
let store = try await notesService.loadNotesStore()

// Save a note
let note = Note(questionId: questionId, answer: "My answer")
try await notesService.saveNote(note)

// Monitor changes
notesService.notesStorePublisher
    .sink { updatedStore in
        // Update UI
    }
    .store(in: &cancellables)
```

**Key Features**:
- UserDefaults-based persistence
- Reactive updates via Combine
- Predefined questions system
- Version management for migrations

### 4. TTSService

**Purpose**: Converts text to speech with customizable parameters.

**Usage**:
```swift
let ttsService = ServiceContainer.shared.ttsService

// Speak text
try await ttsService.speak("Hello, welcome home!", language: "en-US")

// Monitor speaking state
ttsService.isSpeakingPublisher
    .sink { isSpeaking in
        // Update UI
    }
    .store(in: &cancellables)

// Control playback
ttsService.setRate(0.5)
ttsService.setPitch(1.2)
ttsService.stopSpeaking()
```

**Key Features**:
- AVSpeechSynthesizer integration
- Configurable speech parameters
- Progress monitoring
- Interruption handling

### 5. PermissionManager

**Purpose**: Centralized permission handling for microphone and speech recognition.

**Usage**:
```swift
let permissionManager = ServiceContainer.shared.permissionManager

// Request all permissions
await permissionManager.requestAllPermissions()

// Check specific permissions
if permissionManager.isMicrophoneGranted {
    // Enable voice features
}

// Monitor permission changes
permissionManager.$allPermissionsGranted
    .sink { granted in
        // Update UI state
    }
    .store(in: &cancellables)
```

**Key Features**:
- Automatic permission checking
- Reactive permission state
- Settings app integration
- Graceful error handling

## Data Models

### NotesStore Data Models

```swift
// Question for house-related information
struct Question: Codable, Identifiable {
    let id: UUID
    let text: String
    let category: QuestionCategory
    let displayOrder: Int
    let isRequired: Bool
    let hint: String?
    let createdAt: Date
}

// Answer/note for a question
struct Note: Codable {
    let questionId: UUID
    var answer: String
    let createdAt: Date
    var lastModified: Date
    var metadata: [String: String]?
    
    var isAnswered: Bool {
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// Container for all Q&A data
struct NotesStoreData: Codable {
    var questions: [Question]
    var notes: [UUID: Note]
    let version: Int
    
    var completionPercentage: Double {
        guard !questions.isEmpty else { return 0 }
        let answeredCount = questions.filter { isAnswered($0) }.count
        return Double(answeredCount) / Double(questions.count) * 100
    }
}
```

### Voice Models

```swift
// Audio level information
struct AudioLevel {
    let powerLevel: Float    // Current power in dB
    let peakLevel: Float     // Peak level in dB
    let averageLevel: Float  // Smoothed average level
    
    static let silent = AudioLevel(powerLevel: -160, peakLevel: -160, averageLevel: -160)
}

// Transcription result
struct TranscriptionResult {
    let text: String
    let confidence: Float
    let alternatives: [String]
    let segments: [TranscriptionSegment]
    let duration: TimeInterval
}

// House consciousness thoughts
struct HouseThought {
    let thought: String
    let emotion: EmotionType
    let category: ThoughtCategory
    let confidence: Float
    let context: String?
    let suggestion: String?
}
```

## ViewModel Patterns

### Standard ViewModel Structure

```swift
@MainActor
class MyViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var state: MyState = .idle
    @Published private(set) var data: MyData = MyData()
    @Published private(set) var error: String?
    
    // MARK: - Private Properties
    private let service: MyService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(service: MyService) {
        self.service = service
        setupBindings()
    }
    
    // MARK: - Public Methods
    func performAction() {
        Task {
            await handleAction()
        }
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        service.dataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newData in
                self?.data = newData
            }
            .store(in: &cancellables)
    }
    
    private func handleAction() async {
        do {
            state = .loading
            let result = try await service.performOperation()
            state = .success(result)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

### Service Container Integration

```swift
extension ServiceContainer {
    /// Factory method for creating ViewModels with dependencies
    @MainActor
    func makeMyViewModel() -> MyViewModel {
        return MyViewModel(
            service: myService,
            otherService: otherService
        )
    }
}
```

## SwiftUI View Patterns

### Service Container Injection

```swift
struct MyView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @StateObject private var viewModel: MyViewModel
    
    init() {
        // Initialize with temporary ViewModel
        _viewModel = StateObject(wrappedValue: MyViewModel(service: MockService()))
    }
    
    var body: some View {
        VStack {
            // View content
        }
        .onAppear {
            // Replace with real ViewModel
            viewModel = serviceContainer.makeMyViewModel()
        }
    }
}
```

### Reactive State Updates

```swift
struct MyView: View {
    @StateObject private var viewModel: MyViewModel
    
    var body: some View {
        VStack {
            switch viewModel.state {
            case .idle:
                IdleView()
            case .loading:
                ProgressView()
            case .success(let data):
                DataView(data: data)
            case .error(let message):
                ErrorView(message: message)
            }
        }
        .onReceive(viewModel.$state) { newState in
            // React to state changes
        }
    }
}
```

## Common Development Tasks

### Adding a New Service

1. **Create Protocol**:
```swift
protocol MyNewService {
    func performOperation() async throws -> Result
    var statePublisher: AnyPublisher<State, Never> { get }
}
```

2. **Implement Service**:
```swift
class MyNewServiceImpl: MyNewService {
    func performOperation() async throws -> Result {
        // Implementation
    }
    
    var statePublisher: AnyPublisher<State, Never> {
        stateSubject.eraseToAnyPublisher()
    }
}
```

3. **Add to ServiceContainer**:
```swift
extension ServiceContainer {
    private(set) lazy var myNewService: MyNewService = {
        MyNewServiceImpl()
    }()
}
```

### Creating a New View

1. **Create ViewModel**:
```swift
@MainActor
class MyNewViewModel: ObservableObject {
    @Published private(set) var state: MyState = .idle
    
    private let service: MyNewService
    
    init(service: MyNewService) {
        self.service = service
    }
    
    func performAction() {
        Task {
            // Implementation
        }
    }
}
```

2. **Create View**:
```swift
struct MyNewView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @StateObject private var viewModel: MyNewViewModel
    
    var body: some View {
        VStack {
            // View implementation
        }
        .onAppear {
            viewModel = serviceContainer.makeMyNewViewModel()
        }
    }
}
```

3. **Add Factory Method**:
```swift
extension ServiceContainer {
    @MainActor
    func makeMyNewViewModel() -> MyNewViewModel {
        return MyNewViewModel(service: myNewService)
    }
}
```

### Adding Navigation

```swift
struct ParentView: View {
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: MyNewView()) {
                    Text("Go to New View")
                }
            }
        }
    }
}
```

## Testing Patterns

### Service Testing

```swift
class MyServiceTests: XCTestCase {
    var service: MyNewServiceImpl!
    var mockDependency: MockDependency!
    
    override func setUp() {
        mockDependency = MockDependency()
        service = MyNewServiceImpl(dependency: mockDependency)
    }
    
    func testPerformOperation() async throws {
        // Given
        mockDependency.expectedResult = .success
        
        // When
        let result = try await service.performOperation()
        
        // Then
        XCTAssertEqual(result, .success)
    }
}
```

### ViewModel Testing

```swift
@MainActor
class MyViewModelTests: XCTestCase {
    var viewModel: MyNewViewModel!
    var mockService: MockMyNewService!
    
    override func setUp() {
        mockService = MockMyNewService()
        viewModel = MyNewViewModel(service: mockService)
    }
    
    func testPerformAction() async {
        // Given
        mockService.shouldSucceed = true
        
        // When
        viewModel.performAction()
        
        // Then
        await fulfillment(of: [
            viewModel.state == .success
        ])
    }
}
```

### Mock Services

```swift
class MockMyNewService: MyNewService {
    var shouldSucceed = true
    var expectedResult: Result = .success
    
    func performOperation() async throws -> Result {
        if shouldSucceed {
            return expectedResult
        } else {
            throw TestError.failed
        }
    }
    
    var statePublisher: AnyPublisher<State, Never> {
        Just(.idle).eraseToAnyPublisher()
    }
}
```

## Best Practices

### 1. Service Design

- Keep services focused on single responsibilities
- Use protocols for all service interfaces
- Implement reactive publishers for state changes
- Handle errors gracefully with typed error enums
- Use async/await for asynchronous operations

### 2. ViewModel Design

- Mark as `@MainActor` for UI updates
- Use `@Published` for reactive properties
- Keep business logic in services, not ViewModels
- Use `Task` for async operations from sync contexts
- Implement proper cleanup in `deinit`

### 3. View Design

- Use `@EnvironmentObject` for service container access
- Implement proper loading and error states
- Keep views focused on presentation logic
- Use `onAppear` for initialization tasks
- Prefer composition over inheritance

### 4. Data Management

- Use Codable for persistence models
- Implement proper versioning for data migrations
- Keep data models simple and focused
- Use computed properties for derived data
- Handle optional data gracefully

### 5. Error Handling

- Use typed errors for better debugging
- Implement user-friendly error messages
- Provide recovery mechanisms where possible
- Log errors for debugging purposes
- Use Result types for complex operations

## Performance Considerations

### 1. Memory Management

- Use `weak` references in closures
- Implement proper cancellation for async operations
- Clean up resources in `deinit`
- Use lazy initialization for expensive operations

### 2. Threading

- Keep UI updates on main thread
- Use `@MainActor` for ViewModels
- Implement proper queue management for services
- Use `Task` for concurrent operations

### 3. Data Efficiency

- Implement lazy loading for large datasets
- Use efficient data structures
- Minimize unnecessary updates
- Cache expensive computations

This reference should help developers understand the architecture and follow consistent patterns when adding new features to the C11S House iOS app.