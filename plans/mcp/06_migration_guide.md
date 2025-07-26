# HomeGraph MCP Migration Guide

## Overview

This guide provides detailed instructions for migrating from the existing NotesService to the new HomeGraph MCP server. The migration is designed to be safe, incremental, and reversible.

## Migration Principles

1. **Zero Data Loss**: All existing data preserved
2. **No Downtime**: System remains functional throughout
3. **Gradual Transition**: Incremental rollout with monitoring
4. **Easy Rollback**: Can revert at any stage
5. **User Transparent**: No visible changes initially

## Pre-Migration Checklist

### System Requirements
- [ ] iOS 17.0+ deployment target confirmed
- [ ] SQLite available (built-in)
- [ ] Sufficient storage space (2x current Notes data)
- [ ] Backup system operational
- [ ] Error reporting configured

### Code Preparation
- [ ] Feature flags implemented
- [ ] Monitoring system ready
- [ ] Rollback procedures tested
- [ ] Team briefed on process

## Migration Architecture

### Dual-System Operation

```swift
// During migration, both systems operate in parallel
class MigrationCoordinator {
    private let notesService: NotesServiceProtocol
    private let homeGraphMCP: HomeGraphMCPServiceProtocol
    private let featureFlags: FeatureFlags
    
    func getNote(for questionId: String) async throws -> String? {
        if featureFlags.isEnabled(.useHomeGraphMCP) {
            // Try new system first
            do {
                return try await homeGraphMCP.getNote(for: questionId)
            } catch {
                // Fallback to old system
                logger.error("MCP failed, falling back: \(error)")
                return try await notesService.getNote(for: questionId)
            }
        } else {
            // Use old system
            return try await notesService.getNote(for: questionId)
        }
    }
}
```

### Data Sync Strategy

```swift
class DataSyncService {
    enum SyncDirection {
        case notesToGraph  // Initial migration
        case bidirectional // During parallel operation
        case graphToNotes  // Rollback scenario
    }
    
    func syncData(direction: SyncDirection) async throws {
        switch direction {
        case .notesToGraph:
            try await migrateNotesToGraph()
        case .bidirectional:
            try await syncBidirectional()
        case .graphToNotes:
            try await rollbackToNotes()
        }
    }
}
```

## Step-by-Step Migration Process

### Step 1: Deploy Infrastructure (Day 1)

#### 1.1 Add HomeGraph Components
```bash
# Add new files without removing old ones
Services/HomeGraph/
├── HomeGraphStorage.swift
├── HomeGraphModels.swift
├── HomeKitGraphBridge.swift
└── HomeGraph.swift

Services/MCP/
├── HomeGraphMCPService.swift
├── MCPResourceHandlers.swift
└── MCPToolHandlers.swift
```

#### 1.2 Initialize Database
```swift
// AppDelegate or SceneDelegate
func initializeHomeGraph() async {
    do {
        let dbURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HomeGraph.db")
        
        let storage = try HomeGraphStorage(databaseURL: dbURL)
        let graph = HomeGraph(storage: storage)
        
        ServiceContainer.shared.register(storage: storage)
        ServiceContainer.shared.register(graph: graph)
        
        logger.info("HomeGraph initialized successfully")
    } catch {
        logger.error("Failed to initialize HomeGraph: \(error)")
        // Continue with NotesService only
    }
}
```

### Step 2: Initial Data Migration (Day 2-3)

#### 2.1 Run Migration Script
```swift
class InitialMigration {
    func perform() async throws {
        logger.info("Starting initial migration")
        
        // 1. Load existing notes
        let notes = try await NotesService.shared.getAllNotes()
        let questions = try await NotesService.shared.getAllQuestions()
        
        // 2. Convert to entities
        var entities: [HomeEntity] = []
        
        for question in questions {
            let entity = convertQuestionToEntity(question)
            entities.append(entity)
        }
        
        for note in notes {
            let entity = convertNoteToEntity(note)
            entities.append(entity)
        }
        
        // 3. Store in HomeGraph
        let storage = ServiceContainer.shared.homeGraphStorage
        for entity in entities {
            try await storage.store(entity: entity)
        }
        
        // 4. Verify migration
        let count = try await storage.countEntities()
        logger.info("Migrated \(count) entities successfully")
        
        // 5. Set migration flag
        UserDefaults.standard.set(true, forKey: "homeGraphMigrationComplete")
    }
}
```

#### 2.2 Verify Data Integrity
```swift
class MigrationVerifier {
    func verify() async throws -> VerificationReport {
        var report = VerificationReport()
        
        // Compare counts
        let notesCount = try await NotesService.shared.getAllNotes().count
        let entitiesCount = try await homeGraphStorage.countEntities(ofType: .note)
        report.countMatch = (notesCount == entitiesCount)
        
        // Sample content verification
        let sampleNotes = try await NotesService.shared.getAllNotes().prefix(10)
        for note in sampleNotes {
            let entity = try await homeGraphStorage.fetchEntity(id: note.id)
            report.contentMatches.append(
                verifyContent(note: note, entity: entity)
            )
        }
        
        return report
    }
}
```

### Step 3: Enable Read Path (Day 4-5)

#### 3.1 Update Service Container
```swift
extension ServiceContainer {
    var notesProvider: NotesProviding {
        if FeatureFlags.shared.isEnabled(.useHomeGraphMCP) {
            return homeGraphMCP
        } else {
            return notesService
        }
    }
}
```

#### 3.2 Add Compatibility Layer
```swift
// Make HomeGraphMCP conform to existing protocols
extension HomeGraphMCPService: NotesServiceProtocol {
    func getNote(for questionId: String) async throws -> String? {
        let request = MCPToolRequest(
            method: "get_answer",
            params: ["questionId": questionId]
        )
        let response = try await handleToolCall(request)
        return response.content.first?.text
    }
    
    func saveNote(_ answer: String, for questionId: String) async throws {
        // Write to both systems during migration
        if FeatureFlags.shared.isEnabled(.dualWrite) {
            try await notesService.saveNote(answer, for: questionId)
        }
        
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

### Step 4: Enable Write Path (Day 6-7)

#### 4.1 Dual-Write Configuration
```swift
class DualWriteCoordinator {
    func saveNote(_ answer: String, for questionId: String) async throws {
        let errors = await withTaskGroup(of: Error?.self) { group in
            group.addTask {
                do {
                    try await self.notesService.saveNote(answer, for: questionId)
                    return nil
                } catch {
                    return error
                }
            }
            
            group.addTask {
                do {
                    try await self.homeGraphMCP.saveNote(answer, for: questionId)
                    return nil
                } catch {
                    return error
                }
            }
            
            var errors: [Error] = []
            for await error in group {
                if let error = error {
                    errors.append(error)
                }
            }
            return errors
        }
        
        // If either write failed, handle appropriately
        if !errors.isEmpty {
            logger.error("Dual write partial failure: \(errors)")
            throw MigrationError.dualWriteFailure(errors)
        }
    }
}
```

### Step 5: Gradual Rollout (Week 2)

#### 5.1 Feature Flag Configuration
```swift
enum MigrationStage: String {
    case disabled = "disabled"
    case shadow = "shadow"          // Write to both, read from old
    case canary = "canary"          // 5% read from new
    case partial = "partial"        // 50% read from new
    case enabled = "enabled"        // 100% read from new
    case complete = "complete"      // Old system removed
}

class MigrationFeatureFlags {
    func currentStage() -> MigrationStage {
        let rawValue = RemoteConfig.shared.string(forKey: "homeGraphStage")
        return MigrationStage(rawValue: rawValue) ?? .disabled
    }
    
    func shouldUseHomeGraph() -> Bool {
        switch currentStage() {
        case .disabled, .shadow:
            return false
        case .canary:
            return rollDice(percentage: 5)
        case .partial:
            return rollDice(percentage: 50)
        case .enabled, .complete:
            return true
        }
    }
}
```

#### 5.2 Monitoring Setup
```swift
class MigrationMonitor {
    func trackOperation(
        operation: String,
        source: DataSource,
        success: Bool,
        latency: TimeInterval
    ) {
        Analytics.track("migration_operation", parameters: [
            "operation": operation,
            "source": source.rawValue,
            "success": success,
            "latency_ms": Int(latency * 1000)
        ])
    }
    
    func compareResults(
        operation: String,
        oldResult: Any?,
        newResult: Any?
    ) {
        let match = resultsMatch(oldResult, newResult)
        if !match {
            logger.warning("Result mismatch in \(operation)")
            Analytics.track("migration_mismatch", parameters: [
                "operation": operation,
                "old_result": String(describing: oldResult),
                "new_result": String(describing: newResult)
            ])
        }
    }
}
```

### Step 6: Validation & Cutover (Week 3)

#### 6.1 Final Validation
```swift
class FinalValidation {
    func performValidation() async throws -> ValidationReport {
        var report = ValidationReport()
        
        // 1. Data integrity check
        report.dataIntegrity = try await validateDataIntegrity()
        
        // 2. Performance comparison
        report.performance = try await comparePerformance()
        
        // 3. Feature parity check
        report.features = try await validateFeatureParity()
        
        // 4. Error rate analysis
        report.errors = try await analyzeErrorRates()
        
        return report
    }
    
    private func validateDataIntegrity() async throws -> Bool {
        // Compare all data between systems
        let notesData = try await notesService.exportAll()
        let graphData = try await homeGraphMCP.exportAll()
        
        return dataMatches(notesData, graphData)
    }
}
```

#### 6.2 Final Cutover
```swift
class CutoverCoordinator {
    func performCutover() async throws {
        // 1. Set NotesService to read-only
        NotesService.shared.setReadOnly(true)
        
        // 2. Final sync
        try await DataSyncService().syncData(direction: .notesToGraph)
        
        // 3. Update feature flags
        FeatureFlags.shared.set(.useHomeGraphMCP, to: true)
        FeatureFlags.shared.set(.dualWrite, to: false)
        
        // 4. Notify UI to refresh
        NotificationCenter.default.post(
            name: .dataSourceChanged,
            object: nil
        )
        
        logger.info("Cutover complete - HomeGraph MCP is now primary")
    }
}
```

### Step 7: Cleanup (Week 4)

#### 7.1 Remove Old Code
```bash
# After successful operation for 1 week
# Archive but don't delete immediately

mkdir -p Archived/NotesService
mv Services/Notes/* Archived/NotesService/

# Update imports and dependencies
```

#### 7.2 Remove Feature Flags
```swift
// Simplify code paths after migration
class NotesViewModel {
    // Before
    func loadNotes() async {
        if FeatureFlags.shared.isEnabled(.useHomeGraphMCP) {
            notes = try await homeGraphMCP.getNotes()
        } else {
            notes = try await notesService.getNotes()
        }
    }
    
    // After
    func loadNotes() async {
        notes = try await homeGraphMCP.getNotes()
    }
}
```

## Rollback Procedures

### Emergency Rollback

```swift
class EmergencyRollback {
    func execute(reason: String) async throws {
        logger.critical("Emergency rollback initiated: \(reason)")
        
        // 1. Immediately switch reads back to NotesService
        FeatureFlags.shared.set(.useHomeGraphMCP, to: false)
        
        // 2. Stop dual writes
        FeatureFlags.shared.set(.dualWrite, to: false)
        
        // 3. Sync any new data back
        if shouldSyncBack() {
            try await DataSyncService().syncData(direction: .graphToNotes)
        }
        
        // 4. Notify monitoring
        AlertingService.shared.sendAlert(
            level: .critical,
            message: "HomeGraph migration rolled back: \(reason)"
        )
        
        // 5. Clear caches
        clearAllCaches()
        
        logger.info("Rollback complete")
    }
}
```

### Rollback Triggers

1. **Error Rate > 5%**: Automatic rollback
2. **Performance Degradation > 50%**: Automatic rollback
3. **Data Inconsistency Detected**: Manual review required
4. **User Reports**: Manual rollback decision

## Post-Migration Tasks

### 1. Performance Optimization
- Analyze query patterns
- Optimize indices
- Tune cache sizes

### 2. Feature Enhancements
- Enable CoreML integration
- Add advanced graph queries
- Implement predictive features

### 3. Documentation Updates
- Update API documentation
- Create user guides
- Train support team

## Success Metrics

### Technical Metrics
- [ ] 100% data migrated successfully
- [ ] Query performance improved by >20%
- [ ] Error rate <0.1%
- [ ] Memory usage reduced by >30%

### Business Metrics
- [ ] User engagement maintained or improved
- [ ] Support tickets not increased
- [ ] App store rating maintained
- [ ] Feature adoption >80%

## Support Resources

### For Developers
- Migration FAQ: `docs/migration-faq.md`
- Troubleshooting: `docs/troubleshooting.md`
- API Changes: `docs/api-changes.md`

### For Users
- No visible changes initially
- Improved performance after migration
- New features enabled gradually

## Timeline Summary

| Week | Phase | Key Activities |
|------|-------|----------------|
| 1 | Preparation | Deploy infrastructure, initial testing |
| 2 | Migration | Data migration, dual operation |
| 3 | Validation | Gradual rollout, monitoring |
| 4 | Cleanup | Remove old code, optimization |

This migration guide ensures a smooth, safe transition from NotesService to HomeGraph MCP with minimal risk and maximum benefit.