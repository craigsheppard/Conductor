// swift-tools-version: 5.10
// Conductor — macOS dashboard for Claude Code sessions.
// This Package.swift is intentionally minimal: it pins the toolchain and platform.
// Real targets (App, Domain, Stores, etc.) land in Phase 1 per PROJECT_PLAN.md.

import PackageDescription

let package = Package(
    name: "Conductor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "conductor", targets: ["Conductor"])
    ],
    targets: [
        .executableTarget(
            name: "Conductor",
            path: "Sources/Conductor"
        ),
        .testTarget(
            name: "ConductorTests",
            dependencies: ["Conductor"],
            path: "Tests/ConductorTests"
        )
    ]
)
