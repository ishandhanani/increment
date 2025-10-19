# Increment - iOS App

A modern iOS application using a **workspace + SPM package** architecture for clean separation between app shell and feature code.

## AI Assistant Rules Files

This template includes **opinionated rules files** for popular AI coding assistants. These files establish coding standards, architectural patterns, and best practices for modern iOS development using the latest APIs and Swift features.

### Included Rules Files

- **Claude Code**: `CLAUDE.md` - Claude Code rules
- **Cursor**: `.cursor/*.mdc` - Cursor-specific rules
- **GitHub Copilot**: `.github/copilot-instructions.md` - GitHub Copilot rules

### Customization Options

These rules files are **starting points** - feel free to:

- ✅ **Edit them** to match your team's coding standards
- ✅ **Delete them** if you prefer different approaches
- ✅ **Add your own** rules for other AI tools
- ✅ **Update them** as new iOS APIs become available

### What Makes These Rules Opinionated

- **No ViewModels**: Embraces pure SwiftUI state management patterns
- **Swift 6+ Concurrency**: Enforces modern async/await over legacy patterns
- **Latest APIs**: Recommends iOS 18+ features with optional iOS 26 guidelines
- **Testing First**: Promotes Swift Testing framework over XCTest
- **Performance Focus**: Emphasizes @Observable over @Published for better performance

**Note for AI assistants**: You MUST read the relevant rules files before making changes to ensure consistency with project standards.

## Project Architecture

```
Increment/
├── Increment.xcworkspace/              # Open this file in Xcode
├── Increment.xcodeproj/                # App shell project
├── Increment/                          # App target (minimal)
│   ├── Assets.xcassets/                # App-level assets (icons, colors)
│   ├── IncrementApp.swift              # App entry point
│   └── Increment.xctestplan            # Test configuration
├── IncrementPackage/                   # 🚀 Primary development area
│   ├── Package.swift                   # Package configuration
│   ├── Sources/IncrementFeature/       # Your feature code
│   └── Tests/IncrementFeatureTests/    # Unit tests
└── IncrementUITests/                   # UI automation tests
```

## Key Architecture Points

### Workspace + SPM Structure

- **App Shell**: `Increment/` contains minimal app lifecycle code
- **Feature Code**: `IncrementPackage/Sources/IncrementFeature/` is where most development happens
- **Separation**: Business logic lives in the SPM package, app target just imports and displays it

### Buildable Folders (Xcode 16)

- Files added to the filesystem automatically appear in Xcode
- No need to manually add files to project targets
- Reduces project file conflicts in teams

## Development Notes

### Code Organization

Most development happens in `IncrementPackage/Sources/IncrementFeature/` - organize your code as you prefer.

### Public API Requirements

Types exposed to the app target need `public` access:

```swift
public struct NewView: View {
    public init() {}

    public var body: some View {
        // Your view code
    }
}
```

### Adding Dependencies

Edit `IncrementPackage/Package.swift` to add SPM dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/example/SomePackage", from: "1.0.0")
],
targets: [
    .target(
        name: "IncrementFeature",
        dependencies: ["SomePackage"]
    ),
]
```

### Test Structure

- **Unit Tests**: `IncrementPackage/Tests/IncrementFeatureTests/` (Swift Testing framework)
- **UI Tests**: `IncrementUITests/` (XCUITest framework)
- **Test Plan**: `Increment.xctestplan` coordinates all tests

## Configuration

### XCConfig Build Settings

Build settings are managed through **XCConfig files** in `Config/`:

- `Config/Shared.xcconfig` - Common settings (bundle ID, versions, deployment target)
- `Config/Debug.xcconfig` - Debug-specific settings
- `Config/Release.xcconfig` - Release-specific settings
- `Config/Tests.xcconfig` - Test-specific settings

### Entitlements Management

App capabilities are managed through a **declarative entitlements file**:

- `Config/Increment.entitlements` - All app entitlements and capabilities
- AI agents can safely edit this XML file to add HealthKit, CloudKit, Push Notifications, etc.
- No need to modify complex Xcode project files

### Asset Management

- **App-Level Assets**: `Increment/Assets.xcassets/` (app icon, accent color)
- **Feature Assets**: Add `Resources/` folder to SPM package if needed

### SPM Package Resources

To include assets in your feature package:

```swift
.target(
    name: "IncrementFeature",
    dependencies: [],
    resources: [.process("Resources")]
)
```

## Workout Data Model Architecture

### Overview

The app uses a **dynamic workout generation system** with clean separation of concerns:

- **LiftLibrary** (Data) - Centralized repository of all exercise definitions
- **WorkoutBuilder** (Logic) - Dynamic template generation based on workout type
- **SessionManager** (State) - Orchestrates workout flow and manages session state

### Core Models

#### Lift
Represents a single exercise with rich metadata:
- No UUID (identified by name, Hashable)
- Category: Push/Pull/Legs/Cardio
- Equipment type and muscle groups
- STEEL configuration for progressive overload

#### WorkoutTemplate
Structured workout plan with multiple exercises:
- Has UUID for session tracking
- Contains ordered list of WorkoutExercise items
- Each exercise has priority (core vs accessory)
- Specifies sets, reps, rest periods

#### WorkoutCycle
Tracks rotation through workout types:
- Remembers last completed workout type
- Provides `.next` workout in rotation

### Dynamic Generation Flow

1. **Initialization**: Empty WorkoutCycle created in SessionManager
2. **Pre-Workout**: User selects feeling, triggers dynamic generation
3. **Generation**: `WorkoutBuilder.build(type:)` creates template on-demand
4. **Conversion**: Template → WorkoutPlan + ExerciseProfiles (STEEL format)
5. **Session-Scoped Storage**: Generated data stored with Session instance
6. **Execution**: STEEL progressive overload algorithm manages sets/weights

### STEEL Integration

Templates are converted to STEEL's format at runtime:
- `Lift` → `ExerciseProfile` (with progression config)
- `WorkoutTemplate` → `WorkoutPlan` (with exercise order)
- Conversion maintains backward compatibility with existing STEEL algorithm
- Each session stores its own generated WorkoutPlan and ExerciseProfiles

### Files

- `Models.swift` - Core data structures (Lift, WorkoutTemplate, WorkoutCycle, etc.)
- `LiftLibrary.swift` - All lift definitions organized by category
- `WorkoutBuilder.swift` - Dynamic template generation logic
- `WorkoutTemplateConverter.swift` - Converts templates to STEEL format
- `SessionManager.swift` - Orchestrates workout flow with dynamic generation

### Generated with XcodeBuildMCP

This project was scaffolded using [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP), which provides tools for AI-assisted iOS development workflows.
