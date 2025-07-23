# C11S House iOS - Documentation Index

Quick reference guide to all documentation in the project.

## 📚 Primary Documentation

### Getting Started
- [README.md](README.md) - Project overview and setup instructions
- [CLAUDE.md](CLAUDE.md) - AI assistant context and instructions
- [Quick Start Guide](plans/development/guidelines.md) - Development setup

### Architecture & Design
- [System Architecture](plans/current-state/architecture.md) - High-level system design
- [Technical Stack](plans/current-state/technical-stack.md) - Technologies and frameworks
- [Implemented Features](plans/current-state/implemented-features.md) - Current functionality

### User Interface
- [Onboarding UX Plan](plans/user-interface/OnboardingUXPlan.md) - User experience design
- [Onboarding Implementation Guide](plans/user-interface/OnboardingImplementationGuide.md) - Developer guide

### Feature Plans
- [HomeKit Integration](plans/homekit.md) 🆕 - Smart home integration plan
- [Location Services](plans/implementation/location-services.md) - Weather and location features
- [Voice Enhancements](plans/implementation/voice-enhancements.md) - Voice interface improvements
- [Smart Home Integration](plans/implementation/smart-home-integration.md) - Future IoT plans

### Development
- [Development Guidelines](plans/development/guidelines.md) - Coding standards
- [Testing Strategy](plans/development/testing-strategy.md) - Test approach
- [Deployment Guide](plans/development/deployment.md) - Release procedures
- [State Management](plans/implementation/state-management-patterns.md) - App state patterns

## 🗂️ Documentation Organization

### Active Documentation
- `/README.md` - Main project readme
- `/CLAUDE.md` - AI assistant instructions
- `/plans/` - All planning and design documents
  - `current-state/` - Current implementation status
  - `development/` - Development guidelines
  - `implementation/` - Feature implementation plans
  - `user-interface/` - UI/UX documentation
  - `homekit.md` - HomeKit integration plan

### Code Documentation
- In-line documentation in Swift files
- Header comments with context and decision history
- Test files with descriptive test names

### Archived Documentation
- `/plans/archive/` - Historical documents
  - `implementation-history/` - Past implementations
  - `test-reports/` - Historical test results
  - Legacy planning documents

## 🔍 Finding Information

### By Topic:
- **Architecture**: Start with [System Architecture](plans/current-state/architecture.md)
- **Features**: Check [Implemented Features](plans/current-state/implemented-features.md)
- **UI/UX**: See [Onboarding UX Plan](plans/user-interface/OnboardingUXPlan.md)
- **Testing**: Review [Testing Strategy](plans/development/testing-strategy.md)
- **Deployment**: Read [Deployment Guide](plans/development/deployment.md)

### By File Type:
- **Planning docs**: `/plans/`
- **Test scripts**: `/tests/scripts/`
- **Claude commands**: `/.claude/commands/`
- **Source code**: `/C11Shouse/C11SHouse/`

## 📝 Documentation Maintenance

### Adding New Documentation
1. Place in appropriate directory under `/plans/`
2. Use descriptive filename with `.md` extension
3. Add link to this index
4. Update relevant README files

### Archiving Old Documentation
1. Move to `/plans/archive/` with appropriate subdirectory
2. Remove from active documentation indexes
3. Keep for historical reference

## 🚀 Quick Links

- [Project README](README.md)
- [Plans Directory](plans/README.md)
- [Test Scripts](tests/README.md)
- [HomeKit Plan](plans/homekit.md) - Latest feature plan

---
*Last updated: 2025-07-23*