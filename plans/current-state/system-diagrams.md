# C11S House iOS App - System Diagrams

## Service Architecture Overview

```mermaid
graph TB
    subgraph "App Layer"
        A[C11SHouseApp] --> B[ContentView]
        A --> SC[ServiceContainer]
    end
    
    subgraph "View Layer"
        B --> CV[ConversationView]
        B --> NV[NotesView]
        CV --> HTV[HouseThoughtsView]
        CV --> TV[TranscriptionView]
        CV --> VRB[VoiceRecordingButton]
    end
    
    subgraph "ViewModel Layer"
        CV --> VTM[VoiceTranscriptionViewModel]
        VTM --> SC
    end
    
    subgraph "Service Layer"
        SC --> AS[AudioRecorderService]
        SC --> TS[TranscriptionService]
        SC --> NS[NotesService]
        SC --> TTS[TTSService]
        SC --> PM[PermissionManager]
    end
    
    subgraph "Infrastructure Layer"
        AS --> ASM[AudioSessionManager]
        AS --> AE[AudioEngine]
        TS --> CR[ConversationRecognizer]
        PM --> iOS[iOS Frameworks]
    end
    
    subgraph "Data Layer"
        NS --> UD[UserDefaults]
        AS --> TF[Temporary Files]
        CV --> @S[App Storage]
    end
```

## Data Flow Architecture

```mermaid
sequenceDiagram
    participant U as User
    participant CV as ConversationView
    participant VTM as VoiceTranscriptionViewModel
    participant AS as AudioRecorderService
    participant TS as TranscriptionService
    participant NS as NotesService
    participant TTS as TTSService
    
    U->>CV: Start Recording
    CV->>VTM: startRecording()
    VTM->>AS: startRecording()
    AS->>AS: Record Audio
    
    U->>CV: Stop Recording
    CV->>VTM: stopRecording()
    VTM->>AS: stopRecording()
    AS-->>VTM: Audio Data
    VTM->>TS: transcribe()
    TS-->>VTM: Transcribed Text
    VTM->>NS: saveNote()
    NS->>NS: UserDefaults
    
    VTM->>TTS: speak()
    TTS->>TTS: AVSpeechSynthesizer
    TTS-->>U: Audio Output
```

## Permission Management Flow

```mermaid
flowchart TD
    A[App Launch] --> B[ServiceContainer Init]
    B --> C[PermissionManager.shared]
    C --> D{Check Permissions}
    
    D -->|Not Granted| E[Request Permissions]
    D -->|Granted| F[Ready State]
    
    E --> G[Microphone Permission]
    E --> H[Speech Recognition Permission]
    
    G --> I{Microphone OK?}
    H --> J{Speech OK?}
    
    I -->|Yes| K[Microphone Granted]
    I -->|No| L[Microphone Denied]
    
    J -->|Yes| M[Speech Granted]
    J -->|No| N[Speech Denied]
    
    K --> O{All Permissions?}
    M --> O
    L --> P[Show Permission Error]
    N --> P
    
    O -->|Yes| F
    O -->|No| P
    
    F --> Q[Enable Voice Features]
    P --> R[Disable Voice Features]
```

## Service Dependencies

```mermaid
graph LR
    subgraph "ServiceContainer"
        SC[ServiceContainer.shared]
    end
    
    subgraph "Core Services"
        AS[AudioRecorderService]
        TS[TranscriptionService]
        NS[NotesService]
        TTS[TTSService]
        PM[PermissionManager]
    end
    
    subgraph "ViewModels"
        VTM[VoiceTranscriptionViewModel]
    end
    
    subgraph "Views"
        CV[ConversationView]
        NV[NotesView]
        HTV[HouseThoughtsView]
    end
    
    SC --> AS
    SC --> TS
    SC --> NS
    SC --> TTS
    SC --> PM
    
    SC --> VTM
    VTM --> AS
    VTM --> TS
    VTM --> PM
    
    CV --> VTM
    NV --> NS
    HTV --> TTS
    
    CV --> SC
    NV --> SC
    HTV --> SC
```

## Audio Processing Pipeline

```mermaid
flowchart LR
    subgraph "Input"
        M[Microphone]
    end
    
    subgraph "Recording"
        AS[AVAudioSession]
        AE[AVAudioEngine]
        IN[InputNode]
        T[Tap]
    end
    
    subgraph "Processing"
        B[Audio Buffer]
        L[Level Calculation]
        F[File Writer]
    end
    
    subgraph "Output"
        TF[Temporary File]
        AL[Audio Levels]
    end
    
    M --> AS
    AS --> AE
    AE --> IN
    IN --> T
    T --> B
    B --> L
    B --> F
    L --> AL
    F --> TF
```

## Notes Data Model

```mermaid
classDiagram
    class NotesStoreData {
        +questions: [Question]
        +notes: [UUID: Note]
        +version: Int
        +sortedQuestions: [Question]
        +completionPercentage: Double
        +isAnswered(question): Bool
    }
    
    class Question {
        +id: UUID
        +text: String
        +category: QuestionCategory
        +displayOrder: Int
        +isRequired: Bool
        +hint: String?
        +createdAt: Date
    }
    
    class Note {
        +questionId: UUID
        +answer: String
        +createdAt: Date
        +lastModified: Date
        +metadata: [String: String]?
        +isAnswered: Bool
        +updateAnswer(newAnswer)
        +setMetadata(key, value)
    }
    
    class QuestionCategory {
        <<enumeration>>
        personal
        houseInfo
        maintenance
        preferences
        reminders
        other
    }
    
    NotesStoreData --> Question
    NotesStoreData --> Note
    Question --> QuestionCategory
    Note --> Question : questionId
```

## State Management

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Ready : Permissions Granted
    Ready --> Preparing : Start Recording
    Preparing --> Recording : Audio Engine Started
    Recording --> Processing : Stop Recording
    Processing --> Transcribed : Success
    Processing --> Error : Failure
    Transcribed --> Ready : Reset
    Error --> Ready : Retry
    Recording --> Cancelled : Cancel
    Cancelled --> Ready : Reset
    
    note right of Recording
        Timer updates duration
        Audio level monitoring
        Silence detection
    end note
    
    note right of Processing
        Audio data processing
        Speech recognition
        Result parsing
    end note
```

## Voice Service Integration

```mermaid
graph TD
    subgraph "iOS Frameworks"
        AVF[AVFoundation]
        SF[Speech Framework]
        UIK[UIKit]
    end
    
    subgraph "Voice Services"
        ARS[AudioRecorderService]
        TS[TranscriptionService]
        TTS[TTSService]
        PM[PermissionManager]
    end
    
    subgraph "Components"
        AE[AVAudioEngine]
        ASS[AVAudioSession]
        SR[SFSpeechRecognizer]
        SS[AVSpeechSynthesizer]
        AV[AVAudioSession]
    end
    
    AVF --> ARS
    AVF --> TTS
    SF --> TS
    UIK --> PM
    
    ARS --> AE
    ARS --> ASS
    TS --> SR
    TTS --> SS
    PM --> AV
```

## Error Handling Flow

```mermaid
flowchart TD
    A[Service Call] --> B{Try Operation}
    B -->|Success| C[Return Result]
    B -->|Error| D[Catch Error]
    
    D --> E{Error Type}
    E -->|Permission| F[PermissionManager]
    E -->|Network| G[Network Error]
    E -->|Audio| H[Audio Error]
    E -->|Transcription| I[Transcription Error]
    
    F --> J[Request Permission]
    G --> K[Retry Logic]
    H --> L[Reset Audio]
    I --> M[Show Error]
    
    J --> N{Permission Granted?}
    N -->|Yes| O[Retry Operation]
    N -->|No| P[Show Settings]
    
    K --> Q{Retry Count}
    Q -->|< Max| O
    Q -->|>= Max| M
    
    L --> O
    M --> R[User Action Required]
    O --> B
    P --> S[Open Settings]
```

## Component Lifecycle

```mermaid
sequenceDiagram
    participant A as App
    participant SC as ServiceContainer
    participant PM as PermissionManager
    participant AS as AudioRecorderService
    participant VM as ViewModel
    participant V as View
    
    A->>SC: Initialize (singleton)
    SC->>PM: Get shared instance
    SC->>AS: Lazy initialization
    A->>V: Create ContentView
    V->>VM: @StateObject init
    VM->>SC: Factory method
    SC->>AS: Inject dependencies
    SC->>PM: Inject dependencies
    VM->>AS: Setup bindings
    V->>VM: Bind to @Published
    
    note over A,V: App is ready for user interaction
```

## Testing Architecture

```mermaid
graph TB
    subgraph "Production Code"
        SC[ServiceContainer]
        AS[AudioRecorderService]
        TS[TranscriptionService]
        NS[NotesService]
        VM[ViewModel]
    end
    
    subgraph "Test Code"
        TSC[TestServiceContainer]
        MAS[MockAudioRecorderService]
        MTS[MockTranscriptionService]
        MNS[MockNotesService]
        VMT[ViewModelTests]
    end
    
    subgraph "Protocols"
        ASP[AudioRecorderService]
        TSP[TranscriptionService]
        NSP[NotesService]
    end
    
    AS -.->|implements| ASP
    TS -.->|implements| TSP
    NS -.->|implements| NSP
    
    MAS -.->|implements| ASP
    MTS -.->|implements| TSP
    MNS -.->|implements| NSP
    
    SC --> AS
    SC --> TS
    SC --> NS
    
    TSC --> MAS
    TSC --> MTS
    TSC --> MNS
    
    VM --> SC
    VMT --> TSC
```

These diagrams provide a comprehensive view of the actual implemented architecture, showing the real relationships between components, data flow, and system interactions in the C11S House iOS app.