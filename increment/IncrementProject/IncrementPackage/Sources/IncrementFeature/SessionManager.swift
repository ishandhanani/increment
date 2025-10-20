import Foundation
import Combine
import Observation
import OSLog

/// Manages the current workout session state
@Observable
@MainActor
public class SessionManager {
    // MARK: - Observable State

    public var currentSession: Session?
    public var currentExerciseIndex: Int = 0
    public var currentSetIndex: Int = 0
    public var sessionState: SessionState = .intro
    public var currentExerciseLog: ExerciseSessionLog?
    public var nextPrescription: (reps: Int, weight: Double)?
    public var isFirstExercise: Bool = true
    public var isInitialized: Bool = false

    // MARK: - Data

    public var exerciseProfiles: [String: ExerciseProfile] = [:]  // Keyed by exercise name
    public var exerciseStates: [String: ExerciseState] = [:]  // Keyed by exercise name

    // Workout system
    public var workoutCycle: WorkoutCycle?
    public var currentWorkoutTemplate: WorkoutTemplate?
    public var suggestedWorkoutType: LiftCategory = .push  // For workout selection screen

    // Timer management
    private var restTimer: RestTimer?
    private var cancellables = Set<AnyCancellable>()

    // Live Activity management
    private let liveActivityManager = LiveActivityManager.shared

    // MARK: - Session State

    public enum SessionState: Equatable {
        case intro
        case workoutSelection  // NEW: Shows workout type before committing
        case preWorkout
        case workoutOverview  // Shows workout summary before stretching
        case stretching(timeRemaining: Int)  // 5-minute stretching countdown
        case warmup(step: Int)  // 0 = 50%×5, 1 = 70%×3
        case workingSet
        case rest(timeRemaining: Int)
        case review
        case done
    }

    // MARK: - Initialization

    public init() {
        loadDefaultWorkoutCycle()
        // Start loading persisted state asynchronously
        Task {
            await loadPersistedState()
        }
    }

    /// Initialize and wait for persisted state to load
    public func initialize() async {
        await loadPersistedState()
    }

    // MARK: - Resume State

    public var hasResumableSession: Bool {
        guard isInitialized else { return false }

        // Depend on currentSession to trigger SwiftUI updates
        // This ensures the view refreshes when discardSession() sets currentSession = nil
        _ = currentSession

        // Query DB directly for active session
        if let session = PersistenceManager.shared.loadCurrentSessionSync() {
            return session.isActive && !PersistenceManager.shared.isSessionStale(session)
        }
        return false
    }

    public func resumeSession() {
        AppLogger.session.info("Resume session requested, currentSession exists: \(self.currentSession != nil, privacy: .public), isActive: \(self.currentSession?.isActive ?? false, privacy: .public)")

        guard let session = currentSession,
              session.isActive,
              !PersistenceManager.shared.isSessionStale(session) else {
            AppLogger.session.debug("Resume session guard failed - no valid session to resume")
            return
        }

        AppLogger.session.notice("Resuming session")

        // Restore workout data from template (always regenerate profiles)
        if let template = session.workoutTemplate {
            AppLogger.session.info("Restoring workout data from template: \(template.name, privacy: .public)")
            currentWorkoutTemplate = template
            exerciseProfiles = WorkoutTemplateConverter.toExerciseProfiles(from: template)
            AppLogger.session.debug("Generated \(self.exerciseProfiles.count) exercise profiles from template")
        } else {
            AppLogger.session.error("No workout template available for resume")
            return
        }

        // Restore exercise index
        if let exerciseIndex = session.currentExerciseIndex {
            currentExerciseIndex = exerciseIndex
        }

        // Restore set index
        if let setIndex = session.currentSetIndex {
            currentSetIndex = setIndex
        }

        // Restore session state first
        if let stateRaw = session.sessionStateRaw, !stateRaw.isEmpty {
            sessionState = deserializeSessionState(stateRaw) ?? .preWorkout
            AppLogger.session.debug("Restored session state from: \(stateRaw, privacy: .public)")
        } else {
            // Fallback: if no state saved, determine based on session progress
            if session.preWorkoutFeeling != nil && session.exerciseLogs.isEmpty {
                // Had pre-workout feeling but no exercises logged yet - likely in stretching or warmup
                sessionState = .preWorkout
            } else if !session.exerciseLogs.isEmpty {
                // Has exercise logs - go to review of last exercise
                sessionState = .review
            } else {
                // Unknown state - start at pre-workout
                sessionState = .preWorkout
            }
            AppLogger.session.debug("Fallback session state determined")
        }

        // Restore current exercise log
        // First try to restore the in-progress exercise log saved in the session
        if let savedLog = session.currentExerciseLog {
            currentExerciseLog = savedLog
            AppLogger.session.debug("Restored exercise log from session")
        } else if currentExerciseIndex < session.exerciseLogs.count {
            // Fall back to completed exercise log at this index
            currentExerciseLog = session.exerciseLogs[currentExerciseIndex]
            AppLogger.session.debug("Restored exercise log from history at index \(self.currentExerciseIndex)")
        } else if let template = session.workoutTemplate,
                  currentExerciseIndex < template.exercises.count {
            // Exercise was started but not logged yet - create a new log
            let exercises = template.exercises.sorted(by: { $0.order < $1.order })
            let exercise = exercises[currentExerciseIndex]
            let exerciseId = exercise.lift.id
            let startWeight = exerciseStates[exerciseId]?.lastStartLoad ?? 45.0
            currentExerciseLog = ExerciseSessionLog(
                exerciseId: exerciseId,
                startWeight: startWeight
            )
            AppLogger.session.debug("Created new exercise log for resumed session: \(exerciseId, privacy: .public)")
        } else {
            AppLogger.session.error("Could not restore exercise log - no valid source")
        }

        // Restore prescription from last set log if available
        if let lastSet = currentExerciseLog?.setLogs.last {
            nextPrescription = (reps: lastSet.targetReps, weight: lastSet.targetWeight)
        }

        // If still no prescription and we're in a state that needs one, compute it
        if nextPrescription == nil {
            if case .workingSet = sessionState {
                computeInitialPrescription()
            } else if case .rest = sessionState {
                computeInitialPrescription()
            }
        }

        // Restart timers if in a timer-dependent state
        switch sessionState {
        case .stretching(let timeRemaining):
            // Restart stretching timer with remaining time or default duration
            let duration = timeRemaining > 0 ? timeRemaining : 300
            startStretchingTimer(duration: duration)
        case .rest:
            // Restart rest timer with default duration (can't reliably restore exact time)
            if let exerciseId = currentExerciseLog?.exerciseId,
               let profile = exerciseProfiles[exerciseId] {
                startRestTimer(duration: profile.defaultRestSec)
            }
        default:
            break
        }
    }

    private func startStretchingTimer(duration: Int) {
        let timer = RestTimer()
        restTimer = timer
        timer.start(duration: duration)
        sessionState = .stretching(timeRemaining: duration)

        timer.$timeRemaining
            .sink { [weak self] remaining in
                self?.sessionState = .stretching(timeRemaining: remaining)
            }
            .store(in: &cancellables)
    }

    public func discardSession() {
        AppLogger.session.notice("Discarding current session")

        // Clear database first (synchronously)
        PersistenceManager.shared.clearCurrentSessionSync()

        // Then clear in-memory state
        currentSession = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        sessionState = .intro
        currentExerciseLog = nil
        nextPrescription = nil
        isFirstExercise = true

        AppLogger.session.info("Session discarded, reset to intro")
    }

    private func serializeSessionState(_ state: SessionState) -> String {
        switch state {
        case .intro:
            return "intro"
        case .workoutSelection:
            return "workoutSelection"
        case .preWorkout:
            return "preWorkout"
        case .workoutOverview:
            return "workoutOverview"
        case .stretching(let timeRemaining):
            return "stretching:\(timeRemaining)"
        case .warmup(let step):
            return "warmup:\(step)"
        case .workingSet:
            return "workingSet"
        case .rest(let timeRemaining):
            return "rest:\(timeRemaining)"
        case .review:
            return "review"
        case .done:
            return "done"
        }
    }

    private func deserializeSessionState(_ raw: String) -> SessionState? {
        let components = raw.split(separator: ":")
        guard let first = components.first else { return nil }

        switch first {
        case "intro":
            return .intro
        case "workoutSelection":
            return .workoutSelection
        case "preWorkout":
            return .preWorkout
        case "workoutOverview":
            return .workoutOverview
        case "stretching":
            if components.count > 1, let time = Int(components[1]) {
                return .stretching(timeRemaining: time)
            }
            return .stretching(timeRemaining: 0)
        case "warmup":
            if components.count > 1, let step = Int(components[1]) {
                return .warmup(step: step)
            }
            return .warmup(step: 0)
        case "workingSet":
            return .workingSet
        case "rest":
            if components.count > 1, let time = Int(components[1]) {
                return .rest(timeRemaining: time)
            }
            return .rest(timeRemaining: 0)
        case "review":
            return .review
        case "done":
            return .done
        default:
            return nil
        }
    }

    // MARK: - Session Control

    /// Step 1: Show workout type selection (no DB write yet)
    public func showWorkoutSelection() {
        AppLogger.session.notice("Showing workout selection")

        // Query last workout from DB
        let sessions = PersistenceManager.shared.loadSessionsSync()
        let lastType = sessions.first?.workoutTemplate?.workoutType
        let nextType = lastType?.next ?? .push

        suggestedWorkoutType = nextType
        sessionState = .workoutSelection

        AppLogger.session.info("Suggested workout type: \(nextType.rawValue, privacy: .public)")
    }

    /// Step 2: User confirmed - create session and persist immediately
    public func confirmWorkoutStart() {
        AppLogger.session.notice("Confirmed workout start: \(self.suggestedWorkoutType.rawValue, privacy: .public)")

        // Reset session state
        currentExerciseIndex = 0
        currentSetIndex = 0
        isFirstExercise = true

        // Generate template
        currentWorkoutTemplate = WorkoutBuilder.build(type: suggestedWorkoutType)
        AppLogger.session.info("Generated template: \(self.currentWorkoutTemplate?.name ?? "unknown", privacy: .public)")

        // Create new session
        currentSession = Session(
            workoutTemplate: currentWorkoutTemplate,
            isActive: true
        )

        // 🔴 CRITICAL: First DB write happens here
        persistCurrentState()
        AppLogger.session.notice("Session persisted to database")

        // Move to pre-workout feeling
        sessionState = .preWorkout
    }

    /// Cancel workout selection - go back to intro with no DB changes
    public func cancelWorkoutSelection() {
        AppLogger.session.debug("Cancelled workout selection")
        sessionState = .intro
    }

    public func logPreWorkoutFeeling(_ feeling: PreWorkoutFeeling) {
        AppLogger.session.info("Logged pre-workout feeling: \(feeling.rating, privacy: .public)")
        currentSession?.preWorkoutFeeling = feeling

        persistCurrentState()

        // Skip workout overview and go straight to starting the workout
        startWorkoutFromTemplate()
    }

    // MARK: - Workout Overview

    public func startWorkoutFromTemplate() {
        guard let template = currentWorkoutTemplate else { return }

        // Convert template to ExerciseProfiles for STEEL compatibility
        let profiles = WorkoutTemplateConverter.toExerciseProfiles(from: template)

        // Populate working dictionary for STEEL lookups
        exerciseProfiles = profiles

        AppLogger.session.info("Workout template stored with \(profiles.count) exercises")

        // Start stretching phase
        startStretchingPhase()
        persistCurrentState()
    }

    // MARK: - Stretching Phase

    public func startStretchingPhase() {
        let stretchDuration = 300  // 5 minutes
        startStretchingTimer(duration: stretchDuration)
        persistCurrentState()
    }

    public func skipStretching() {
        // Stop the stretching timer
        restTimer?.stop()
        restTimer = nil

        // Start first exercise
        guard let template = currentSession?.workoutTemplate,
              let firstExercise = template.exercises.sorted(by: { $0.order < $1.order }).first else { return }

        startExercise(exerciseId: firstExercise.lift.id)
    }

    public func finishStretching() {
        AppLogger.session.info("Finishing stretching phase")

        // Stop the stretching timer
        restTimer?.stop()
        restTimer = nil

        // Start first exercise
        guard let session = currentSession,
              let template = session.workoutTemplate,
              let firstExercise = template.exercises.sorted(by: { $0.order < $1.order }).first else {
            AppLogger.session.error("Cannot finish stretching - workout template not found")
            return
        }

        AppLogger.session.notice("Starting first exercise: \(firstExercise.lift.name, privacy: .public)")
        startExercise(exerciseId: firstExercise.lift.id)
    }

    public func startExercise(exerciseId: String) {
        guard let profile = exerciseProfiles[exerciseId] else { return }

        // Get starting weight from state or use default
        let startWeight = exerciseStates[exerciseId]?.lastStartLoad ?? 45.0  // Default bar weight

        currentExerciseLog = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: startWeight
        )

        currentSetIndex = 0

        // Determine exercise index in workout
        let exerciseIndex = currentSession?.workoutTemplate?.exercises.firstIndex(where: { $0.lift.id == exerciseId }) ?? 0

        // Use STEEL to determine warmup prescription
        if let exercise = currentSession?.workoutTemplate?.exercises.first(where: { $0.lift.id == exerciseId }) {
            let warmupPrescription = SteelProgressionEngine.prescribeWarmup(
                equipment: exercise.lift.equipment,
                workingWeight: startWeight,
                category: exercise.lift.category,
                priority: exercise.priority,
                exerciseIndex: exerciseIndex,
                config: exercise.lift.steelConfig
            )

            if warmupPrescription.needsWarmup {
                AppLogger.session.debug("STEEL prescribed \(warmupPrescription.sets.count) warmup sets for \(exercise.lift.name, privacy: .public)")
                sessionState = .warmup(step: 0)
            } else {
                AppLogger.session.debug("STEEL skipped warmup for \(exercise.lift.name, privacy: .public)")
                sessionState = .workingSet
                computeInitialPrescription()
            }
        } else {
            // Exercise not found in template - skip warmup
            sessionState = .workingSet
            computeInitialPrescription()
        }

        persistCurrentState()

        // Update Live Activity
        Task {
            await updateLiveActivity(
                exerciseId: profile.name,
                currentSet: 1,
                totalSets: profile.sets,
                restTimeRemaining: nil,
                isResting: false
            )
        }
    }

    // MARK: - Warmup Flow

    public func advanceWarmup() {
        guard case .warmup(let step) = sessionState else { return }
        guard let exerciseLog = currentExerciseLog,
              let exercise = currentSession?.workoutTemplate?.exercises.first(where: { $0.lift.id == exerciseLog.exerciseId }) else { return }

        let exerciseIndex = currentSession?.workoutTemplate?.exercises.firstIndex(where: { $0.lift.id == exerciseLog.exerciseId }) ?? 0

        let warmupPrescription = SteelProgressionEngine.prescribeWarmup(
            equipment: exercise.lift.equipment,
            workingWeight: exerciseLog.startWeight,
            category: exercise.lift.category,
            priority: exercise.priority,
            exerciseIndex: exerciseIndex,
            config: exercise.lift.steelConfig
        )

        if step < warmupPrescription.sets.count - 1 {
            // Move to next warmup step
            sessionState = .warmup(step: step + 1)
        } else {
            // Warmup complete, move to working set
            sessionState = .workingSet
            computeInitialPrescription()
        }
    }

    public func getWarmupPrescription() -> (weight: Double, reps: Int)? {
        guard case .warmup(let step) = sessionState else { return nil }
        guard let exerciseLog = currentExerciseLog,
              let exercise = currentSession?.workoutTemplate?.exercises.first(where: { $0.lift.id == exerciseLog.exerciseId }) else {
            return nil
        }

        let exerciseIndex = currentSession?.workoutTemplate?.exercises.firstIndex(where: { $0.lift.id == exerciseLog.exerciseId }) ?? 0

        let warmupPrescription = SteelProgressionEngine.prescribeWarmup(
            equipment: exercise.lift.equipment,
            workingWeight: exerciseLog.startWeight,
            category: exercise.lift.category,
            priority: exercise.priority,
            exerciseIndex: exerciseIndex,
            config: exercise.lift.steelConfig
        )

        guard step < warmupPrescription.sets.count else { return nil }
        let warmupSet = warmupPrescription.sets[step]

        return (weight: warmupSet.weight, reps: warmupSet.reps)
    }

    // MARK: - Working Set Flow

    public func logSet(reps: Int, rating: Rating) {
        guard let exerciseLog = currentExerciseLog,
              let profile = exerciseProfiles[exerciseLog.exerciseId] else { return }

        let currentWeight = nextPrescription?.weight ?? exerciseLog.startWeight
        let targetReps = nextPrescription?.reps ?? profile.repRange.lowerBound

        let setLog = SetLog(
            setIndex: currentSetIndex + 1,
            targetReps: targetReps,
            targetWeight: currentWeight,
            achievedReps: reps,
            rating: rating,
            actualWeight: currentWeight,
            restPlannedSec: profile.defaultRestSec
        )

        currentExerciseLog?.setLogs.append(setLog)

        // Check for bad-day switch
        if SteelProgressionEngine.shouldActivateBadDaySwitch(setLogs: currentExerciseLog?.setLogs ?? []) {
            applyBadDaySwitch()
        }

        // Compute next prescription using S.T.E.E.L. micro-adjust
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: currentWeight,
            achievedReps: reps,
            repRange: profile.repRange,
            rating: rating,
            baseIncrement: profile.baseIncrement,
            microAdjustStep: profile.microAdjustStep,
            rounding: profile.rounding
        )

        nextPrescription = (reps: result.nextReps, weight: result.nextWeight)

        // Move to rest
        currentSetIndex += 1
        startRestTimer(duration: profile.defaultRestSec)
        persistCurrentState()
    }

    public func advanceToNextSet() {
        // Stop the rest timer
        restTimer?.stop()
        restTimer = nil

        guard let exerciseId = currentExerciseLog?.exerciseId,
              let profile = exerciseProfiles[exerciseId] else { return }

        if currentSetIndex < profile.sets {
            sessionState = .workingSet
        } else {
            // Exercise complete, compute decision
            finishExercise()
        }
    }

    // MARK: - Timer Management

    private func startRestTimer(duration: Int) {
        // Create new timer
        let timer = RestTimer()
        restTimer = timer

        // Start timer
        timer.start(duration: duration)

        // Initial state
        sessionState = .rest(timeRemaining: duration)

        // Observe timer updates
        timer.$timeRemaining
            .sink { [weak self] remaining in
                guard let self = self else { return }
                self.sessionState = .rest(timeRemaining: remaining)

                // Update Live Activity with rest timer
                guard let exerciseLog = self.currentExerciseLog,
                      let profile = self.exerciseProfiles[exerciseLog.exerciseId] else {
                    return
                }

                Task { @MainActor in
                    await self.updateLiveActivity(
                        exerciseId: profile.name,
                        currentSet: self.currentSetIndex + 1,
                        totalSets: profile.sets,
                        restTimeRemaining: remaining,
                        isResting: true
                    )
                }
            }
            .store(in: &cancellables)
    }

    public func adjustRestTime(by seconds: Int) {
        restTimer?.adjustTime(by: seconds)
    }

    // MARK: - Exercise Completion

    public func finishExercise() {
        guard var exerciseLog = currentExerciseLog,
              let profile = exerciseProfiles[exerciseLog.exerciseId] else { return }

        // Compute decision
        let decision = SteelProgressionEngine.computeDecision(
            setLogs: exerciseLog.setLogs,
            repRange: profile.repRange,
            totalSets: profile.sets
        )

        exerciseLog.sessionDecision = decision

        // Compute next session start weight
        let recentLoads = getRecentLoads(exerciseId: exerciseLog.exerciseId)

        // Package profile config as SteelConfig
        let steelConfig = SteelConfig(
            repRange: profile.repRange,
            baseIncrement: profile.baseIncrement,
            rounding: profile.rounding,
            microAdjustStep: profile.microAdjustStep,
            weeklyCapPct: profile.weeklyCapPct,
            plateOptions: profile.plateOptions,
            warmupRule: profile.warmupRule
        )

        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: exerciseLog.startWeight,
            decision: decision,
            config: steelConfig,
            recentLoads: recentLoads
        )

        exerciseLog.nextStartWeight = result.startWeight

        // Update state
        updateExerciseState(
            exerciseId: exerciseLog.exerciseId,
            startLoad: result.startWeight,
            decision: decision
        )

        // Save to session
        currentExerciseLog = exerciseLog
        currentSession?.exerciseLogs.append(exerciseLog)

        sessionState = .review
    }

    public func advanceToNextExercise() {
        guard let session = currentSession,
              let template = session.workoutTemplate else { return }

        currentExerciseIndex += 1

        let exercises = template.exercises.sorted(by: { $0.order < $1.order })
        if currentExerciseIndex < exercises.count {
            let nextExercise = exercises[currentExerciseIndex]
            startExercise(exerciseId: nextExercise.lift.id)
        } else {
            finishSession()
        }
    }

    // MARK: - Session Completion

    public func finishSession() {
        guard var session = currentSession else { return }

        // Calculate stats
        let totalVolume = session.exerciseLogs.reduce(0.0) { total, log in
            let exerciseVolume = log.setLogs.reduce(0.0) { setTotal, set in
                setTotal + (Double(set.achievedReps) * set.actualWeight)
            }
            return total + exerciseVolume
        }

        session.stats.totalVolume = totalVolume

        // Mark session as inactive (completed)
        session.isActive = false

        // Update workout cycle if we used a template
        if let template = currentWorkoutTemplate {
            workoutCycle?.completeWorkout(template.workoutType)
        }

        // Save session
        currentSession = session
        persistCurrentState()

        sessionState = .done

        // Invalidate analytics cache so new session appears immediately
        invalidateAnalyticsCache()

        // End Live Activity
        Task {
            await endLiveActivity()
        }
    }

    /// Reset to intro screen after finishing a session (without discarding saved data)
    public func resetToIntro() {
        AppLogger.session.notice("Resetting to intro after completed session")

        // Clear in-memory state but don't delete saved session from database
        currentSession = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        sessionState = .intro
        currentExerciseLog = nil
        nextPrescription = nil
        isFirstExercise = true

        AppLogger.session.info("Reset to intro complete")
    }

    // MARK: - Helper Methods

    private func computeInitialPrescription() {
        guard let exerciseLog = currentExerciseLog,
              let profile = exerciseProfiles[exerciseLog.exerciseId] else { return }

        nextPrescription = (
            reps: profile.repRange.upperBound,  // Prescribe max reps to aim for
            weight: exerciseLog.startWeight
        )
    }

    private func applyBadDaySwitch() {
        guard let exerciseLog = currentExerciseLog,
              let profile = exerciseProfiles[exerciseLog.exerciseId],
              let currentWeight = nextPrescription?.weight else { return }

        let result = SteelProgressionEngine.applyBadDayAdjustment(
            currentWeight: currentWeight,
            baseIncrement: profile.baseIncrement,
            rounding: profile.rounding,
            repRange: profile.repRange
        )

        nextPrescription = (reps: result.nextReps, weight: result.nextWeight)
    }

    private func getRecentLoads(exerciseId: String) -> [Double] {
        // For now, return empty array - this will be loaded async when needed
        // TODO: Make this async or cache sessions in memory
        return []
    }

    private func updateExerciseState(exerciseId: String, startLoad: Double, decision: SessionDecision) {
        exerciseStates[exerciseId] = ExerciseState(
            exerciseId: exerciseId,
            lastStartLoad: startLoad,
            lastDecision: decision,
            lastUpdatedAt: Date()
        )
        persistExerciseStates()
    }

    // MARK: - Persistence

    /// Persist current state to database (synchronous - critical path)
    private func persistCurrentState() {
        guard var session = currentSession else {
            AppLogger.session.error("Attempted to persist but no current session exists")
            return
        }

        // Update all state fields
        session.currentExerciseIndex = currentExerciseIndex
        session.currentSetIndex = currentSetIndex
        session.sessionStateRaw = serializeSessionState(sessionState)
        session.currentExerciseLog = currentExerciseLog
        session.lastUpdated = Date()

        // Mark as inactive if done
        if case .done = sessionState {
            session.isActive = false
            AppLogger.session.info("Marking session as inactive (done)")
        }

        currentSession = session

        // 🔴 CRITICAL: Synchronous DB write
        PersistenceManager.shared.saveCurrentSessionSync(session)

        // Update history
        var sessions = PersistenceManager.shared.loadSessionsSync()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        PersistenceManager.shared.saveSessionsSync(sessions)

        AppLogger.session.debug("State persisted: \(self.serializeSessionState(self.sessionState), privacy: .public)")
    }

    private func persistExerciseStates() {
        Task {
            await PersistenceManager.shared.saveExerciseStates(exerciseStates)
        }
    }

    private func loadPersistedState() async {
        AppLogger.session.debug("Loading persisted session state")

        // Load exercise states (always needed for progression tracking)
        let states = await PersistenceManager.shared.loadExerciseStates()
        exerciseStates = states

        // IMPORTANT: Skip loading old workout plans and profiles
        // We're now using the template system exclusively
        AppLogger.session.debug("Using template system, skipping legacy workout plans")

        // Load current session if exists
        if let savedSession = await PersistenceManager.shared.loadCurrentSession() {
            // Check if session is stale
            if PersistenceManager.shared.isSessionStale(savedSession) {
                // Clear stale session
                await PersistenceManager.shared.clearCurrentSession()
                AppLogger.session.info("Cleared stale session")
            } else {
                // Keep session for potential resume
                currentSession = savedSession

                // Restore the workout template from the session
                if let template = savedSession.workoutTemplate {
                    currentWorkoutTemplate = template
                    AppLogger.session.info("Restored workout template: \(template.name, privacy: .public)")
                }
            }
        }

        // Mark as initialized
        isInitialized = true
    }

    // MARK: - Default Data

    private func loadDefaultWorkoutCycle() {
        AppLogger.session.debug("Initializing workout cycle with dynamic generation")

        // Initialize cycle - templates are generated on-demand
        workoutCycle = WorkoutCycle(lastCompletedType: nil)

        AppLogger.session.info("Workout cycle initialized for dynamic generation")
    }

    // MARK: - Live Activity Helpers

    private func updateLiveActivity(
        exerciseId: String,
        currentSet: Int,
        totalSets: Int,
        restTimeRemaining: Int?,
        isResting: Bool
    ) async {
        guard let session = currentSession,
              let template = session.workoutTemplate else {
            return
        }

        let nextWeight = nextPrescription?.weight ?? 0
        let nextReps = nextPrescription?.reps ?? 0
        let totalExercises = template.exercises.count
        let exercisesCompleted = session.exerciseLogs.count

        // Start or update activity
        if liveActivityManager.hasActiveActivity {
            await liveActivityManager.updateActivity(
                exerciseId: exerciseId,
                currentSet: currentSet,
                totalSets: totalSets,
                restTimeRemaining: restTimeRemaining,
                nextWeight: nextWeight,
                nextReps: nextReps,
                isResting: isResting,
                exercisesCompleted: exercisesCompleted,
                totalExercises: totalExercises
            )
        } else {
            await liveActivityManager.startActivity(
                workoutName: template.name,
                exerciseId: exerciseId,
                currentSet: currentSet,
                totalSets: totalSets,
                nextWeight: nextWeight,
                nextReps: nextReps,
                exercisesCompleted: exercisesCompleted,
                totalExercises: totalExercises
            )
        }
    }

    public func endLiveActivity() async {
        guard let session = currentSession,
              let template = session.workoutTemplate else {
            await liveActivityManager.endActivity()
            return
        }

        let exercisesCompleted = session.exerciseLogs.count
        let totalExercises = template.exercises.count
        let finalExercise = exercisesCompleted > 0 ? session.exerciseLogs.last?.exerciseId : nil

        await liveActivityManager.endActivity(
            finalExercise: finalExercise,
            completedExercises: exercisesCompleted,
            totalExercises: totalExercises
        )
    }
}