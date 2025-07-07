# C11S House iOS - Planning Documentation

## Overview

This directory contains all planning and documentation for the C11S House iOS application - a native Swift application that provides voice-driven interaction with a house consciousness system using Apple Intelligence features.

### Project Vision
Build an intuitive, voice-first iOS application that allows users to interact naturally with their smart home consciousness system, leveraging the latest Apple technologies while maintaining privacy and security.

## Document Navigation

### Core Planning Documents

1. **[Implementation Roadmap](./implementation-roadmap.md)**
   - Comprehensive 14-week development plan
   - Phase-by-phase breakdown with milestones
   - Risk assessment and mitigation strategies
   - Team structure and success metrics

2. **[Development Guidelines](./development-guidelines.md)**
   - Coding standards and conventions
   - Git workflow and branching strategy
   - Code review process
   - TDD practices and requirements

3. **[Current Architecture Documentation](./current-state/architecture.md)**
   - Actual implemented architecture (ServiceContainer + MVVM)
   - System architecture overview with real component relationships
   - Data flow diagrams based on implementation
   - Service layer design and integration points

4. **[Architecture Analysis](./current-state/)**
   - **[System Diagrams](./current-state/system-diagrams.md)**: Visual representation of actual architecture
   - **[Architecture Comparison](./current-state/architecture-comparison.md)**: Planned vs actual implementation
   - **[Developer Reference](./current-state/developer-reference.md)**: Comprehensive guide for developers

## Quick Start Guide for Developers

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9+
- iOS 17.0+ deployment target
- Apple Developer account

### Initial Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-org/c11s-house-ios.git
   cd c11s-house-ios
   ```

2. **Install Dependencies**
   ```bash
   # Install SwiftLint for code quality
   brew install swiftlint
   
   # Install Ruby gems for Fastlane
   bundle install
   ```

3. **Configure Development Environment**
   ```bash
   # Copy environment template
   cp .env.example .env
   
   # Add your API keys and configuration
   # Edit .env with your credentials
   ```

4. **Open in Xcode**
   ```bash
   open C11SHouse.xcworkspace
   ```

5. **Run Tests**
   - Press ⌘+U in Xcode to run all unit tests
   - Ensure all tests pass before making changes

### Development Workflow

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Write Tests First (TDD)**
   - Create test cases for your feature
   - Run tests to see them fail
   - Implement feature to make tests pass

3. **Submit Pull Request**
   - Ensure all tests pass
   - Update documentation if needed
   - Request code review from team

## Key Decisions Summary

### Technology Stack (Actual Implementation)
- **Language**: Swift 5.9+ (no Objective-C)
- **UI Framework**: SwiftUI (primary), UIKit (where necessary)
- **Architecture**: ServiceContainer + MVVM (simplified from planned MVVM-C)
- **Dependency Injection**: ServiceContainer singleton with protocol-based services
- **Audio Processing**: AVFoundation (AVAudioEngine, AVSpeechSynthesizer)
- **Speech Services**: Apple Speech framework for transcription
- **Local Storage**: UserDefaults (for Q&A notes), temporary files (for audio)
- **Testing**: XCTest with protocol-based mocking

### Design Principles
1. **Voice-First**: Every feature must be accessible via voice
2. **Privacy-Focused**: Minimize data collection, maximize on-device processing
3. **Offline-Capable**: Core functions work without internet
4. **Accessible**: Full VoiceOver and accessibility support
5. **Testable**: Minimum 90% code coverage

### Integration Points (Current Implementation)
- **Apple Speech Framework**: Server-based and on-device speech recognition
- **AVFoundation**: Audio recording, playback, and session management
- **SwiftUI + Combine**: Reactive UI updates and state management
- **UserDefaults**: Local persistence for notes and settings
- **iOS Permissions**: Microphone and speech recognition permissions

### Security Requirements
- All API communications over HTTPS
- Certificate pinning for backend connections
- Biometric authentication for sensitive operations
- Encrypted local storage for user data
- No third-party tracking SDKs

## Next Steps

### For Developers
1. Review the [Development Guidelines](./development-guidelines.md)
2. Set up your development environment
3. Join the team Slack channel: #c11s-house-ios
4. Pick up a starter task from the backlog

### For Project Managers
1. Review the [Implementation Roadmap](./implementation-roadmap.md)
2. Schedule team kickoff meeting
3. Set up project tracking in Jira
4. Establish communication channels

### For Designers
1. Access design files in Figma
2. Review Apple Human Interface Guidelines
3. Coordinate with development team on component library
4. Plan user research sessions

### For QA Engineers
1. Set up test automation framework
2. Create test plan based on requirements
3. Configure device testing lab
4. Establish bug tracking workflow

## Resources

### Internal Documentation
- [API Documentation](https://github.com/adrianco/consciousness)
- [Design System](./design-system.md) (Coming Soon)
- [Testing Strategy](./testing-strategy.md) (Coming Soon)

### External Resources
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Swift Style Guide](https://github.com/raywenderlich/swift-style-guide)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Contributing

Please read our [Development Guidelines](./development-guidelines.md) before contributing. All code must:
- Follow our coding standards
- Include comprehensive tests
- Pass CI/CD checks
- Be reviewed by at least one team member

## Questions?

- **Technical Questions**: Post in #c11s-house-ios-dev
- **Project Questions**: Contact the Technical Lead
- **Design Questions**: Reach out to the UX team
- **General Inquiries**: Email: c11s-house-ios@example.com

---

## Project Status

**Current Phase**: Implementation Complete (MVP)
- Core voice transcription functionality implemented
- Q&A notes system operational
- ServiceContainer architecture in place
- Basic testing infrastructure established

**Next Steps**: Feature expansion and UI/UX improvements based on user feedback.

---

Last Updated: 2025-07-07 (Architecture documentation updated to reflect actual implementation)