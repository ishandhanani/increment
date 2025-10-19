# Session Flow Redesign - Database as Source of Truth

## Current Problems
1. ❌ Session only persisted AFTER pre-workout feeling
2. ❌ If you quit early, nothing is saved
3. ❌ No way to know if workout is "in progress" vs "just browsing"
4. ❌ Complex async/sync persistence logic
5. ❌ Database is empty despite "persistence" code

## New Architecture

### Core Principle
**Database is the SINGLE source of truth. Every state transition writes to DB immediately (synchronously).**

### Flow Redesign

```
INTRO VIEW (sessionState = .intro)
│
├─ No active session in DB
│  └─> Show: START WORKOUT button
│
└─ Active session in DB (isActive=true, lastUpdated < 24h)
   └─> Show: RESUME / DISCARD buttons

┌──────────────────────────────────────────────────────┐
│ User taps START WORKOUT                              │
│ NO DB WRITE YET                                      │
└──────────────────────────────────────────────────────┘
                    ↓
WORKOUT TYPE SELECTION (new screen, sessionState = .workoutSelection)
│
├─ Query DB: SELECT lastCompletedType FROM sessions WHERE date = MAX(date)
├─ Calculate next: push -> pull -> legs -> cardio -> push
├─ Show: "Today's workout: PULL DAY"
│         [← CANCEL]  [START PULL WORKOUT →]
│
├─ User taps CANCEL
│  └─> Go back to intro, NO DB WRITE
│
└─ User taps START PULL WORKOUT
   ┌──────────────────────────────────────────────────┐
   │ 🔴 CRITICAL: FIRST DB WRITE                     │
   │ INSERT INTO sessions (id, isActive=1, ...)      │
   │ sessionState = .preWorkout                       │
   └──────────────────────────────────────────────────┘
                    ↓
PRE-WORKOUT FEELING (.preWorkout)
│ [QUIT button in corner]
│ User rates feeling 1-5
│
└─ User submits
   ┌──────────────────────────────────────────────────┐
   │ UPDATE sessions SET preWorkoutFeeling=X          │
   │ sessionState = .workoutOverview                  │
   └──────────────────────────────────────────────────┘
                    ↓
WORKOUT OVERVIEW (.workoutOverview)
│ [QUIT button]
│ Shows: Pull Day - 5 exercises
│
└─ User taps START
   ┌──────────────────────────────────────────────────┐
   │ UPDATE sessions SET sessionStateRaw='stretching' │
   └──────────────────────────────────────────────────┘
                    ↓
STRETCHING (.stretching)
│ [QUIT button]
│ 5-minute timer
│
└─ Timer completes OR skip
   ┌──────────────────────────────────────────────────┐
   │ UPDATE sessions SET sessionStateRaw='warmup:0'   │
   └──────────────────────────────────────────────────┘
                    ↓
   ... and so on for every state transition
```

### Database Schema (Current - Already Good)

```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    date REAL NOT NULL,
    preWorkoutFeeling BLOB,
    isActive INTEGER NOT NULL DEFAULT 1,  -- ← KEY FIELD
    sessionStateRaw TEXT,                  -- ← STATE TRACKING
    currentExerciseIndex INTEGER,
    currentSetIndex INTEGER,
    currentExerciseLog BLOB,
    lastUpdated REAL NOT NULL,            -- ← STALENESS CHECK
    workoutTemplate BLOB,
    ...
);
```

### Session States & Persistence

| State                | Persisted? | DB Update                                    |
|----------------------|------------|----------------------------------------------|
| `.intro`             | No         | N/A                                          |
| `.workoutSelection`  | No         | N/A (just browsing)                         |
| `.preWorkout`        | **YES**    | INSERT new session, isActive=1              |
| `.workoutOverview`   | **YES**    | UPDATE sessionStateRaw, workoutTemplate     |
| `.stretching`        | **YES**    | UPDATE sessionStateRaw='stretching:300'     |
| `.warmup(step)`      | **YES**    | UPDATE sessionStateRaw='warmup:X'           |
| `.workingSet`        | **YES**    | UPDATE sessionStateRaw, currentSetIndex     |
| `.rest(time)`        | **YES**    | UPDATE sessionStateRaw='rest:X'             |
| `.review`            | **YES**    | UPDATE sessionStateRaw, exerciseLogs        |
| `.done`              | **YES**    | UPDATE isActive=0                           |

### Code Changes

#### 1. SessionManager Refactor

```swift
@Observable
@MainActor
public class SessionManager {
    public var sessionState: SessionState = .intro

    // MARK: - Session Lifecycle

    /// Query DB to check if resumable session exists
    public var hasResumableSession: Bool {
        guard isInitialized else { return false }

        // Query DB synchronously
        if let session = PersistenceManager.shared.loadCurrentSessionSync() {
            return session.isActive && !PersistenceManager.shared.isSessionStale(session)
        }
        return false
    }

    /// Show workout type selection (no DB write)
    public func showWorkoutSelection() {
        // Query last workout type from DB
        let sessions = PersistenceManager.shared.loadSessionsSync()
        let lastType = sessions.first?.workoutTemplate?.workoutType
        let nextType = lastType?.next ?? .push

        // Store in memory only
        currentWorkoutType = nextType
        sessionState = .workoutSelection
    }

    /// User confirmed - start workout and persist immediately
    public func confirmWorkoutStart(type: LiftCategory) {
        // Generate template
        currentWorkoutTemplate = WorkoutBuilder.build(type: type)

        // Create session
        let session = Session(
            workoutTemplate: currentWorkoutTemplate,
            isActive: true
        )
        currentSession = session

        // 🔴 IMMEDIATE DB WRITE (sync)
        PersistenceManager.shared.saveCurrentSessionSync(session)
        var sessions = PersistenceManager.shared.loadSessionsSync()
        sessions.append(session)
        PersistenceManager.shared.saveSessionsSync(sessions)

        // Move to pre-workout
        sessionState = .preWorkout
    }

    /// Every state transition calls this
    private func persistCurrentState() {
        guard var session = currentSession else { return }

        session.sessionStateRaw = serializeSessionState(sessionState)
        session.currentExerciseIndex = currentExerciseIndex
        session.currentSetIndex = currentSetIndex
        session.currentExerciseLog = currentExerciseLog
        session.lastUpdated = Date()

        // Mark inactive if done
        if case .done = sessionState {
            session.isActive = false
        }

        currentSession = session

        // 🔴 SYNC WRITE (critical path)
        PersistenceManager.shared.saveCurrentSessionSync(session)

        // Update history
        var sessions = PersistenceManager.shared.loadSessionsSync()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        PersistenceManager.shared.saveSessionsSync(sessions)
    }
}
```

#### 2. Add New State

```swift
public enum SessionState: Equatable {
    case intro
    case workoutSelection(suggestedType: LiftCategory)  // NEW
    case preWorkout
    case workoutOverview
    // ... rest unchanged
}
```

#### 3. PersistenceManager - Add Sync Methods

Already done! We have:
- `saveCurrentSessionSync()`
- `saveSessionsSync()`
- `loadSessionsSync()`
- `loadCurrentSessionSync()` (needs to be added)

#### 4. New View: WorkoutSelectionView

```swift
struct WorkoutSelectionView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack {
            Text("TODAY'S WORKOUT")
            Text(sessionManager.suggestedWorkoutType.displayName)
                .font(.largeTitle)

            HStack {
                Button("CANCEL") {
                    sessionManager.cancelWorkoutSelection()
                }

                Button("START WORKOUT") {
                    sessionManager.confirmWorkoutStart()
                }
            }
        }
    }
}
```

#### 5. Add Quit Button to All Views

```swift
struct PreWorkoutView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("QUIT") {
                    sessionManager.quitWorkout()
                }
            }
            // ... rest of view
        }
    }
}

extension SessionManager {
    public func quitWorkout() {
        // Keep session active so it can be resumed
        sessionState = .intro
        // Session stays in DB with isActive=true
    }
}
```

### Testing the Fix

1. Launch app
2. Tap START WORKOUT → goes to workout selection
3. Query DB: `SELECT * FROM sessions` → should be empty
4. Tap START PULL WORKOUT
5. Query DB: `SELECT * FROM sessions` → should have 1 row, isActive=1
6. Force quit app
7. Relaunch
8. Should show RESUME button

### Migration Plan

1. ✅ Add sync methods to PersistenceManager/DatabaseManager
2. ⬜ Add `WorkoutSelectionView`
3. ⬜ Update `SessionState` enum
4. ⬜ Refactor `SessionManager.startSession()` → `showWorkoutSelection()` + `confirmWorkoutStart()`
5. ⬜ Add `persistCurrentState()` calls to every state transition
6. ⬜ Add QUIT button to all workout views
7. ⬜ Test persistence at each step

### Benefits

✅ Database is always up-to-date
✅ Resume works reliably
✅ Can quit at any point and resume
✅ Clear separation: browsing vs committed workout
✅ Sync writes = no data loss on force quit
✅ Simpler mental model
