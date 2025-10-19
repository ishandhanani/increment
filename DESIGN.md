# design.md — Increment (MVP v1)

> Terminal-inspired, single-user lifting app. This document defines the visual language, UI components, and interaction rules that the build must follow. It is scoped to the v1 storyboard and **S.T.E.E.L.™** progression.

---

## 1) Design Philosophy

- **Terminal clarity.** Monospace first, crisp line heights, understated chrome. The UI is an interface, not a poster. SRCL is built for “terminal aesthetics” and precise monospace spacing—use that as the baseline. ([Sacred Computer][1])
- **Single task at a time.** Every screen answers “what do I do now?” and exposes exactly one primary action.
- **Deterministic layouts.** Strict grid, fixed paddings, no surprise reflows. SRCL exposes theme/grid affordances explicitly. ([Sacred Computer][1])
- **Affordance over ornament.** Use SRCL components that look like UI (action bars, lists, loaders), not illustrations. SRCL provides action bars/lists, loaders and other terminal-style primitives. ([Sacred Computer][1])
- **Low cognitive overhead.** Vertical scanning; top-left shows context, bottom houses the action bar.

---

## 2) UI Library Adoption (SRCL)

### 2.1 What we’re using

- **Typography & grid:** SRCL’s monospace typography and grid utilities; keep default line height/character rhythm. (SRCL positions itself around monospace precision.) ([GitHub][2])
- **Action Bar:** For bottom navigation/primary actions per screen. ([Sacred Computer][1])
- **Action List / Buttons:** For the four difficulty ratings as a stacked, single-column list. ([Sacred Computer][1])
- **Input & Form:** For reps input and any inline fields. ([Sacred Computer][1])
- **Loaders:**

  - **Bar Loader** for linear progress moments (optional),
  - **Block Loader** for micro feedback. ([Sacred Computer][1])

- **Alert Banner:** For deload/weekly-cap notices (rare). ([Sacred Computer][1])

### 2.2 What we’re not using (v1)

- Avatars, dropdowns, breadcrumbs, blog/post patterns—out of scope for MVP. (SRCL provides them; we defer.) ([Sacred Computer][1])

---

## 3) Visual Language

### 3.1 Type

- **Family:** SRCL monospace default (no overrides).
- **Scale:** Only three sizes:

  - **H1 (header strip):** Exercise name & right-column stats.
  - **Body:** Content panel.
  - **Caption:** Plate math & helper text.

- **Weight:** Regular. Use bold only in header labels (“Set”, “Goal”, “Weight”, “Plates”).

### 3.2 Color

- **Palette:** Dark/blue terminal panel background, high-contrast white text, subtle borders.
- **Semantic accents:**

  - **Primary:** Action buttons, timers.
  - **Status:** `FAIL` (danger), `HOLY_SHIT` (warning), `HARD` (primary), `EASY` (success).

- All colors must come from SRCL theme tokens when available (do **not** hardcode). SRCL supports theme control (Theme / Grid affordances). ([Sacred Computer][1])

### 3.3 Spacing & Grid

- **Unit:** Fixed 8-point rhythm (or SRCL’s default step).
- **Containers:** 24px outer padding; 16px internal gutters; 12px inter-control spacing.

### 3.4 Iconography

- Minimal; only for timer play/pause and optional rating glyphs. Prefer ASCII-like forms where possible to match SRCL idiom.

---

## 4) Layout Patterns (per storyboard)

> All screens share a **three-band layout**:
> **Header** (context) → **Panel** (content) → **Action Bar** (primary action).

### 4.1 Header (persistent spec)

- **Left:** Exercise name (monospace), never truncates below 2 lines.
- **Right (column):**

  - `Set: i of N`
  - `Goal: rMin–rMax` _or_ `Goal: X reps`
  - `Weight: Y lb` (on-bar total or per-pair for DB)
  - `Plates: 45 | 5 | 2.5` (per-side for barbells)

### 4.2 Panels

- **Start Session:** Empty panel with terminal border; prominent `START SESSION` in Action Bar (secondary “New Workout” inline).
- **Warmup Stepper:** Centered line stating next warmup prescription; primary action `NEXT WARMUP WEIGHT »`.
- **Load Step:** Plate math as a short list; optional small block loader while recalculating.
- **Rate Set:**

  - Reps field (inline) above the rating list.
  - **Action List** of four stacked options in this exact vertical order: `FAIL`, `HOLY_SHIT`, `HARD`, `EASY`. (Use SRCL Action List/Buttons.) ([Sacred Computer][1])

- **Rest:** Two-line center:

  - `Next: X × Y lb`
  - `Rest: MM:SS`
  - Bottom controls: `-10s` (left) and `NEXT →` (right).

- **End Exercise:** Badge row with decision (`UP +Δ`, `HOLD`, `DOWN −Δ`) and one-line reason; primary action = “NEXT EXERCISE”.

### 4.3 Action Bar (global)

- Always present; houses the one thing you should do next (or the two rest controls on the Rest screen). SRCL Action Bar is the base. ([Sacred Computer][1])

---

## 5) Interaction Rules

### 5.1 Timers

- Use a **monotonic timer** (never based on frame cadence). Resume accurately after background/lock.
- On Rest:

  - Start when a rating is logged.
  - `-10s` decrements, floored at 0.
  - `NEXT →` advances immediately.
  - At 0: show subtle “Ready” state (no auto-advance).

### 5.2 Input

- Reps field defaults to the target; stepper arrows optional; direct numeric edit allowed.
- Tapping a rating:

  1. Log set.
  2. Compute **S.T.E.E.L.™ micro-adjust** for the next prescription.
  3. Navigate to Rest with `Next: …` populated.

### 5.3 Safety & Feedback

- First two sets red → **Bad-Day Switch** banner (SRCL Alert Banner), then auto-adjust loads. ([Sacred Computer][1])
- Weekly cap hit → passive Alert Banner; convert excess “up” to “hold”.

---

## 6) Component Mapping (SRCL ↔ Increment)

| App Element         | SRCL Primitive                        | Notes                                                                         |
| ------------------- | ------------------------------------- | ----------------------------------------------------------------------------- |
| Header strip        | Typography + Grid                     | Keep two-column structure; no icons. ([Sacred Computer][1])                   |
| Bottom action area  | **Action Bar**                        | Single primary action per screen. ([Sacred Computer][1])                      |
| Rating stack        | **Action List** or **Action Buttons** | Four full-width items, vertical, ordered as specified. ([Sacred Computer][1]) |
| Reps entry          | **Input** / **Form**                  | Inline; monospace caret. ([Sacred Computer][1])                               |
| Rest countdown      | **Bar Loader** (optional) + Text      | Prefer numeric timer; loader is supplemental. ([Sacred Computer][1])          |
| Tiny activity hints | **Block Loader**                      | Use sparingly. ([Sacred Computer][1])                                         |
| System notices      | **Alert Banner**                      | Deload/Cap messages only. ([Sacred Computer][1])                              |

---

## 7) State & Navigation (pseudocode)

> No implementation, just deterministic states the UI must render.

```
STATE = INTRO | WARMUP | LOAD | WORKING_SET | REST | REVIEW | DONE

INTRO:
  show START SESSION
  next -> WARMUP (exercise 1)

WARMUP:
  header shows Set 0/N
  action: NEXT WARMUP WEIGHT » until warmups exhausted
  next -> LOAD

LOAD:
  show plates for startWeight
  primary: LOAD PLATES (acknowledge)
  next -> WORKING_SET (set 1)

WORKING_SET:
  header shows Set i/N, Goal, Weight, Plates
  reps input (prefill target)
  rating list [FAIL, HOLY_SHIT, HARD, EASY]
  on rating:
    log set; compute microAdjust; set nextPrescription
    next -> REST

REST:
  show Next: reps × weight and Rest: MM:SS
  controls: -10s | NEXT →
  when NEXT or time=0:
    if i < N -> WORKING_SET (set i+1)
    else -> REVIEW

REVIEW:
  show decision badge (up_2 | up_1 | hold | down_1) + reason
  primary: NEXT EXERCISE or END SESSION
  if more exercises -> WARMUP (next exercise)
  else -> DONE

DONE:
  show session summary; offer back to INTRO
```

---

## 8) Copy & Tone

- Monospace, sentence case, short and literal.
- Header labels are nouns: **Set**, **Goal**, **Weight**, **Plates**.
- Decision reasons are one line: “3/3 sets at top, no red sets.”

---

## 9) Accessibility

- **Contrast:** Meet WCAG AA on all text over panel blue.
- **Targets:** Minimum 44×44 pt for all tappable elements (ratings, timer buttons).
- **Focus:** Visible focus ring states using SRCL defaults.
- **Semantics:** List semantics for Action List; progress semantics for timers/loaders.

---

## 10) Platform Notes

- **iOS (primary):**

  - SwiftUI surfaces must visually match SRCL (monospace, borders, spacing).
  - Haptics: light impact on rating tap; success haptic at Rest=0.
  - Background timer: monotonic time source; restore on foreground.

- **Web/PWA (secondary):**

  - Use SRCL directly; service worker for offline; IndexedDB for state.
  - Timers use `performance.now()` for accuracy after tab sleep.

---

## 11) Data shown on each screen (strict)

- **Intro:** App title; `START SESSION`.
- **Warmup:** `Set 0/N`, `Goal`, `Start Weight`, `Next warmup prescription`, `NEXT WARMUP WEIGHT »`.
- **Load:** `Plates` per side, `LOAD PLATES`.
- **Working Set:** `Set i/N`, `Goal`, `Weight`, `Plates`, editable `Reps`, ratings stack.
- **Rest:** `Next: reps × weight`, `Rest: MM:SS`, `-10s`, `NEXT →`.
- **End Exercise:** Decision badge + reason; CTA to continue.
- **End Session:** Totals + per-exercise decisions.

---

## 12) S.T.E.E.L.™ in the UI (reference hooks)

- **Within-session (micro-adjust):** Rest screen must reflect the computed `Next:` immediately after rating.
- **Across-session:** End-exercise badge reflects decision, and the next session’s **start weight** will derive from it (shown on the next visit to that exercise).
- **Bad-Day Switch:** If triggered, display an Alert Banner and adjust subsequent sets accordingly. (Banner style from SRCL.) ([Sacred Computer][1])

---

## 13) Telemetry (local only, queued)

- `warmup_advanced`, `plates_loaded`, `set_logged` (rating, reps, weight),
  `rest_started`, `rest_skipped`, `exercise_decision`, `session_completed`.

---

## 14) Deliverables Checklist

- [ ] SRCL styles included; monospace verifies across iOS/Web. ([GitHub][2])
- [ ] Screens mirror the storyboard order and content fields.
- [ ] Action Bar present on all screens with single clear primary action. ([Sacred Computer][1])
- [ ] Rating list uses SRCL Action List/Buttons with required order. ([Sacred Computer][1])
- [ ] Timer behavior matches Section 5.1 exactly.
- [ ] S.T.E.E.L.™ hooks are implemented (micro-adjust → Rest; decision → Review).
- [ ] Accessibility targets and contrast verified.

---

### Sources

- SRCL overview & component catalog (terminal aesthetics; action bar/list; loaders; forms/inputs). ([Sacred Computer][1])
- SRCL repo (monospace precision; component/style repository). ([GitHub][2])

> This file is the single source of truth for UI behavior and component choices for MVP. If a question arises, prefer SRCL primitives and this spec’s “one primary action” rule.

[1]: https://www.sacred.computer/ "srcl"
[2]: https://github.com/internet-development/www-sacred "GitHub - internet-development/www-sacred: SRCL is an open-source React component and style repository that helps you build web applications, desktop applications, and static websites with terminal aesthetics."
