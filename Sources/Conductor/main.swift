// Conductor — entry point placeholder.
// Phase 1 (per PROJECT_PLAN.md) replaces this with the real SwiftUI App.
// Until then, this file exists so `swift build` succeeds and the harness has
// something to lint, test, and ship through CI.

import Foundation

@main
struct ConductorBootstrap {
    static func main() {
        FileHandle.standardOutput.write(Data("Conductor harness scaffold — see PROJECT_PLAN.md\n".utf8))
    }
}
