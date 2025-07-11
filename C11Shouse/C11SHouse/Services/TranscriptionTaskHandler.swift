/*
 * CONTEXT & PURPOSE:
 * TranscriptionTaskHandler provides thread-safe management of transcription task
 * continuations using Swift's actor model. This replaces the older objc_sync
 * pattern with modern concurrency primitives.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation
 *   - Created as part of Phase 4 refactoring
 *   - Replaces objc_sync_enter/exit patterns
 *   - Uses actor isolation for thread safety
 *   - Prevents multiple continuation resumes
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation

/// Thread-safe handler for transcription task continuations
actor TranscriptionTaskHandler {
    private var hasResumed = false
    private var continuation: CheckedContinuation<String, Error>?
    
    /// Set the continuation for this task
    func setContinuation(_ continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }
    
    /// Check if we should process results (returns true only once)
    func shouldProcess() -> Bool {
        if hasResumed { return false }
        hasResumed = true
        return true
    }
    
    /// Resume the continuation with a result
    func resume(with result: Result<String, Error>) {
        guard let continuation = continuation else { return }
        
        if !hasResumed {
            hasResumed = true
            continuation.resume(with: result)
        }
    }
    
    /// Check if the task has been resumed
    func isResumed() -> Bool {
        return hasResumed
    }
}