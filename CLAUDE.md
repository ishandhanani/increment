# Project Overview

> **⚠️ IMPORTANT:** All UI/UX design decisions MUST reference and follow the principles defined in [`DESIGN.md`](../DESIGN.md). This includes layout patterns, component choices, interaction rules, and visual language. When making any design-related changes, consult DESIGN.md first.

This is a native **iOS application** built with **Swift 6.1+** and **SwiftUI**. The codebase targets **iOS 18.0 and later**, allowing full use of modern Swift and iOS APIs. All concurrency is handled with **Swift Concurrency** (async/await, actors, @MainActor isolation) ensuring thread-safe code.

- **Frameworks & Tech:** SwiftUI for UI, Swift Concurrency with strict mode, Swift Package Manager for modular architecture
- **Architecture:** Model-View (MV) pattern using pure SwiftUI state management. We avoid MVVM and instead leverage SwiftUI's built-in state mechanisms (@State, @Observable, @Environment, @Binding)
- **Testing:** Swift Testing framework with modern @Test macros and #expect/#require assertions
- **Platform:** iOS (Simulator and Device)
- **Accessibility:** Full accessibility support using SwiftUI's accessibility modifiers

## Project Structure

The project follows a **workspace + SPM package** architecture:

```
YourApp/
├── Config/                         # XCConfig build settings
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   ├── Shared.xcconfig
│   └── Tests.xcconfig
├── YourApp.xcworkspace/            # Workspace container
├── YourApp.xcodeproj/              # App shell (minimal wrapper)
├── YourApp/                        # App target - just the entry point
│   ├── Assets.xcassets/
│   ├── YourAppApp.swift           # @main entry point only
│   └── YourApp.xctestplan
├── YourAppPackage/                 # All features and business logic
│   ├── Package.swift
│   ├── Sources/
│   │   └── YourAppFeature/        # Feature modules
│   └── Tests/
│       └── YourAppFeatureTests/   # Swift Testing tests
└── YourAppUITests/                 # UI automation tests
```

**Important:** All development work should be done in the **YourAppPackage** Swift Package, not in the app project. The app project is merely a thin wrapper that imports and launches the package features.

# Code Quality & Style Guidelines

## Swift Style & Conventions

- **Naming:** Use `UpperCamelCase` for types, `lowerCamelCase` for properties/functions. Choose descriptive names (e.g., `calculateMonthlyRevenue()` not `calcRev`)
- **Value Types:** Prefer `struct` for models and data, use `class` only when reference semantics are required
- **Enums:** Leverage Swift's powerful enums with associated values for state representation
- **Early Returns:** Prefer early return pattern over nested conditionals to avoid pyramid of doom

## Optionals & Error Handling

- Use optionals with `if let`/`guard let` for nil handling
- Never force-unwrap (`!`) without absolute certainty - prefer `guard` with failure path
- Use `do/try/catch` for error handling with meaningful error types
- Handle or propagate all errors - no empty catch blocks

# Modern SwiftUI Architecture Guidelines (2025)

### No ViewModels - Use Native SwiftUI Data Flow

**New features MUST follow these patterns:**

1. **Views as Pure State Expressions**

   ```swift
   struct MyView: View {
       @Environment(MyService.self) private var service
       @State private var viewState: ViewState = .loading

       enum ViewState {
           case loading
           case loaded(data: [Item])
           case error(String)
       }

       var body: some View {
           // View is just a representation of its state
       }
   }
   ```

2. **Use Environment Appropriately**

   - **App-wide services**: Router, Theme, CurrentAccount, Client, etc. - use `@Environment`
   - **Feature-specific services**: Timeline services, single-view logic - use `let` properties with `@Observable`
   - Rule: Environment for cross-app/cross-feature dependencies, let properties for single-feature services
   - Access app-wide via `@Environment(ServiceType.self)`
   - Feature services: `private let myService = MyObservableService()`

3. **Local State Management**

   - Use `@State` for view-specific state
   - Use `enum` for view states (loading, loaded, error)
   - Use `.task(id:)` and `.onChange(of:)` for side effects
   - Pass state between views using `@Binding`

4. **No ViewModels Required**

   - Views should be lightweight and disposable
   - Business logic belongs in services/clients
   - Test services independently, not views
   - Use SwiftUI previews for visual testing

5. **When Views Get Complex**
   - Split into smaller subviews
   - Use compound views that compose smaller views
   - Pass state via bindings between views
   - Never reach for a ViewModel as the solution

# iOS 26 Features (Optional)

**Note**: If your app targets iOS 26+, you can take advantage of these cutting-edge SwiftUI APIs introduced in June 2025. These features are optional and should only be used when your deployment target supports iOS 26.

## Available iOS 26 SwiftUI APIs

When targeting iOS 26+, consider using these new APIs:

#### Liquid Glass Effects

- `glassEffect(_:in:isEnabled:)` - Apply Liquid Glass effects to views
- `buttonStyle(.glass)` - Apply Liquid Glass styling to buttons
- `ToolbarSpacer` - Create visual breaks in toolbars with Liquid Glass

#### Enhanced Scrolling

- `scrollEdgeEffectStyle(_:for:)` - Configure scroll edge effects
- `backgroundExtensionEffect()` - Duplicate, mirror, and blur views around edges

#### Tab Bar Enhancements

- `tabBarMinimizeBehavior(_:)` - Control tab bar minimization behavior
- Search role for tabs with search field replacing tab bar
- `TabViewBottomAccessoryPlacement` - Adjust accessory view content based on placement

#### Web Integration

- `WebView` and `WebPage` - Full control over browsing experience

#### Drag and Drop

- `draggable(_:_:)` - Drag multiple items
- `dragContainer(for:id:in:selection:_:)` - Container for draggable views

#### Animation

- `@Animatable` macro - SwiftUI synthesizes custom animatable data properties

#### UI Components

- `Slider` with automatic tick marks when using step parameter
- `windowResizeAnchor(_:)` - Set window anchor point for resizing

#### Text Enhancements

- `TextEditor` now supports `AttributedString`
- `AttributedTextSelection` - Handle text selection with attributed text
- `AttributedTextFormattingDefinition` - Define text styling in specific contexts
- `FindContext` - Create find navigator in text editing views

#### Accessibility

- `AssistiveAccess` - Support Assistive Access in iOS scenes

#### HDR Support

- `Color.ResolvedHDR` - RGBA values with HDR headroom information

#### UIKit Integration

- `UIHostingSceneDelegate` - Host and present SwiftUI scenes in UIKit
- `NSGestureRecognizerRepresentable` - Incorporate gesture recognizers from AppKit

#### Immersive Spaces (if applicable)

- `manipulable(coordinateSpace:operations:inertia:isEnabled:onChanged:)` - Hand gesture manipulation
- `SurfaceSnappingInfo` - Snap volumes and windows to surfaces
- `RemoteImmersiveSpace` - Render stereo content from Mac to Apple Vision Pro
- `SpatialContainer` - 3D layout container
- Depth-based modifiers: `aspectRatio3D(_:contentMode:)`, `rotation3DLayout(_:)`, `depthAlignment(_:)`

## iOS 26 Usage Guidelines

- **Only use when targeting iOS 26+**: Ensure your deployment target supports these APIs
- **Progressive enhancement**: Use availability checks if supporting multiple iOS versions
- **Feature detection**: Test on older simulators to ensure graceful fallbacks
- **Modern aesthetics**: Leverage Liquid Glass effects for cutting-edge UI design

```swift
// Example: Using iOS 26 features with availability checks
struct ModernButton: View {
    var body: some View {
        Button("Tap me") {
            // Action
        }
        .buttonStyle({
            if #available(iOS 26.0, *) {
                .glass
            } else {
                .bordered
            }
        }())
    }
}
```

## SwiftUI State Management (MV Pattern)

- **@State:** For all state management, including observable model objects
- **@Observable:** Modern macro for making model classes observable (replaces ObservableObject)
- **@Environment:** For dependency injection and shared app state
- **@Binding:** For two-way data flow between parent and child views
- **@Bindable:** For creating bindings to @Observable objects
- Avoid ViewModels - put view logic directly in SwiftUI views using these state mechanisms
- Keep views focused and extract reusable components

Example with @Observable:

```swift
@Observable
class UserSettings {
    var theme: Theme = .light
    var fontSize: Double = 16.0
}

@MainActor
struct SettingsView: View {
    @State private var settings = UserSettings()

    var body: some View {
        VStack {
            // Direct property access, no $ prefix needed
            Text("Font Size: \(settings.fontSize)")

            // For bindings, use @Bindable
            @Bindable var settings = settings
            Slider(value: $settings.fontSize, in: 10...30)
        }
    }
}

// Sharing state across views
@MainActor
struct ContentView: View {
    @State private var userSettings = UserSettings()

    var body: some View {
        NavigationStack {
            MainView()
                .environment(userSettings)
        }
    }
}

@MainActor
struct MainView: View {
    @Environment(UserSettings.self) private var settings

    var body: some View {
        Text("Current theme: \(settings.theme)")
    }
}
```

Example with .task modifier for async operations:

```swift
@Observable
class DataModel {
    var items: [Item] = []
    var isLoading = false

    func loadData() async throws {
        isLoading = true
        defer { isLoading = false }

        // Simulated network call
        try await Task.sleep(for: .seconds(1))
        items = try await fetchItems()
    }
}

@MainActor
struct ItemListView: View {
    @State private var model = DataModel()

    var body: some View {
        List(model.items) { item in
            Text(item.name)
        }
        .overlay {
            if model.isLoading {
                ProgressView()
            }
        }
        .task {
            // This task automatically cancels when view disappears
            do {
                try await model.loadData()
            } catch {
                // Handle error
            }
        }
        .refreshable {
            // Pull to refresh also uses async/await
            try? await model.loadData()
        }
    }
}
```

## Concurrency

- **@MainActor:** All UI updates must use @MainActor isolation
- **Actors:** Use actors for expensive operations like disk I/O, network calls, or heavy computation
- **async/await:** Always prefer async functions over completion handlers
- **Task:** Use structured concurrency with proper task cancellation
- **.task modifier:** Always use .task { } on views for async operations tied to view lifecycle - it automatically handles cancellation
- **Avoid Task { } in onAppear:** This doesn't cancel automatically and can cause memory leaks or crashes
- No GCD usage - Swift Concurrency only

### Sendable Conformance

Swift 6 enforces strict concurrency checking. All types that cross concurrency boundaries must be Sendable:

- **Value types (struct, enum):** Usually Sendable if all properties are Sendable
- **Classes:** Must be marked `final` and have immutable or Sendable properties, or use `@unchecked Sendable` with thread-safe implementation
- **@Observable classes:** Automatically Sendable when all properties are Sendable
- **Closures:** Mark as `@Sendable` when captured by concurrent contexts

```swift
// Sendable struct - automatic conformance
struct UserData: Sendable {
    let id: UUID
    let name: String
}

// Sendable class - must be final with immutable properties
final class Configuration: Sendable {
    let apiKey: String
    let endpoint: URL

    init(apiKey: String, endpoint: URL) {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }
}

// @Observable with Sendable
@Observable
final class UserModel: Sendable {
    var name: String = ""
    var age: Int = 0
    // Automatically Sendable if all stored properties are Sendable
}

// Using @unchecked Sendable for thread-safe types
final class Cache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]

    func get(_ key: String) -> Any? {
        lock.withLock { storage[key] }
    }
}

// @Sendable closures
func processInBackground(completion: @Sendable @escaping (Result<Data, Error>) -> Void) {
    Task {
        // Processing...
        completion(.success(data))
    }
}
```

## Code Organization

- Keep functions focused on a single responsibility
- Break large functions (>50 lines) into smaller, testable units
- Use extensions to organize code by feature or protocol conformance
- Prefer `let` over `var` - use immutability by default
- Use `[weak self]` in closures to prevent retain cycles
- Always include `self.` when referring to instance properties in closures

# Testing Guidelines

We use **Swift Testing** framework (not XCTest) for all tests. Tests live in the package test target.

## Swift Testing Basics

```swift
import Testing

@Test func userCanLogin() async throws {
    let service = AuthService()
    let result = try await service.login(username: "test", password: "pass")
    #expect(result.isSuccess)
    #expect(result.user.name == "Test User")
}

@Test("User sees error with invalid credentials")
func invalidLogin() async throws {
    let service = AuthService()
    await #expect(throws: AuthError.self) {
        try await service.login(username: "", password: "")
    }
}
```

## Key Swift Testing Features

- **@Test:** Marks a test function (replaces XCTest's test prefix)
- **@Suite:** Groups related tests together
- **#expect:** Validates conditions (replaces XCTAssert)
- **#require:** Like #expect but stops test execution on failure
- **Parameterized Tests:** Use @Test with arguments for data-driven tests
- **async/await:** Full support for testing async code
- **Traits:** Add metadata like `.bug()`, `.feature()`, or custom tags

## Test Organization

- Write tests in the package's Tests/ directory
- One test file per source file when possible
- Name tests descriptively explaining what they verify
- Test both happy paths and edge cases
- Add tests for bug fixes to prevent regression

# Entitlements Management

This template includes a **declarative entitlements system** that AI agents can safely modify without touching Xcode project files.

## How It Works

- **Entitlements File**: `Config/Increment.entitlements` contains all app capabilities
- **XCConfig Integration**: `CODE_SIGN_ENTITLEMENTS` setting in `Config/Shared.xcconfig` points to the entitlements file
- **AI-Friendly**: Agents can edit the XML file directly to add/remove capabilities

## Adding Entitlements

To add capabilities to your app, edit `Config/Increment.entitlements`:

## Common Entitlements

| Capability         | Entitlement Key                          | Value                                                             |
| ------------------ | ---------------------------------------- | ----------------------------------------------------------------- |
| HealthKit          | `com.apple.developer.healthkit`          | `<true/>`                                                         |
| CloudKit           | `com.apple.developer.icloud-services`    | `<array><string>CloudKit</string></array>`                        |
| Push Notifications | `aps-environment`                        | `development` or `production`                                     |
| App Groups         | `com.apple.security.application-groups`  | `<array><string>group.id</string></array>`                        |
| Keychain Sharing   | `keychain-access-groups`                 | `<array><string>$(AppIdentifierPrefix)bundle.id</string></array>` |
| Background Modes   | `com.apple.developer.background-modes`   | `<array><string>mode-name</string></array>`                       |
| Contacts           | `com.apple.developer.contacts.notes`     | `<true/>`                                                         |
| Camera             | `com.apple.developer.avfoundation.audio` | `<true/>`                                                         |

# XcodeBuildMCP Tool Usage

To work with this project, build, test, and development commands should use XcodeBuildMCP tools instead of raw command-line calls.

## Project Discovery & Setup

```javascript
// Discover Xcode projects in the workspace
discover_projs({
  workspaceRoot: "/path/to/YourApp",
});

// List available schemes
list_schems_ws({
  workspacePath: "/path/to/YourApp.xcworkspace",
});
```

## Building for Simulator

```javascript
// Build for iPhone simulator by name
build_sim_name_ws({
  workspacePath: "/path/to/YourApp.xcworkspace",
  scheme: "YourApp",
  simulatorName: "iPhone 16",
  configuration: "Debug",
});

// Build and run in one step
build_run_sim_name_ws({
  workspacePath: "/path/to/YourApp.xcworkspace",
  scheme: "YourApp",
  simulatorName: "iPhone 16",
});
```

## Building for Device

```javascript
// List connected devices first
list_devices();

// Build for physical device
build_dev_ws({
  workspacePath: "/path/to/YourApp.xcworkspace",
  scheme: "YourApp",
  configuration: "Debug",
});
```

## Testing

```javascript
// Run tests on simulator
test_sim_name_ws({
  workspacePath: "/path/to/YourApp.xcworkspace",
  scheme: "YourApp",
  simulatorName: "iPhone 16",
});

// Run tests on device
test_device_ws({
  workspacePath: "/path/to/YourApp.xcworkspace",
  scheme: "YourApp",
  deviceId: "DEVICE_UUID_HERE",
});

// Test Swift Package
swift_package_test({
  packagePath: "/path/to/YourAppPackage",
});
```

## Simulator Management

```javascript
// List available simulators
list_sims({
  enabled: true,
});

// Boot simulator
boot_sim({
  simulatorUuid: "SIMULATOR_UUID",
});

// Install app
install_app_sim({
  simulatorUuid: "SIMULATOR_UUID",
  appPath: "/path/to/YourApp.app",
});

// Launch app
launch_app_sim({
  simulatorUuid: "SIMULATOR_UUID",
  bundleId: "com.example.YourApp",
});
```

## Device Management

```javascript
// Install on device
install_app_device({
  deviceId: "DEVICE_UUID",
  appPath: "/path/to/YourApp.app",
});

// Launch on device
launch_app_device({
  deviceId: "DEVICE_UUID",
  bundleId: "com.example.YourApp",
});
```

## UI Automation

```javascript
// Get UI hierarchy
describe_ui({
  simulatorUuid: "SIMULATOR_UUID",
});

// Tap element
tap({
  simulatorUuid: "SIMULATOR_UUID",
  x: 100,
  y: 200,
});

// Type text
type_text({
  simulatorUuid: "SIMULATOR_UUID",
  text: "Hello World",
});

// Take screenshot
screenshot({
  simulatorUuid: "SIMULATOR_UUID",
});
```

## Log Capture

```javascript
// Start capturing simulator logs
start_sim_log_cap({
  simulatorUuid: "SIMULATOR_UUID",
  bundleId: "com.example.YourApp",
});

// Stop and retrieve logs
stop_sim_log_cap({
  logSessionId: "SESSION_ID",
});

// Device logs
start_device_log_cap({
  deviceId: "DEVICE_UUID",
  bundleId: "com.example.YourApp",
});
```

## Utility Functions

```javascript
// Get bundle ID from app
get_app_bundle_id({
  appPath: "/path/to/YourApp.app",
});

// Clean build artifacts
clean_ws({
  workspacePath: "/path/to/YourApp.xcworkspace",
});

// Get app path for simulator
get_sim_app_path_name_ws({
  workspacePath: "/path/to/YourApp.xcworkspace",
  scheme: "YourApp",
  platform: "iOS Simulator",
  simulatorName: "iPhone 16",
});
```

# Development Workflow

1. **Make changes in the Package**: All feature development happens in YourAppPackage/Sources/
2. **Write tests**: Add Swift Testing tests in YourAppPackage/Tests/
3. **Build and test**: Use XcodeBuildMCP tools to build and run tests
4. **Run on simulator**: Deploy to simulator for manual testing
5. **UI automation**: Use describe_ui and automation tools for UI testing
6. **Device testing**: Deploy to physical device when needed

# Best Practices

## SwiftUI & State Management

- Keep views small and focused
- Extract reusable components into their own files
- Use @ViewBuilder for conditional view composition
- Leverage SwiftUI's built-in animations and transitions
- Avoid massive body computations - break them down
- **Always use .task modifier** for async work tied to view lifecycle - it automatically cancels when the view disappears
- Never use Task { } in onAppear - use .task instead for proper lifecycle management

## Performance

- Use .id() modifier sparingly as it forces view recreation
- Implement Equatable on models to optimize SwiftUI diffing
- Use LazyVStack/LazyHStack for large lists
- Profile with Instruments when needed
- @Observable tracks only accessed properties, improving performance over @Published

## Accessibility

- Always provide accessibilityLabel for interactive elements
- Use accessibilityIdentifier for UI testing
- Implement accessibilityHint where actions aren't obvious
- Test with VoiceOver enabled
- Support Dynamic Type

## Security & Privacy

- Never log sensitive information
- Use Keychain for credential storage
- All network calls must use HTTPS
- Request minimal permissions
- Follow App Store privacy guidelines

## Data Persistence

When data persistence is required, always prefer **SwiftData** over CoreData. However, carefully consider whether persistence is truly necessary - many apps can function well with in-memory state that loads on launch.

### When to Use SwiftData

- You have complex relational data that needs to persist across app launches
- You need advanced querying capabilities with predicates and sorting
- You're building a data-heavy app (note-taking, inventory, task management)
- You need CloudKit sync with minimal configuration

### When NOT to Use Data Persistence

- Simple user preferences (use UserDefaults)
- Temporary state that can be reloaded from network
- Small configuration data (consider JSON files or plist)
- Apps that primarily display remote data

### SwiftData Best Practices

```swift
import SwiftData

@Model
final class Task {
    var title: String
    var isCompleted: Bool
    var createdAt: Date

    init(title: String) {
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
}

// In your app
@main
struct IncrementApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: Task.self)
        }
    }
}

// In your views
struct TaskListView: View {
    @Query private var tasks: [Task]
    @Environment(\.modelContext) private var context

    var body: some View {
        List(tasks) { task in
            Text(task.title)
        }
        .toolbar {
            Button("Add") {
                let newTask = Task(title: "New Task")
                context.insert(newTask)
            }
        }
    }
}
```

**Important:** Never use CoreData for new projects. SwiftData provides a modern, type-safe API that's easier to work with and integrates seamlessly with SwiftUI.

---

# Live Activities Implementation

This app includes **Live Activities** for real-time workout tracking on the lock screen and Dynamic Island.

## Architecture

Live Activities are implemented using:

- **ActivityKit** framework (iOS 16.1+) for Live Activity lifecycle management
- **WidgetKit** for rendering Lock Screen and Dynamic Island UI
- **Widget Extension** target (`IncrementWidget`) containing all Live Activity UI code

## Key Components

### 1. Activity Attributes & State

- **File**: `IncrementPackage/Sources/IncrementFeature/WorkoutLiveActivity.swift`
- Defines static attributes (workout name) and dynamic content state (exercise, sets, rest timer, etc.)

### 2. Live Activity Manager

- **File**: `IncrementPackage/Sources/IncrementFeature/LiveActivityManager.swift`
- Singleton service managing activity lifecycle: start, update, end
- Handles ActivityKit API calls with proper error handling

### 3. Notification Manager

- **File**: `IncrementPackage/Sources/IncrementFeature/NotificationManager.swift`
- Manages notification permissions (required for Live Activities)
- Requests authorization on first launch

### 4. Widget Extension UI

- **File**: `IncrementWidget/WorkoutLiveActivityWidget.swift`
- Complete Live Activity widget implementation
- Lock Screen UI: Shows exercise, sets progress, rest timer, and next prescription
- Dynamic Island: Compact (minimal info), minimal (split view), and expanded states
- Real-time timer updates during rest periods

### 5. Session Integration

- **File**: `IncrementPackage/Sources/IncrementFeature/SessionManager.swift`
- Integrates LiveActivityManager into workout flow
- Updates Live Activity on exercise transitions
- Provides real-time rest timer updates (every second)
- Ends activity when workout completes

## Widget Extension Setup

The Widget Extension target must be configured in Xcode (cannot be done via CLI):

1. **Add Widget Extension Target:**

   - File → New → Target → Widget Extension
   - Name: `IncrementWidget`
   - Enable "Include Live Activity" checkbox
   - Do NOT select "Include Configuration Intent"

2. **Link IncrementFeature Package:**

   - Select IncrementWidget target
   - General tab → Frameworks and Libraries
   - Add `IncrementFeature` from IncrementPackage

3. **Configure Info.plist Keys:**

   - Main app's Info.plist needs:
     ```xml
     <key>NSSupportsLiveActivities</key>
     <true/>
     <key>NSSupportsLiveActivitiesFrequentUpdates</key>
     <true/>
     ```
   - Widget's Info.plist needs:
     ```xml
     <key>NSExtension</key>
     <dict>
         <key>NSExtensionPointIdentifier</key>
         <string>com.apple.widgetkit-extension</string>
     </dict>
     ```

4. **Clean Up Template Files:**
   - Remove Xcode-generated template files (IncrementWidget.swift, IncrementWidgetLiveActivity.swift, etc.)
   - Update IncrementWidgetBundle.swift to only include WorkoutLiveActivity()

## Testing Live Activities

1. Build and run on simulator (iOS 16.1+)
2. Start a workout session
3. Lock the device (Cmd+L)
4. Grant notification permission when prompted
5. Observe Live Activity on lock screen with real-time timer
6. Unlock to see Dynamic Island compact view (on supported devices)

## Permissions

Live Activities require notification permissions. The app automatically requests authorization when starting the first Live Activity. Users must grant permission for Live Activities to appear.

## Implementation Notes

- **Real-time updates**: Timer updates every second during rest periods using RestTimer's publisher
- **Frequent updates enabled**: Info.plist flag allows high-frequency updates for smooth countdown
- **Automatic lifecycle**: Activities start when exercise begins, update during rest, and end when session completes
- **Error handling**: All ActivityKit calls include proper error handling and graceful fallbacks
- **Type safety**: Using explicit ActivityContent types to satisfy Swift 6 strict concurrency

---

# Workout Data Model Architecture

## Overview

Increment uses a **dynamic workout generation system** with clean separation of concerns between data, logic, and state management.

### Architecture Layers

- **LiftLibrary** (Data) - Centralized repository of all exercise definitions
- **WorkoutBuilder** (Logic) - Dynamic template generation based on workout type
- **SessionManager** (State) - Orchestrates workout flow and manages session state

## Core Models

### Lift

Represents a single exercise with rich metadata:

```swift
public struct Lift: Codable, Hashable, Sendable {
    public let name: String              // No UUID - identified by name
    public let category: LiftCategory    // push/pull/legs/cardio
    public let equipment: Equipment
    public let muscleGroups: [MuscleGroup]
    public let steelConfig: SteelConfig

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
```

Key design decisions:
- **No UUID**: Lifts are identified by name, making them simple and hashable
- **Rich metadata**: Category, equipment, muscle groups for filtering and organization
- **STEEL config**: Built-in progressive overload configuration

### WorkoutTemplate

Structured workout plan combining multiple exercises:

```swift
public struct WorkoutTemplate: Codable, Identifiable, Sendable {
    public let id: UUID                          // Has UUID for session tracking
    public let name: String
    public let workoutType: LiftCategory
    public let exercises: [WorkoutExercise]
}

public struct WorkoutExercise: Codable, Identifiable, Sendable {
    public let id: UUID
    public let lift: Lift
    public let order: Int
    public let priority: LiftPriority           // .core or .accessory
    public let sets: Int
    public let reps: Int
    public let restSeconds: Int
}
```

Key design decisions:
- **UUID for templates**: Templates need IDs for session tracking and persistence
- **Exercise priority**: Distinguishes core lifts from accessory work
- **Ordered exercises**: Explicit order field for workout flow

### WorkoutCycle

Tracks rotation through workout types:

```swift
public struct WorkoutCycle: Codable, Sendable {
    public var templates: [WorkoutTemplate]     // Empty in dynamic mode
    public var lastCompletedType: LiftCategory?

    public func nextWorkout() -> WorkoutTemplate? {
        // Returns next workout in rotation
    }
}

public enum LiftCategory: String, Codable, Sendable, CaseIterable {
    case push, pull, legs, cardio

    public var next: LiftCategory {
        let all = LiftCategory.allCases
        guard let currentIndex = all.firstIndex(of: self) else { return .push }
        let nextIndex = (currentIndex + 1) % all.count
        return all[nextIndex]
    }
}
```

## Dynamic Generation Flow

1. **Initialization**: Empty `WorkoutCycle` created in `SessionManager.init()`
   ```swift
   private func loadDefaultWorkoutCycle() {
       workoutCycle = WorkoutCycle(templates: [], lastCompletedType: nil)
   }
   ```

2. **Pre-Workout**: User selects feeling → triggers dynamic generation
   ```swift
   public func logPreWorkoutFeeling(_ feeling: PreWorkoutFeeling) {
       let nextType = workoutCycle?.lastCompletedType?.next ?? .push
       currentWorkoutTemplate = WorkoutBuilder.build(type: nextType)
       sessionState = .workoutOverview
   }
   ```

3. **Generation**: `WorkoutBuilder.build(type:)` creates template on-demand
   ```swift
   struct WorkoutBuilder {
       static func build(type: LiftCategory) -> WorkoutTemplate {
           switch type {
           case .push: return buildPushDay()
           case .pull: return buildPullDay()
           case .legs: return buildLegDay()
           case .cardio: return buildCardioDay()
           }
       }
   }
   ```

4. **Conversion**: Template → WorkoutPlan + ExerciseProfiles (STEEL format)
   ```swift
   let (plan, profiles) = WorkoutTemplateConverter.toWorkoutPlan(from: template)
   ```

5. **Session-Scoped Storage**: Generated data stored with Session instance
   ```swift
   currentSession?.workoutPlan = plan
   currentSession?.exerciseProfilesForSession = profiles
   ```

6. **Execution**: STEEL progressive overload algorithm manages sets/weights

## STEEL Integration

The STEEL (Set-to-set Tuning + End-of-exercise Escalation/Lowering) progressive overload system requires a specific data format. We maintain compatibility through runtime conversion:

### Conversion Layer

```swift
struct WorkoutTemplateConverter {
    static func toExerciseProfile(from lift: Lift, sets: Int, restSec: Int) -> ExerciseProfile {
        ExerciseProfile(
            name: lift.name,
            sets: sets,
            goalReps: lift.steelConfig.goalReps,
            restSec: restSec,
            minIncrement: lift.steelConfig.minIncrement,
            maxIncrement: lift.steelConfig.maxIncrement,
            microAdjustThreshold: lift.steelConfig.microAdjustThreshold,
            badDaySwitch: lift.steelConfig.badDaySwitch
        )
    }

    static func toWorkoutPlan(from template: WorkoutTemplate) -> (WorkoutPlan, [UUID: ExerciseProfile]) {
        // Generates unique UUIDs and converts all exercises
    }
}
```

### Session-Scoped Storage

Unlike the old global `exerciseProfiles` and `workoutPlans` dictionaries, the new system stores generated data directly with each Session:

```swift
public struct Session: Codable, Identifiable, Sendable {
    public let workoutPlanId: UUID

    // Session-scoped workout data (generated from template once per session)
    public var workoutPlan: WorkoutPlan?
    public var exerciseProfilesForSession: [UUID: ExerciseProfile]?
}
```

This ensures:
- Each session has its own isolated workout data
- Resume functionality works correctly (restores from session storage)
- No global state pollution across sessions
- Clean session history with embedded workout data

## File Organization

### Models (`IncrementPackage/Sources/IncrementFeature/Models.swift`)
Core data structures used throughout the app:
- `Lift`, `LiftCategory`, `Equipment`, `MuscleGroup`
- `WorkoutTemplate`, `WorkoutExercise`, `LiftPriority`
- `WorkoutCycle`, `SteelConfig`
- `Session` (with session-scoped storage fields)

### Lift Library (`IncrementPackage/Sources/IncrementFeature/LiftLibrary.swift`)
Centralized repository of all exercise definitions organized by category:
```swift
struct LiftLibrary {
    // Push exercises
    static let benchPress = Lift(...)
    static let inclineDumbbellBench = Lift(...)
    static let pushLifts: [Lift] = [benchPress, inclineDumbbellBench, ...]

    // Pull exercises
    static let pullups = Lift(...)
    static let pullLifts: [Lift] = [pullups, ...]

    // Legs and cardio...
}
```

### Workout Builder (`IncrementPackage/Sources/IncrementFeature/WorkoutBuilder.swift`)
Dynamic template generation logic:
```swift
struct WorkoutBuilder {
    static func build(type: LiftCategory) -> WorkoutTemplate {
        // Generates templates on-demand
    }

    private static func buildPushDay() -> WorkoutTemplate {
        // 2 core + 3 accessory exercises
    }
}
```

### Template Converter (`IncrementPackage/Sources/IncrementFeature/WorkoutTemplateConverter.swift`)
Converts templates to STEEL format:
- Lift → ExerciseProfile
- WorkoutTemplate → (WorkoutPlan, [UUID: ExerciseProfile])

### Session Manager (`IncrementPackage/Sources/IncrementFeature/SessionManager.swift`)
Orchestrates the entire workout flow with dynamic generation

## Benefits of This Architecture

1. **Separation of Concerns**: Data, logic, and state are cleanly separated
2. **Dynamic Generation**: Workouts created on-demand, enabling future variations
3. **Maintainability**: All lift definitions in one place (LiftLibrary)
4. **Extensibility**: Easy to add new workout types, variations, randomization
5. **STEEL Compatibility**: Maintains existing progressive overload system
6. **Session Isolation**: Each session carries its own workout data
7. **Type Safety**: Full Swift type checking with Codable/Sendable

## Future Enhancements

- Workout variations based on equipment availability
- Randomized accessory exercise selection
- Progression-based exercise substitution
- Personalization based on user feedback
- Terminal-style "generating workout" animation

---

Remember: This project prioritizes clean, simple SwiftUI code using the platform's native state management. Keep the app shell minimal and implement all features in the Swift Package.
