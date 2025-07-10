# C11S House iOS - Test Suite

This directory contains all test-related files for the C11S House iOS application.

## Directory Structure

```
tests/
├── scripts/              # Test runner scripts
│   ├── run-onboarding-tests.sh
│   ├── run-notes-service-tests.sh
│   └── run-threading-tests.sh
├── test_coverage_summary.md
└── README.md
```

## Test Files Location

The actual test source files are located within the Xcode project structure:

- **Unit Tests**: `C11Shouse/C11SHouseTests/`
- **UI Tests**: `C11Shouse/C11SHouseUITests/`

## Running Tests

### Quick Start

```bash
# Run all onboarding tests
./tests/scripts/run-onboarding-tests.sh

# Run notes service tests
./tests/scripts/run-notes-service-tests.sh

# Run threading verification tests
./tests/scripts/run-threading-tests.sh
```

### Using Xcode

1. Open `C11Shouse/C11SHouse.xcodeproj`
2. Select the test scheme
3. Press `Cmd+U` to run all tests

### Test Categories

- **Unit Tests**: Fast, isolated component tests
- **Integration Tests**: Tests of component interactions
- **UI Tests**: End-to-end user flow validation
- **Performance Tests**: Metrics and benchmarks

## Coverage Reports

See `test_coverage_summary.md` for the latest coverage metrics.

## Contributing

When adding new tests:
1. Place test scripts in `tests/scripts/`
2. Update relevant documentation
3. Ensure tests pass before committing
4. Update coverage reports as needed