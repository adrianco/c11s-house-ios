# Threading Quick Reference Card

## 🚦 Thread-Safe Patterns for C11S House iOS

### ✅ DO: UI Updates

```swift
// For ViewModels
@MainActor
class MyViewModel: ObservableObject {
    @Published var uiProperty = ""
}

// For one-off updates
Task { @MainActor in
    self.uiProperty = newValue
}

// For Combine
publisher
    .receive(on: DispatchQueue.main)
    .sink { value in
        self.uiProperty = value
    }
```

### ✅ DO: Background Processing

```swift
// Thread-safe buffer
class Buffer {
    private let queue = DispatchQueue(label: "buffer", attributes: .concurrent)
    
    func write(_ data: Data) {
        queue.async(flags: .barrier) {
            // Write operation
        }
    }
    
    func read() -> Data {
        queue.sync {
            // Read operation
        }
    }
}
```

### ❌ DON'T: Common Mistakes

```swift
// ❌ UI update on background thread
DispatchQueue.global().async {
    self.label.text = "text" // Purple warning!
}

// ❌ Timer without main thread dispatch
Timer.scheduledTimer(withTimeInterval: 1.0) { _ in
    self.uiProperty = "value" // May crash!
}

// ❌ Missing @MainActor on UI class
class ViewModel: ObservableObject { // Should have @MainActor
    @Published var text = ""
}
```

### 🛠 Debug Tools

1. **Enable in Xcode Scheme:**
   - Main Thread Checker ✅
   - Thread Sanitizer (testing only) ✅

2. **Watch for:**
   - Purple warnings in console
   - "UI API called on background thread"
   - App freezing or lag

3. **Test Commands:**
   ```bash
   # Run threading tests
   ./run-threading-tests.sh
   
   # Check specific file
   xcodebuild test -only-testing:ThreadingVerificationTests
   ```

### 📋 Checklist for New Code

- [ ] ViewModels have `@MainActor`
- [ ] UI updates use `Task { @MainActor in ... }`
- [ ] Timers dispatch to main thread
- [ ] Combine uses `.receive(on: DispatchQueue.main)`
- [ ] Concurrent data structures use barriers
- [ ] No retain cycles in closures

### 🔍 Quick Verification

```swift
// Add to any method to verify thread
assert(Thread.isMainThread, "Must be on main thread!")
```

---
*Keep this reference handy when writing UI code!*