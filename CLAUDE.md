# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Full build with simulator destination
xcodebuild -project Grow2.xcodeproj -scheme "Grow2 iOS" -destination 'platform=iOS Simulator,name=iPhone 16' build

# Quick syntax-check build (no simulator needed)
xcodebuild -project Grow2.xcodeproj -scheme "Grow2 iOS" build -destination 'generic/platform=iOS'
```

- **Swift 5.0**, iOS deployment target **17.2**
- Pure Xcode project — no CocoaPods, SPM, or Carthage
- No test target exists

## Architecture

### Core Pattern: Command → Engine → StateChange → Visual

All game logic lives in `Grow2 Shared/` (pure Swift, no SpriteKit). The iOS layer (`Grow2 iOS/`) handles UIKit and SpriteKit rendering.

**Flow:** Player/AI action → `EngineCommand.validate()` → `EngineCommand.execute()` → `StateChange` events emitted via `StateChangeBuilder` → visual layer pattern-matches on changes to update SpriteKit nodes.

### EngineCommand Protocol

```swift
protocol EngineCommand {
    var id: UUID { get }
    var playerID: UUID { get }
    var timestamp: TimeInterval { get }
    func validate(in state: GameState) -> EngineCommandResult
    func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult
}
```

All game mutations go through commands in `Commands/`. Use `BaseEngineCommand` for convenience defaults. AI commands (prefixed `AI`) use the same pipeline.

### GameEngine Subsystems

`GameEngine.shared` owns and coordinates these (they are **not** singletons):
- `CombatEngine` — 3-phase combat (with `DamageCalculator` and `GarrisonDefenseEngine`)
- `MovementEngine` — hex pathfinding and movement
- `ResourceEngine` — gathering and production
- `ConstructionEngine` — building and upgrades
- `TrainingEngine` — unit training queues
- `VisionEngine` — fog of war (unexplored → explored → visible)

Other singletons: `AIController.shared`, `NotificationManager.shared`.

### AI System

`AIController` orchestrates AI via a state machine (Peace → Alert → Defense → Attack → Retreat) and delegates to four planners:
- `AIEconomyPlanner` — building, villagers, resource camps, scouting
- `AIMilitaryPlanner` — army deployment, combat decisions
- `AIDefensePlanner` — towers, forts, garrison logic
- `AIResearchPlanner` — technology research selection

### Configuration

`GameConfig.swift` centralizes all tunable constants (engine intervals, movement speeds, combat multipliers, AI thresholds). Edit values there instead of hunting through engine files.

`DebugLog.swift` provides `debugLog(_:)` — use this instead of `print()`. Compiles to nothing in release builds.

### Large File Organization via Extensions

Several large classes are split into focused extension files:
- `GameScene` + `GameScene+InputHandling` (touch/drag/tap)
- `MenuCoordinator` + `+TileMenus` + `+EntityMenus`
- `BuildingDetailViewController` + `+Training` + `+Market` + `+Garrison` + `+Upgrades`

## Adding New Files to the Xcode Project

There is no SPM or build tool — you must manually edit `Grow2.xcodeproj/project.pbxproj`:

1. **PBXBuildFile** — add a build file entry with a unique 24-char hex ID
2. **PBXFileReference** — add a file reference entry with a unique ID
3. **PBXGroup** — add the file reference ID to the appropriate group's `children` array
4. **PBXSourcesBuildPhase** — add the build file ID to the `files` array

**ID convention:** The project uses semantic prefixes — e.g., `3FENGN` for Engine files, `3FDATA` for Data files, `3FBDVC` for BuildingDetailViewController extensions. Build file IDs end in `0001`, file reference IDs end in `0002`, both share a semantic suffix (e.g., `AICNT` for AIController). Use existing entries as templates.

## Code Patterns

- **Weak references**: View controllers referencing other controllers (e.g., `BuildingDetailViewController.gameViewController`) must use `weak` to avoid retain cycles.
- **Timer cleanup**: Store timers in properties and invalidate in `viewWillDisappear`.
- **Auto Layout**: Prefer Auto Layout over frame-based layout for new UI.
- **Logging**: Use `debugLog()` instead of `print()`.
