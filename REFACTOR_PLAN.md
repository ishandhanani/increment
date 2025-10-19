# Legacy Code Removal & Refactor Plan

## ✅ PHASES 1 & 2 COMPLETE!

### What We Accomplished

**Phase 1 - STEEL Refactor** ✅
- Refactored `SteelProgressionEngine.computeNextSessionWeight()` to accept `SteelConfig` instead of individual parameters
- Cleaner API, no functional changes

**Phase 2 - WorkoutPlan Elimination** ✅
- Completely removed `WorkoutPlan` struct
- Session now stores `WorkoutTemplate` directly
- Removed `SessionManager.workoutPlans` array
- Removed deprecated `Session.workoutPlanId` and `Session.workoutPlan` properties
- Removed deprecated `startSession(workoutPlanId:)` method
- Cleaned up `PersistenceManager` (removed save/load WorkoutPlan methods)
- Renamed `WorkoutTemplateConverter.toWorkoutPlan()` → `toExerciseProfiles()`
- All code now uses `template.exercises` instead of `plan.order`

### Current Architecture (After Cleanup)

```
User Flow:
1. startSession() → creates empty Session
2. logPreWorkoutFeeling() → generates WorkoutTemplate dynamically via WorkoutBuilder
3. startWorkoutFromTemplate() → converts to ExerciseProfiles, stores both in Session
4. Exercise execution → uses ExerciseProfile for STEEL calculations
5. Session persistence → stores WorkoutTemplate + ExerciseProfiles

Data Flow:
WorkoutTemplate (source of truth)
    ↓
WorkoutTemplateConverter.toExerciseProfiles()
    ↓
[UUID: ExerciseProfile] (for STEEL compatibility)
```

### What's Still Legacy

**Still Using:**
- `ExerciseProfile` struct - used by STEEL and Analytics
- `exerciseProfiles: [UUID: ExerciseProfile]` dictionary - for STEEL lookups
- `WorkoutTemplateConverter` - converts template → profiles
- `ExerciseCategory` enum - used by Analytics
- `ExercisePriority` enum - used by Analytics

**Why:** STEEL algorithm and Analytics still depend on ExerciseProfile. This is Phase 3+4 work.

## Remaining Phases (Future Work)

### Phase 3: Remove exerciseProfiles Dictionary

**Goal:** Store exercise metadata inline with WorkoutTemplate.exercises

**Changes:**
1. Remove `SessionManager.exerciseProfiles` dictionary
2. Remove `Session.exerciseProfilesForSession`
3. Look up exercises directly from `WorkoutTemplate.exercises` array
4. Use lift name as the key instead of UUID

**Impact:** Medium - requires updating all exercise lookups

### Phase 4: Update Analytics

**Goal:** Make Analytics work with `Lift` instead of `ExerciseProfile`

**Changes:**
1. `AnalyticsEngine.calculateVolumeByCategory()` uses `Lift.equipment` instead of `ExerciseProfile.category`
2. Map Equipment → display categories
3. Remove dependency on ExerciseCategory enum

**Impact:** Medium - changes analytics API

### Phase 5: Update Tests

**Goal:** Refactor tests to use new workout flow

**Changes:**
1. Remove all `workoutPlans.first!.id` patterns
2. Use `startSession() → logPreWorkoutFeeling() → startWorkoutFromTemplate()` flow
3. Update assertions to check `currentWorkoutTemplate`

**Impact:** High - many test changes needed

### Phase 6: Final Cleanup

**Goal:** Remove all remaining legacy code

**Delete:**
- `ExerciseProfile` struct
- `ExercisePriority` enum
- `ExerciseCategory` enum
- `WorkoutTemplateConverter.swift` (entire file)
- PersistenceManager methods for exerciseProfiles

**Impact:** Low - just deletion

## Benefits Achieved So Far

✅ Eliminated WorkoutPlan → WorkoutTemplate conversion layer
✅ Single source of truth (WorkoutTemplate)
✅ Cleaner SessionManager (no workoutPlans array)
✅ Simpler data model
✅ Zero backward compatibility baggage
✅ All builds succeed

## Estimated Remaining Effort

- **Phase 3**: 3 hours
- **Phase 4**: 3 hours
- **Phase 5**: 6 hours
- **Phase 6**: 1 hour

**Total Remaining**: ~13 hours (~1.5 days)

---

## Commit History

1. **Initial Cleanup** - Removed empty no-op methods, updated SessionIntroView
2. **Phase 1 & 2** - STEEL refactor + WorkoutPlan elimination (with deprecations)
3. **Final Cleanup** - Removed all backward compatibility code

---

**Status**: Ready for Phase 3 whenever you want to continue! 🚀
