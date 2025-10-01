# Increment — iOS Weightlifting Tracker

A terminal-inspired weightlifting tracker for fast, offline sessions with automatic progression.

## Features

### Core Functionality
- **One-tap gym flow**: Start → Warmup → Load → Set → Rate → Rest → Repeat
- **S.T.E.E.L.™ Progression**: Set-to-set Tuning + End-of-exercise Escalation/Lowering
- **Four ratings**: `FAIL`, `HOLY_SHIT`, `HARD`, `EASY`
- **Auto-progression**: Micro-adjusts within sessions and sets next session's start weight
- **Offline-first**: All data stored locally, survives app kill/refresh
- **Background-resilient timer**: Uses monotonic clock (CFAbsoluteTime) for accuracy

### Design Philosophy
- **Terminal clarity**: Monospace typography, crisp layouts, SRCL-inspired design
- **Single task at a time**: Every screen shows exactly what to do next
- **Deterministic layouts**: Fixed spacing, no surprise reflows
- **Low cognitive overhead**: Vertical scanning, context at top, action at bottom

## Project Structure

```
Increment/
├── IncrementApp.swift           # App entry point
├── ContentView.swift             # Main UI with all views (Intro, Warmup, Load, Set, Rest, Review, Done)
├── Models.swift                  # Data models (ExerciseProfile, Session, SetLog, etc.)
├── SteelProgressionEngine.swift  # S.T.E.E.L. algorithm implementation
├── SessionManager.swift          # Session state management
├── RestTimer.swift               # Background-resilient timer
├── PersistenceManager.swift      # Local storage via UserDefaults
└── Info.plist                    # iOS app configuration
```

## S.T.E.E.L.™ Progression Algorithm

**Set-to-set Tuning + End-of-exercise Escalation/Lowering**

### Within-Session Micro-Adjust
Based on rating and reps achieved, the algorithm adjusts the next set's weight:
- `FAIL` → Drop by base increment
- `HOLY_SHIT` → Hold or drop if below min reps
- `HARD` → Hold or drop by micro-step if below min reps
- `EASY` → Add micro-step if at/above max reps

**Bad-Day Switch**: If first two sets are red (FAIL/HOLY_SHIT), drop weight for remaining sets.

### End-of-Exercise Decision
Analyzes all sets to determine next session's progression:
- `up_2`: All sets at max reps with majority feeling easy
- `up_1`: Hit all targets, no failures, hit top on most sets
- `down_1`: Multiple red sets or missed targets
- `hold`: Otherwise

### Next Session Start Weight
- Applies decision (+2×, +1×, -1×, or hold base increment)
- Rounds to specified increment
- Enforces weekly cap (5-10% depending on exercise)
- Rounds to achievable plate combinations for barbells

## Session Flow

1. **Intro**: Start session button
2. **Warmup**: Ramped warmup (50%×5 → 70%×3)
3. **Load**: Shows plate breakdown per side
4. **Working Set**: Enter reps, select rating
5. **Rest**: Shows next prescription + countdown timer with -10s and NEXT controls
6. **Review**: Decision badge (UP/DOWN/HOLD) with reason
7. Repeat for all exercises
8. **Done**: Session summary with total volume

## Default Exercise Profiles

| Category | Rep Range | Sets | Base Inc | Micro | Rest | Weekly Cap |
|----------|-----------|------|----------|-------|------|------------|
| Barbell Lower | 5-8 | 3-5 | +10 lb | +5 lb | 120s | 10% |
| Barbell Upper | 5-8 | 3-5 | +5 lb | +2.5 lb | 90s | 5% |

Default exercises included:
- Barbell Bench Press (Upper)
- Barbell Squat (Lower)

## Persistence

All data is stored locally using `UserDefaults`:
- Exercise states (last start load, decision, timestamp)
- Session history
- Exercise profiles
- Workout plans
- Current session (for mid-session resume)

## Requirements

- iOS 16.0+
- SwiftUI
- Foundation
- Combine

## Building

This is a private, non-public build for personal use.

1. Open `Increment.xcodeproj` in Xcode
2. Select your development team
3. Build and run on device or simulator

## Future Enhancements (Post-MVP)

- Program builder with periodization
- Auto-warmup wizard
- PR tracking and charts
- CSV export / cloud sync
- Wearable integration
- Coach mode (share plans)

## References

- [PRD.md](./PRD.md) - Product requirements document
- [DESIGN.md](./DESIGN.md) - Design philosophy and component mapping
- [increment_storyboard.png](./increment_storyboard.png) - Visual storyboard

---

**S.T.E.E.L.™** is a trademark of Increment.