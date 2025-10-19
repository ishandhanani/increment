# Legacy Code Removal & Refactor Plan

## Summary

We have two parallel workout systems:
- **New (Oct 2025)**: `Lift` → `WorkoutTemplate` → Dynamic generation
- **Legacy (Sep 2025)**: `ExerciseProfile` → `WorkoutPlan` → Static definitions

Currently, the new system converts to legacy format at runtime via `WorkoutTemplateConverter`. This refactor will eliminate the conversion layer and make STEEL work directly with the new models.

## Current State (After Initial Cleanup)

### ✅ Removed
- `loadDefaultExercises()` - empty no-op
- `loadDefaultWorkoutPlan()` - empty no-op
- `SessionIntroView` now uses `startSession()` instead of `startSession(workoutPlanId:)`

### ⚠️ Kept (For Now)
- `startSession(workoutPlanId:)` - deprecated but still used by tests
- `ExerciseProfile` struct - used by STEEL and Analytics
- `WorkoutPlan` struct - used for session execution
- `WorkoutTemplateConverter` - bridges new → old

## Legacy Code Usage Analysis

### 1. ExerciseProfile Usage

**Definition**: `Models.swift:82-126`

**Used By**:
- `SteelProgressionEngine` - reads: `repRange`, `sets`, `baseIncrement`, `rounding`, `microAdjustStep`, `weeklyCapPct`, `plateOptions`
- `AnalyticsEngine.calculateVolumeByCategory()` - reads: `category` (barbell/dumbbell/machine/bodyweight)
- `SessionManager+Analytics` - reads: `name`, `category`, `priority`
- `SessionManager` - creates and stores in `exerciseProfiles: [UUID: ExerciseProfile]` dictionary
- `Session.exerciseProfilesForSession` - session-scoped storage
- `PersistenceManager` - persists/loads exercise profiles

### 2. WorkoutPlan Usage

**Definition**: `Models.swift:277-287`

**Used By**:
- `SessionManager.workoutPlans: [WorkoutPlan]` - working memory during session
- `Session.workoutPlan` - session-scoped storage
- `SessionManager` - reads `plan.order` to iterate through exercises
- `WorkoutTemplateConverter.toWorkoutPlan()` - converts from `WorkoutTemplate`
- Views - read `plan.name` for display
- PersistenceManager - persists/loads plans

### 3. WorkoutTemplateConverter Usage

**Definition**: `WorkoutTemplateConverter.swift`

**Converts**:
- `Lift` → `ExerciseProfile` (maps equipment→category, priority, adds STEEL config)
- `WorkoutTemplate` → `(WorkoutPlan, [UUID: ExerciseProfile])`

**Called By**:
- `SessionManager.resumeSession()` - line 94 (fallback if session data missing)
- `SessionManager.startWorkoutFromTemplate()` - line 325 (primary conversion)

## Refactor Strategy

### Phase 1: Make STEEL Work with SteelConfig Directly ✅ READY

**Goal**: Eliminate `ExerciseProfile` dependency in `SteelProgressionEngine`

**Changes**:
1. Update `SteelProgressionEngine.computeDecision()` signature:
   ```swift
   // OLD
   func computeDecision(setLogs: [SetLog], repRange: ClosedRange<Int>, totalSets: Int)

   // NEW (no change needed - already generic!)
   ```

2. Update `SteelProgressionEngine.computeNextSessionWeight()` signature:
   ```swift
   // OLD
   func computeNextSessionWeight(
       lastStartLoad: Double,
       decision: SessionDecision,
       baseIncrement: Double,
       rounding: Double,
       weeklyCapPct: Double,
       recentLoads: [Double],
       plateOptions: [Double]?
   )

   // NEW - accept SteelConfig
   func computeNextSessionWeight(
       lastStartLoad: Double,
       decision: SessionDecision,
       config: SteelConfig,
       recentLoads: [Double]
   )
   ```

3. Update `SessionManager.completeExercise()` to pass `SteelConfig` instead of profile fields

**Impact**: Zero - STEEL already uses only the fields in `SteelConfig`

### Phase 2: Replace WorkoutPlan with WorkoutTemplate

**Goal**: Use `WorkoutTemplate` directly instead of converting to `WorkoutPlan`

**Changes**:
1. `SessionManager.workoutPlans` → `SessionManager.currentWorkout: WorkoutTemplate?`
2. `Session.workoutPlan` → `Session.workoutTemplate: WorkoutTemplate?`
3. Update all code reading `plan.order` to read `template.exercises.sorted(by: {$0.order < $1.order})`
4. Remove `WorkoutTemplateConverter.toWorkoutPlan()`

**Impact**: Medium - touches session execution and persistence

### Phase 3: Replace exerciseProfiles Dictionary

**Goal**: Store exercise metadata inline with `WorkoutTemplate.exercises`

**Changes**:
1. Remove `SessionManager.exerciseProfiles: [UUID: ExerciseProfile]`
2. Remove `Session.exerciseProfilesForSession: [UUID: ExerciseProfile]?`
3. Store exercise lookup using `WorkoutTemplate.exercises` array
4. Update Analytics to use `Lift.equipment` instead of `ExerciseProfile.category`

**Impact**: High - requires Analytics refactor

### Phase 4: Update Analytics

**Goal**: Make analytics work with `Lift` instead of `ExerciseProfile`

**Changes**:
1. `AnalyticsEngine.calculateVolumeByCategory()`:
   ```swift
   // OLD
   func calculateVolumeByCategory(sessions: [Session], profiles: [UUID: ExerciseProfile])

   // NEW
   func calculateVolumeByCategory(sessions: [Session], template: WorkoutTemplate)
   ```

2. Map `Equipment` → categories for grouping:
   - `.barbell` → "Barbell"
   - `.dumbbell` → "Dumbbell"
   - `.machine` → "Machine"
   - `.bodyweight`, `.cable`, `.cardioMachine` → "Bodyweight"

3. Update `SessionManager+Analytics.volumeByCategory` to pass template

**Impact**: Medium - changes analytics API

### Phase 5: Update Tests

**Goal**: Refactor tests to use new workout flow

**Changes**:
1. Remove `workoutPlans.first!.id` patterns
2. Use `startSession() → logPreWorkoutFeeling() → startWorkoutFromTemplate()` flow
3. Update assertions to check `currentWorkoutTemplate` instead of `workoutPlans`

**Impact**: High - many test changes

### Phase 6: Cleanup

**Goal**: Remove all legacy code

**Delete**:
- `ExerciseProfile` struct
- `WorkoutPlan` struct
- `ExercisePriority` enum (replaced by `LiftPriority`)
- `ExerciseCategory` enum (replaced by `Equipment`)
- `WorkoutTemplateConverter.swift` entire file
- `startSession(workoutPlanId:)` deprecated method
- PersistenceManager methods for profiles/plans

**Impact**: Low - just deletion

## Migration Path

### Incremental Approach (Recommended)

1. **Week 1**: Phase 1 - STEEL refactor (minimal risk)
2. **Week 2**: Phase 2 - WorkoutPlan → WorkoutTemplate
3. **Week 3**: Phase 3 + 4 - Remove exerciseProfiles + Analytics
4. **Week 4**: Phase 5 - Update tests
5. **Week 5**: Phase 6 - Final cleanup

### Big Bang Approach (Risky)

Do all phases in one PR. Not recommended due to:
- High risk of breaking session resume
- Complex merge conflicts
- Difficult to debug if something breaks

## Testing Strategy

For each phase:
1. Run existing test suite
2. Manual test session start/resume
3. Manual test analytics dashboard
4. Check persistence (kill app, reopen)

## Questions to Answer

1. **Do we need `ExerciseCategory` at all?**
   - Analytics groups by equipment now
   - Could use `Equipment` enum directly
   - Answer: NO - can delete

2. **Do we need `ExercisePriority`?**
   - Only used by analytics for grouping
   - New system has `LiftPriority` (core/accessory)
   - Could use `MuscleGroup` for more detail
   - Answer: NO - use `LiftPriority` instead

3. **How to handle existing persisted sessions with old format?**
   - Option A: Migration script to convert old → new
   - Option B: Version check and discard old sessions
   - Option C: Keep compatibility shim for 1-2 releases
   - **Recommendation**: Option B (clean break, minimal support burden)

4. **Should `Lift` have a UUID?**
   - Currently identified by name (hashable)
   - UUIDs would allow duplicate names
   - Answer: NO - name as ID is simpler and works fine

## Success Criteria

- ✅ All tests pass
- ✅ Can start new workout session
- ✅ Can resume in-progress session
- ✅ Analytics dashboard works
- ✅ No references to `ExerciseProfile`, `WorkoutPlan`, `WorkoutTemplateConverter`
- ✅ Code is simpler and easier to understand
- ✅ No performance regression

## Estimated Effort

- **Phase 1**: 2 hours
- **Phase 2**: 4 hours
- **Phase 3**: 3 hours
- **Phase 4**: 3 hours
- **Phase 5**: 6 hours
- **Phase 6**: 1 hour

**Total**: ~19 hours (~2.5 days of focused work)
