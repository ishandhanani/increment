# Increment — Product Requirements (MVP v1)

_A terminal-inspired weightlifting tracker for fast, offline sessions with auto-progression._

**Platforms:**

- **Primary:** iOS (private, non-public build).
- **Secondary (optional):** PWA/web for desktop/mobile with fully working timers and offline state.

**Storyboard:** Already saved in repo (reference it for UI look & order of screens).

---

## 1) Goals & Non-Goals

**Goals**

- One-tap, in-gym flow: warm up → load → set → rate → rest → repeat.
- Clear “what to do now”: exercise, set#, goal reps, target weight, plates.
- Four ratings: `FAIL`, `HOLY_SHIT`, `HARD`, `EASY`.
- **Auto-progression**: micro-adjust within a session + set the next session’s start weight.
- Offline-first; timers/state continue if app is backgrounded.

**Non-Goals (v1)**

- No program builder/periodization.
- No social features, public sharing, or wearable integrations.
- No cloud account (local storage is fine; export/sync later).

---

## 2) Core Flow (mirrors storyboard)

1. **Start Session** → Button `START SESSION`.
2. **Exercise Header** (always visible):

   - Name, `Set i/N`, `Goal: X reps`, `Weight: Y lb`, `Plates: …`.

3. **Warmup Stepper** → Button `NEXT WARMUP WEIGHT »` (cycles 50%×5 → 70%×3 → Start).
4. **Load Step** → Button `LOAD PLATES`.
5. **Rate Set** (working sets): Vertical buttons (top→bottom): `FAIL`, `HOLY_SHIT`, `HARD`, `EASY`.

   - Reps entry prefilled to goal; editable inline.

6. **Rest Screen**:

   - `Next: X × Y lb`, `Rest: MM:SS`, controls: `-10s` and `NEXT →` (advance early).

7. **End Exercise**: Decision badge `UP +Δ`, `HOLD`, or `DOWN −Δ` with one-line reason.
8. **End Session**: Summary; persist offline.

---

## 3) Information Architecture (v1)

> Pseudotypes; not language-specific.

- **ExerciseProfile**

  - `id, name`
  - `category`: barbell | dumbbell | machine | bodyweight
  - `priority`: upper | lower | accessory
  - `repRange`: [min, max]
  - `sets`: integer
  - `baseIncrement`: number (**total** load step; e.g., +5 lb for bench)
  - `rounding`: number (e.g., 2.5)
  - `microAdjustStep?`: number (small intra-session step; optional)
  - `weeklyCapPct`: number (5–10)
  - `plateOptions?`: list[number] (per-side plates; barbell only)
  - `warmupRule`: “ramped_2” (50%×5 → 70%×3)
  - `defaultRestSec`: number (e.g., 90)

- **ExerciseState**

  - `exerciseId`
  - `lastStartLoad`: number
  - `lastDecision`: up | hold | down | null
  - `lastUpdatedAt`: timestamp

- **SetLog**

  - `setIndex`: 1..N
  - `targetReps`, `targetWeight`
  - `achievedReps`, `rating`
  - `actualWeight`
  - `restPlannedSec?`

- **ExerciseSessionLog**

  - `exerciseId`, `startWeight`
  - `setLogs`: list[SetLog]
  - `sessionDecision`: up_2 | up_1 | hold | down_1
  - `nextStartWeight`

- **Session**

  - `id`, `date`, `workoutPlanId`
  - `exerciseLogs`: list[ExerciseSessionLog]
  - `stats`: { totalVolume }
  - `synced`: boolean

- **WorkoutPlan**

  - `id`, `name`, `order`: list[exerciseId]

---

## 4) The Progression Algorithm — **S.T.E.E.L.™**

**S**et-to-set **T**uning + **E**nd-of-exercise **E**scalation/**L**owering.
Two layers: (A) _within session micro-adjust_, (B) _across session decision_.

### 4A) Ratings (semantics)

- `EASY` → ~RIR 3+
- `HARD` → RIR 1–2 (target zone)
- `HOLY_SHIT` → RIR 0 (max effort)
- `FAIL` → missed target/terminated early

### 4B) Within-Session Micro-Adjust (affects “Next:” on Rest screen)

**Inputs**:
`W` (current weight), `r` (achieved reps), `range [rMin, rMax]`, `rating`, profile `{inc=baseIncrement, micro=microAdjustStep, round=rounding}`.

**Rules (evaluate in this order):**

1. **FAIL** → next `W' = round(W − inc)`; next reps target = `rMin`.
2. **HOLY_SHIT** → if `r < rMin`, next `W' = round(W − inc)`; else **hold** (`W' = W`).
3. **HARD** → if `r < rMin` and `micro` exists, next `W' = round(W − micro)`; else **hold**.
4. **EASY** → if `r ≥ rMax` and `micro` exists, next `W' = round(W + micro)`; else **hold**.

**Bad-Day Switch (safety):**
If first **two** working sets are red (`FAIL` or `HOLY_SHIT`), drop `W` by `inc` for remaining sets and aim `rMin`.

### 4C) End-of-Exercise Decision (sets next session start weight)

**Counters** from set logs:

- `S_red` = # of (`HOLY_SHIT` or `FAIL`)
- `S_hit_top` = # of (reps ≥ `rMax` **and** rating ≠ `HOLY_SHIT`)
- `S_meet` = # of (reps ≥ `rMin` **and** rating ≠ `FAIL`)
- `S_easyTop` = # of (reps ≥ `rMax` **and** rating == `EASY`)

**Decision:**

- **up_2** if: _all_ sets == `rMax` **and** `S_easyTop ≥ sets/2`.
- **up_1** if: `S_meet == sets` **and** `S_red == 0` **and** `S_hit_top ≥ sets − 1`.
- **down_1** if: `S_red ≥ 2` **or** `S_meet < sets − 1`.
- **hold** otherwise.

### 4D) Next-Session Start Weight

Let `W_prev = lastStartLoad`, `inc = baseIncrement`.

- `up_2` → `W0 = W_prev + 2*inc`
- `up_1` → `W0 = W_prev + inc`
- `down_1` → `W0 = W_prev − inc`
- `hold` → `W0 = W_prev`

Then:

1. **Round** to `rounding`.
2. **Weekly cap**: cumulative increase over last 7 days ≤ `weeklyCapPct` (if exceeded, downgrade to max allowed or hold).
3. **Plate math** for barbells (per-side using `plateOptions`).

---

## 5) Rest Timer Requirements

- Default per exercise (`defaultRestSec`), shown as `Rest: MM:SS`.
- Timer starts immediately after rating.
- Controls: `-10s` (floor at 0), `NEXT →` (advance early).
- If app is backgrounded or screen locks, timer resumes correctly (use monotonic elapsed time).
- At 0, show a subtle “Ready” state; _no auto-advance_ (advance is explicit via `NEXT →`).

---

## 6) Defaults (ship ready)

| Category             | Rep Range | Sets | baseInc (total) | micro (total) | defaultRest | weeklyCap |
| -------------------- | --------- | ---- | --------------- | ------------- | ----------- | --------- |
| Barbell Lower        | 5–8       | 3–5  | +10 lb          | +5 lb         | 120s        | 10%       |
| Barbell Upper        | 5–8       | 3–5  | +5 lb           | +2.5 lb       | 90s         | 5%        |
| Dumbbell Compounds   | 6–10      | 3–4  | +5 lb (pair)    | +2.5 lb pair  | 90s         | 7%        |
| Accessories (Pin/DB) | 10–15     | 2–4  | smallest step   | —             | 60s         | 5%        |

_Note: “total” means on-bar total (not per side) or per pair for dumbbells._

---

## 7) Acceptance Criteria

**Flow & UI**

- Start → Warmup → Load → Rate → Rest → Repeat → End Exercise decision → Next Exercise → End Session.
- Header always shows Name, `Set i/N`, `Goal`, `Weight`, `Plates`.
- Rate buttons exactly in order: `FAIL`, `HOLY_SHIT`, `HARD`, `EASY`.

**Algorithm (S.T.E.E.L.™)**

- Micro-adjust updates the **Next** prescription shown on the Rest screen according to 4B.
- Decision badge derived exactly by 4C.
- Next-session start weight computed by 4D with rounding, weekly cap, and plate math.

**Timer/State**

- Rest timer continues correctly across background/lock.
- `-10s` and `NEXT →` behave as specified.
- No auto-advance; user explicitly proceeds.

**Persistence**

- All logs stored locally; survive app kill/refresh.
- Resume mid-exercise at last completed set.

**Barbell Plate Math**

- Per-side breakdown matches target weight with available plates; show minimal plate count solution.

---

## 8) Telemetry (local, queued for later export)

- `session_started`, `exercise_started`, `warmup_advanced`, `plates_loaded`,
- `set_logged` (reps, rating, weight), `rest_started`, `rest_skipped`,
- `exercise_decision`, `session_completed`.

---

## 9) Edge Cases

- Weight floor: never below empty bar or 0 (machines).
- Coarse pin steps: rely on rep progression before `up_1`; allow `up_2` only if cap permits.
- Consecutive rough sessions: if result is `down_1/hold` **three** times, suggest a manual deload (−5–10%).
- First two sets both red → activate Bad-Day Switch (see 4B).

---

## 10) Platform Notes

- **iOS (preferred):** SwiftUI app with local persistence. Use a background-resilient timer (monotonic clock / CFAbsoluteTime).
- **PWA/Web (optional):** Offline cache + IndexedDB; use `performance.now()` for timers and restore from persisted timestamps.

---

## 11) Future (post-MVP)

- Program builder (blocks, %e1RM, deload templates).
- Auto-warmup wizard with plate math.
- PRs/charts (best set e1RM, weekly volume).
- Export/Cloud sync; CSV.
- Wearables & haptics; auto rest detection.
- Coach mode (share plan, read-only).

---

## Appendix — Pseudocode (language-agnostic)

> For the coding agent; **pseudocode only**.

### A) Micro-Adjust (S.T.E.E.L. — within session)

```
function microAdjust(W, r, rMin, rMax, rating, inc, micro, round):
  if rating == FAIL:
    return round(max(0, W - inc)), nextReps = rMin

  if rating == HOLY_SHIT:
    if r < rMin:
      return round(max(0, W - inc)), nextReps = rMin
    else:
      return W, nextReps = clamp(goal, rMin, rMax)

  if rating == HARD:
    if r < rMin and micro > 0:
      return round(max(0, W - micro)), nextReps = rMin
    else:
      return W, nextReps = clamp(goal, rMin, rMax)

  if rating == EASY:
    if r >= rMax and micro > 0:
      return round(W + micro), nextReps = rMax
    else:
      return W, nextReps = clamp(goal, rMin, rMax)
```

**Bad-Day Switch**

```
if firstTwoSetsAreRed:
  drop current W by inc for remaining sets
  set target reps = rMin
```

### B) End-of-Exercise Decision (S.T.E.E.L. — across session)

```
S_red     = count(HOLY_SHIT or FAIL)
S_hit_top = count(reps >= rMax and rating != HOLY_SHIT)
S_meet    = count(reps >= rMin and rating != FAIL)
S_easyTop = count(reps >= rMax and rating == EASY)

if all sets == rMax and S_easyTop >= sets/2:
  decision = up_2
else if S_meet == sets and S_red == 0 and S_hit_top >= sets - 1:
  decision = up_1
else if S_red >= 2 or S_meet < sets - 1:
  decision = down_1
else:
  decision = hold
```

### C) Next-Session Start Weight

```
W0 = lastStartLoad
if decision == up_2:  W0 += 2*inc
if decision == up_1:  W0 += 1*inc
if decision == down_1:W0 -= 1*inc
W0 = round(W0)

if weeklyIncreasePct(W0) > weeklyCapPct:
  W0 = maxAllowedUnderCapOrHold()

if isBarbell:
  plates = computePerSidePlates(W0, plateOptions)
```

---

**Name to reference everywhere:** **S.T.E.E.L.™ Progression** (Set-to-set Tuning + End-of-exercise Escalation/Lowering).
