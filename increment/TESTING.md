# Increment Testing Strategy

## Overview

This document outlines the testing strategy for the Increment workout tracking application. Our approach prioritizes **critical business logic** while maintaining **rapid iteration** during beta development.

## Philosophy: AMANALAP (As Minimal As Necessary, As Late As Possible)

We follow the AMANALAP principle for test coverage:
- **Minimal**: Test only what's critical to app functionality
- **Necessary**: Focus on tests that catch real bugs, not boilerplate
- **Late**: Expand test coverage as APIs stabilize, not before

**Current Status**: 18 essential tests covering core workflows
**Future**: Expand to 50-75 tests post-beta as features mature

---

## Testing Framework

### Swift Testing (Modern)
We use **Swift Testing** framework (introduced in Swift 5.9+) instead of XCTest.

**Why Swift Testing?**
- Natural Swift syntax (`#expect` vs `XCTAssert*`)
- Better error messages
- Parameterized tests with `@Test(arguments:)`
- More expressive test organization
- Native async/await support

**Example:**
```swift
import Testing

@Test("Session saves and loads correctly")
func testSessionPersistence() throws {
    // Arrange
    let manager = PersistenceManager.shared
    let session = Session(id: UUID(), startDate: Date(), exercises: [])

    // Act
    manager.saveSessions([session])
    let loaded = manager.loadSessions()

    // Assert
    #expect(loaded.count == 1)
    #expect(loaded.first?.id == session.id)
}
```

---

## Test Organization

### Package Structure

```
IncrementProject/
├── Increment/                    # iOS app target (uses the framework)
│   └── IncrementApp.swift       # @main entry point
│
├── IncrementPackage/            # Swift Package with library + tests
│   ├── Package.swift
│   ├── Sources/
│   │   ├── IncrementFeature/    # Library code (testable)
│   │   │   ├── Models.swift
│   │   │   ├── PersistenceManager.swift
│   │   │   ├── SessionManager.swift
│   │   │   ├── SteelProgressionEngine.swift
│   │   │   └── ContentView.swift
│   │   │
│   │   └── IncrementAppEntry/   # App entry point (separate target)
│   │       └── IncrementApp.swift
│   │
│   └── Tests/
│       └── IncrementFeatureTests/
│           ├── ModelsTests.swift
│           ├── PersistenceManagerTests.swift
│           ├── SessionManagerTests.swift
│           └── SteelProgressionEngineTests.swift
```

### Target Separation

**Why separate targets?**
1. **Library target** (`IncrementFeature`): All business logic, views, models
2. **App entry target** (`IncrementAppEntry`): Only `@main` and app setup
3. **Test target** (`IncrementFeatureTests`): Depends on library, not app entry

**Benefits:**
- Tests don't include `@main` → no linker conflicts
- Library is reusable across app/tests/future extensions
- Clean separation of concerns

---

## Test Execution Methods

**Important**: We have **ONE set of tests** (18 tests in 4 files under `IncrementPackage/Tests/`), not two separate test suites. These same tests can be executed using different methods:

### 1. Swift Package Manager (Local Development)
```bash
cd increment/IncrementProject/IncrementPackage
swift test
```
- **Speed**: ~8ms for all 18 tests
- **Platform**: Runs directly on macOS host (no simulator)
- **What it tests**: Package code in `IncrementFeature` target
- **Best for**: Rapid local development iteration
- **Limitation**: Doesn't validate full iOS app integration

### 2. Xcode Workspace (CI/CD + Integration)
```bash
cd increment/IncrementProject
xcodebuild test \
  -workspace Increment.xcworkspace \
  -scheme Increment \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
- **Speed**: ~30 seconds (includes simulator boot)
- **Platform**: iOS Simulator (actual iOS environment)
- **What it tests**: Same package tests, but through the iOS app target
- **Best for**: CI/CD pipeline, pre-deployment validation
- **Advantage**: Tests the code exactly as users will run it

### 3. Xcode IDE (Interactive Debugging)
- Product → Test (⌘U)
- Test Navigator for granular control
- **Best for**: Debugging test failures, step-through execution

### Which Method to Use?

| Scenario | Method | Why |
|----------|--------|-----|
| Writing new tests | SPM (`swift test`) | Instant feedback (<1s) |
| Pre-commit check | Xcode workspace | Validates full integration |
| CI/CD pipeline | Xcode workspace | Tests deployment scenario |
| Debugging failures | Xcode IDE | Breakpoints + visual tools |

### Migration Impact (Post-October 2025)

**Before migration**:
- SPM tested package code (models, logic)
- Xcode tested iOS app with duplicated files
- These were effectively different codebases

**After migration**:
- iOS app imports `IncrementFeature` package (no duplication)
- Both methods now test the **exact same code**
- SPM tests package directly, Xcode tests package through iOS app wrapper

**CI Strategy**: We run only Xcode workspace tests in CI because they validate the full deployment path that users experience. SPM tests are available for developers who want faster local iteration.

---

## Test Coverage

### Current Coverage (18 Essential Tests)

#### 1. SteelProgressionEngine (8 tests) - **Core Algorithm**
- ✅ FAIL rating decreases weight
- ✅ HOLY_SHIT rating increases weight
- ✅ HARD/EASY ratings micro-adjust
- ✅ Bad-day switch prevents reckless increases
- ✅ Weekly load cap enforced
- ✅ Decision computation accuracy
- ✅ Plate math for barbell exercises
- ✅ Weight calculation edge cases

**Why these matter**: This is our unique IP. Bugs here = unsafe workouts.

#### 2. Models (3 tests) - **Data Integrity**
- ✅ Session Codable serialization
- ✅ ExerciseProfile Codable serialization
- ✅ SetLog Codable serialization

**Why these matter**: Data corruption = lost workout history.

#### 3. PersistenceManager (2 tests) - **Data Persistence**
- ✅ Save/load sessions
- ✅ Save/load exercise states

**Why these matter**: If persistence breaks, users lose all data.

#### 4. SessionManager (5 tests) - **Integration**
- ✅ Pre-workout → first set flow
- ✅ Complete workout end-to-end
- ✅ Set rating flow
- ✅ Bad-day rating flow
- ✅ Skip exercise flow

**Why these matter**: Ensures the full user journey works.

### What We DON'T Test (Yet)

- ❌ UI component rendering (SwiftUI views)
- ❌ Rest timer precision (standard Foundation.Timer)
- ❌ Edge cases in enums (compiler-enforced)
- ❌ Boilerplate getters/setters
- ❌ Export/import utilities (non-critical)

**Rationale**: These can be added post-beta when APIs stabilize.

---

## CI/CD Integration

### GitHub Actions Workflow
- **Triggers**: PRs to `main`, pushes to `main`
- **Runner**: `macos-15` with Xcode 16.1
- **Platform**: iOS Simulator (iPhone 16, iOS 18.4)
- **Artifacts**: Test results HTML, xcresult bundles (30-day retention)

### Workflow Configuration
```yaml
# .github/workflows/increment-tests.yml
- name: Run tests on iOS Simulator
  working-directory: increment/IncrementProject
  run: |
    xcodebuild test \
      -workspace Increment.xcworkspace \
      -scheme Increment \
      -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' \
      -resultBundlePath TestResults.xcresult \
      -enableCodeCoverage YES \
      | xcpretty --color --report html
```

### Test Failure Policy
- ❌ Failing tests **block PR merges**
- 🟡 Flaky tests are investigated and either fixed or removed
- ✅ All tests must pass before deployment

---

## Best Practices

### Writing Tests

1. **Arrange-Act-Assert Pattern**
   ```swift
   @Test("Description of what we're testing")
   func testSomething() {
       // Arrange: Set up test data
       let input = makeTestData()

       // Act: Execute the behavior
       let result = systemUnderTest.doSomething(input)

       // Assert: Verify the outcome
       #expect(result == expectedValue)
   }
   ```

2. **Descriptive Test Names**
   - ✅ Good: `@Test("FAIL rating decreases weight by 10%")`
   - ❌ Bad: `@Test("Test progression")`

3. **Comment Critical Tests**
   ```swift
   // Critical: This test ensures users never get unsafe weight recommendations
   // that could lead to injury. The bad-day switch must always prevent increases
   // when performance deteriorates.
   @Test("Bad-day switch prevents reckless increases")
   ```

4. **Use `@MainActor` When Needed**
   ```swift
   @MainActor
   @Test("Session manager updates UI state")
   func testSessionManagerState() async {
       // Test code that touches UI/Observable state
   }
   ```

### Test Data Management

- Use `setUp()` for shared test fixtures
- Prefer in-test data creation for clarity
- Use `UserDefaults(suiteName: "test")` to avoid polluting real data
- Clean up after tests: `tearDown()` or `deferCleanup`

### Debugging Failed Tests

1. **Check CI logs**: GitHub Actions artifacts have full xcresult bundles
2. **Run locally**: `swift test --verbose` for detailed output
3. **Xcode Test Navigator**: Visual debugging with breakpoints
4. **Print diagnostics**: Use `print()` liberally in tests (won't pollute prod code)

---

## Error Handling Testing

### PersistenceManager Error Handling
As of commit `54dfdec`, all JSON operations have proper error handling:

```swift
// Before (silent failures)
let data = try? encoder.encode(sessions)

// After (logged errors)
do {
    let data = try encoder.encode(sessions)
    logger.debug("Successfully saved \(sessions.count) sessions")
} catch {
    let persistenceError = PersistenceError.encodingFailed(Keys.sessions, error)
    logger.error("\(persistenceError.localizedDescription)")
}
```

**Testing Strategy:**
- ✅ Test successful encode/decode paths
- ✅ Test corrupted data handling (returns empty, logs error)
- ⏳ TODO: Test specific error cases (invalid JSON, missing keys)

---

## Future Enhancements

### Phase 2: Expand Test Coverage (Post-Beta)
- [ ] Add UI tests with SwiftUI testing APIs
- [ ] Test error recovery scenarios
- [ ] Add performance benchmarks for progression engine
- [ ] Test offline/online data sync (when implemented)
- [ ] Add mutation testing to verify test quality

### Phase 3: Advanced Testing (v2.0+)
- [ ] Snapshot testing for UI consistency
- [ ] Property-based testing for edge cases
- [ ] Load testing for large workout histories
- [ ] Integration tests with HealthKit/Apple Watch

---

## Troubleshooting

### "Duplicate symbol '_main'" Error
**Problem**: Running `swift test` fails with linker error about duplicate `_main` symbols.

**Cause**: `IncrementApp.swift` with `@main` is in the library target.

**Solution**: Use the restructured package with separate app entry target (see "Target Separation" above).

### Tests Pass Locally But Fail in CI
**Common causes**:
1. Different Xcode/Swift versions → Check CI uses same version
2. Simulator differences → Specify exact iOS version in CI
3. Timing issues → Add `async`/`await` or explicit waits
4. File paths → Use relative paths, not absolute

### Tests Are Slow
**Optimization strategies**:
1. Use `swift test` instead of `xcodebuild` for library tests
2. Run tests in parallel: `swift test --parallel`
3. Mock expensive operations (network, disk I/O)
4. Use in-memory persistence for test data

---

## References

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [Swift Package Manager - Testing](https://github.com/apple/swift-package-manager/blob/main/Documentation/Usage.md#testing)
- [WWDC 2024: Meet Swift Testing](https://developer.apple.com/videos/play/wwdc2024/10179/)
- [XCTest Migration Guide](https://developer.apple.com/documentation/testing/migratingfromxctest)

---

## Changelog

- **2025-10-01**: Initial testing strategy document
- **2025-10-01**: Added error handling testing guidelines (Issue #11)
