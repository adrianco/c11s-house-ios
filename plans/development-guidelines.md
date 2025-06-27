# C11S House iOS - Development Guidelines

## Table of Contents
1. [Coding Standards](#coding-standards)
2. [Git Workflow](#git-workflow)
3. [Code Review Process](#code-review-process)
4. [Documentation Requirements](#documentation-requirements)
5. [TDD Practices Checklist](#tdd-practices-checklist)

## Coding Standards

### Swift Style Guide

#### Naming Conventions
- **Types & Protocols**: Use UpperCamelCase
  ```swift
  class VoiceCommandProcessor { }
  protocol HouseDeviceProtocol { }
  struct DeviceStatus { }
  enum CommandType { }
  ```

- **Variables & Functions**: Use lowerCamelCase
  ```swift
  var deviceName: String
  func processVoiceCommand(_ command: String) -> CommandResult
  ```

- **Constants**: Use lowerCamelCase for instance-level, UpperCamelCase for type-level
  ```swift
  let maximumRetryCount = 3
  static let DefaultTimeout = 30.0
  ```

#### Code Organization
```swift
// MARK: - Properties
private let apiClient: APIClient
private var devices: [Device] = []

// MARK: - Lifecycle
init(apiClient: APIClient) {
    self.apiClient = apiClient
}

// MARK: - Public Methods
func connectToDevice(_ device: Device) async throws {
    // Implementation
}

// MARK: - Private Methods
private func validateDevice(_ device: Device) -> Bool {
    // Implementation
}

// MARK: - Extensions
extension VoiceController: DeviceDelegate {
    // Implementation
}
```

#### Best Practices
1. **Prefer `let` over `var`** when possible
2. **Use type inference** where obvious
3. **Avoid force unwrapping** - use guard or if-let
4. **Prefer structs over classes** for value types
5. **Use `async/await`** for asynchronous code
6. **Leverage Swift concurrency** for parallel operations

#### SwiftLint Configuration
```yaml
# .swiftlint.yml
disabled_rules:
  - line_length
  - file_length

opt_in_rules:
  - empty_count
  - closure_spacing
  - contains_over_first_not_nil
  - fatal_error_message
  - first_where
  - implicit_return

excluded:
  - Carthage
  - Pods
  - Generated

line_length:
  warning: 120
  error: 200

type_body_length:
  warning: 300
  error: 500

file_length:
  warning: 500
  error: 1200
```

### Architecture Guidelines

#### MVVM-C Pattern
```swift
// Model
struct Device: Codable {
    let id: String
    let name: String
    let type: DeviceType
    var status: DeviceStatus
}

// ViewModel
class DeviceListViewModel: ObservableObject {
    @Published var devices: [Device] = []
    private let repository: DeviceRepository
    
    func loadDevices() async {
        devices = await repository.fetchDevices()
    }
}

// View
struct DeviceListView: View {
    @StateObject private var viewModel: DeviceListViewModel
    
    var body: some View {
        List(viewModel.devices) { device in
            DeviceRow(device: device)
        }
    }
}

// Coordinator
class MainCoordinator: Coordinator {
    func showDeviceDetail(for device: Device) {
        // Navigation logic
    }
}
```

#### Dependency Injection
```swift
protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

class DeviceService {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
}
```

## Git Workflow

### Branch Naming Convention
- `feature/[ticket-id]-brief-description` - New features
- `bugfix/[ticket-id]-brief-description` - Bug fixes
- `hotfix/[ticket-id]-brief-description` - Production hotfixes
- `chore/[ticket-id]-brief-description` - Maintenance tasks
- `docs/[ticket-id]-brief-description` - Documentation updates

### Commit Message Format
```
[Type] Brief description (max 50 chars)

Detailed explanation of what and why (wrap at 72 chars)
Include ticket reference: Fixes #123

Co-authored-by: Name <email@example.com>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Branch Protection Rules
- `main` branch requires:
  - Pull request reviews (minimum 1)
  - Status checks to pass
  - Up-to-date with base branch
  - No direct pushes

### Workflow Steps
1. **Create Feature Branch**
   ```bash
   git checkout -b feature/CH-123-voice-command-parser
   ```

2. **Make Changes**
   ```bash
   # Write tests first (TDD)
   # Implement feature
   # Run tests locally
   swift test
   ```

3. **Commit Changes**
   ```bash
   git add .
   git commit -m "[feat] Add voice command parser

   Implement natural language processing for voice commands
   - Parse basic home control commands
   - Support multiple languages
   - Add unit tests

   Fixes #CH-123"
   ```

4. **Push and Create PR**
   ```bash
   git push origin feature/CH-123-voice-command-parser
   # Create PR via GitHub/GitLab
   ```

## Code Review Process

### Review Checklist
- [ ] **Tests**: Are there adequate tests? Do they pass?
- [ ] **Documentation**: Is the code well-documented?
- [ ] **Style**: Does it follow our coding standards?
- [ ] **Architecture**: Is it consistent with our patterns?
- [ ] **Performance**: Are there any performance concerns?
- [ ] **Security**: Are there any security vulnerabilities?
- [ ] **Error Handling**: Is error handling comprehensive?
- [ ] **Accessibility**: Are UI changes accessible?

### Review Comments Guidelines
```swift
// 🔴 Bad comment
// This is wrong

// ✅ Good comment
// Consider using `async/await` here instead of completion handlers
// for better readability and error handling. Example:
// func loadData() async throws -> [Device] { ... }
```

### PR Description Template
```markdown
## Summary
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Screenshots (if applicable)
[Add screenshots for UI changes]

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings introduced
```

## Documentation Requirements

### Code Documentation
```swift
/// Processes voice commands and returns appropriate house actions
/// - Parameters:
///   - command: The voice command string to process
///   - context: Optional context for better command interpretation
/// - Returns: A `CommandResult` containing the action to perform
/// - Throws: `VoiceProcessingError` if command cannot be parsed
func processVoiceCommand(
    _ command: String,
    context: CommandContext? = nil
) async throws -> CommandResult {
    // Implementation
}
```

### README Requirements
Each module should have a README with:
1. Purpose and overview
2. Installation/setup instructions
3. Usage examples
4. API documentation
5. Testing instructions
6. Contributing guidelines

### API Documentation
- Use Swift DocC for generating documentation
- Include code examples in documentation
- Document all public APIs
- Explain complex algorithms

### Architecture Decision Records (ADRs)
Document significant decisions using this format:
```markdown
# ADR-001: Use SwiftUI for UI Development

## Status
Accepted

## Context
We need to choose a UI framework for the iOS app.

## Decision
We will use SwiftUI as the primary UI framework.

## Consequences
- Positive: Modern, declarative syntax
- Positive: Better performance
- Negative: Limited to iOS 14+
- Negative: Some UIKit interop needed
```

## TDD Practices Checklist

### Before Writing Code
- [ ] **Understand Requirements**: Clear understanding of feature requirements
- [ ] **Plan Test Cases**: List all test scenarios
- [ ] **Create Test File**: Set up test class/file structure

### Red Phase (Write Failing Tests)
- [ ] **Write Test Method**: Descriptive test method name
- [ ] **Arrange**: Set up test data and dependencies
- [ ] **Act**: Call the method under test
- [ ] **Assert**: Verify expected behavior
- [ ] **Run Test**: Confirm test fails for the right reason

### Green Phase (Make Tests Pass)
- [ ] **Write Minimal Code**: Just enough to pass the test
- [ ] **No Over-Engineering**: Avoid adding untested functionality
- [ ] **Run Tests**: Ensure all tests pass

### Refactor Phase
- [ ] **Improve Code Quality**: Refactor while keeping tests green
- [ ] **Extract Methods**: Break down complex logic
- [ ] **Remove Duplication**: Apply DRY principle
- [ ] **Run Tests Again**: Confirm refactoring didn't break anything

### Test Quality Checklist
- [ ] **Test One Thing**: Each test focuses on single behavior
- [ ] **Independent Tests**: Tests don't depend on each other
- [ ] **Fast Execution**: Tests run quickly (<100ms each)
- [ ] **Descriptive Names**: Test names clearly state what they test
- [ ] **No Test Logic**: Tests contain no conditionals or loops

### Example TDD Flow
```swift
// 1. Write failing test
func testVoiceCommand_TurnOnLights_ReturnsCorrectAction() {
    // Arrange
    let processor = VoiceCommandProcessor()
    
    // Act
    let result = processor.process("Turn on the living room lights")
    
    // Assert
    XCTAssertEqual(result.action, .turnOn)
    XCTAssertEqual(result.device, "living_room_lights")
}

// 2. Write minimal implementation
struct VoiceCommandProcessor {
    func process(_ command: String) -> CommandResult {
        if command.contains("Turn on") && command.contains("lights") {
            return CommandResult(action: .turnOn, device: "living_room_lights")
        }
        return CommandResult(action: .unknown, device: nil)
    }
}

// 3. Refactor
struct VoiceCommandProcessor {
    private let commandParser: CommandParser
    
    func process(_ command: String) -> CommandResult {
        let tokens = commandParser.tokenize(command)
        let action = extractAction(from: tokens)
        let device = extractDevice(from: tokens)
        return CommandResult(action: action, device: device)
    }
}
```

### Coverage Requirements
- **Unit Tests**: Minimum 90% code coverage
- **Integration Tests**: Cover all API endpoints
- **UI Tests**: Cover critical user flows
- **Performance Tests**: Baseline performance metrics

### Test Organization
```
Tests/
├── Unit/
│   ├── Models/
│   ├── ViewModels/
│   ├── Services/
│   └── Utilities/
├── Integration/
│   ├── API/
│   └── Database/
├── UI/
│   └── Flows/
└── Performance/
    └── Benchmarks/
```

## Continuous Integration

### CI Pipeline Steps
1. **Linting**: SwiftLint validation
2. **Build**: Debug and Release configurations
3. **Unit Tests**: Run all unit tests
4. **Integration Tests**: Run API tests
5. **UI Tests**: Run on multiple device sizes
6. **Code Coverage**: Generate coverage reports
7. **Static Analysis**: Run security scans
8. **Documentation**: Generate DocC documentation

### Pre-commit Hooks
```bash
#!/bin/sh
# .git/hooks/pre-commit

# Run SwiftLint
swiftlint

# Run tests
swift test

# Check for large files
find . -type f -size +1M | grep -v ".git"
```

## Performance Guidelines

### Memory Management
- Use `weak` references to avoid retain cycles
- Implement proper cleanup in `deinit`
- Profile memory usage regularly
- Use Instruments for leak detection

### Network Optimization
- Implement proper caching strategies
- Use background queues for heavy operations
- Batch API requests when possible
- Implement proper retry logic with backoff

### UI Performance
- Keep main thread free from heavy operations
- Use lazy loading for large datasets
- Implement efficient diffing algorithms
- Profile using Time Profiler

---

By following these guidelines, we ensure consistent, high-quality code that is maintainable, testable, and performant. Regular reviews and updates to these guidelines help us adapt to new Swift features and best practices.