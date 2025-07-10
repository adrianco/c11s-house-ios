# C11S House iOS - Plans & Documentation

This directory contains all planning documents, design specifications, and architectural documentation for the C11S House iOS application.

## Directory Structure

```
plans/
├── archive/              # Historical documentation
│   ├── api-integration.md
│   ├── apple-intelligence.md
│   ├── architecture-comparison.md
│   ├── data-models.md
│   ├── developer-reference.md
│   ├── implementation-roadmap.md
│   ├── system-diagrams.md
│   ├── tdd-strategy.md
│   ├── test-infrastructure.md
│   ├── test-scenarios.md
│   ├── voice-interface.md
│   ├── THREADING_QUICK_REFERENCE.md
│   ├── THREADING_VERIFICATION_GUIDE.md
│   ├── threading-verification-report.md
│   ├── XCODE_CLOUD_SETUP.md
│   └── XCODE_PROJECT_SETUP.md
├── current-state/        # Current implementation status
│   ├── architecture.md
│   ├── implemented-features.md
│   └── technical-stack.md
├── development/          # Development guidelines
│   ├── deployment.md
│   ├── guidelines.md
│   └── testing-strategy.md
├── implementation/       # Feature implementation plans
│   ├── location-services.md
│   ├── location-weather-summary.md
│   ├── smart-home-integration.md
│   └── voice-enhancements.md
├── onboarding/          # Onboarding experience documentation
│   ├── OnboardingUXPlan.md
│   └── OnboardingImplementationGuide.md
├── refactoring-plan-2025-01-09.md
└── README.md
```

## Key Documents

### Active Plans

- **[Onboarding UX Plan](onboarding/OnboardingUXPlan.md)** - Complete user experience design for app onboarding
- **[Onboarding Implementation Guide](onboarding/OnboardingImplementationGuide.md)** - Developer guide for implementing onboarding
- **[Current Architecture](current-state/architecture.md)** - System architecture overview
- **[Refactoring Plan](refactoring-plan-2025-01-09.md)** - Latest refactoring initiative

### Development Resources

- **[Development Guidelines](development/guidelines.md)** - Coding standards and practices
- **[Testing Strategy](development/testing-strategy.md)** - Test approach and methodology
- **[Deployment Guide](development/deployment.md)** - Release and deployment procedures

### Feature Plans

- **[Location Services](implementation/location-services.md)** - Location and weather integration
- **[Voice Enhancements](implementation/voice-enhancements.md)** - Voice interface improvements
- **[Smart Home Integration](implementation/smart-home-integration.md)** - Future IoT integration

### Archived Documentation

The `archive/` directory contains historical documentation that may be useful for reference but is no longer actively maintained. This includes:
- Original design documents
- Threading and concurrency guides
- Xcode setup instructions
- Early architectural proposals

## Contributing

When adding new plans or documentation:
1. Place active documents in the appropriate subdirectory
2. Move outdated docs to `archive/`
3. Update this README with new entries
4. Keep documents focused and well-organized
5. Use clear, descriptive filenames

## Navigation

- **For developers**: Start with `development/guidelines.md`
- **For new features**: Check `implementation/` directory
- **For app setup**: See `current-state/` directory
- **For testing**: Refer to `/tests/` directory