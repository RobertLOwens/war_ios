// ============================================================================
// FILE: Grow2 Shared/Engine/DebugLog.swift
// PURPOSE: Debug-only logging utility - compiles to nothing in release builds
// ============================================================================

import Foundation

/// Debug-only print replacement. Compiles to nothing in release builds.
@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
