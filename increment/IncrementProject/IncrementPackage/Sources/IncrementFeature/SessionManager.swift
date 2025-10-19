import Foundation
import SwiftData
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

    // MARK: - Data

    public var exerciseProfiles: [String: ExerciseProfile] = [:]  // Keyed by exercise name
    public var exerciseStates: [String: ExerciseState] = [:]  // Keyed by exercise name

    // Workout system
    public var workoutCycle: WorkoutCycle?
    public var currentWorkoutTemplate: WorkoutTemplate?

    // ModelContext for SwiftData (injected after init)
    public var modelContext: ModelContext?

    // Timer management
    private var restTimer: RestTimer?
    private var cancellables = Set<AnyCancellable>()

    // Live Activity management
    private let liveActivityManager = LiveActivityManager.shared

    // MARK: - Session State

    public enum SessionState: Equatable {
        case intro
        case preWorkout
        case workoutOverview  // NEW: Shows workout summary before stretching
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
        loadPersistedState()
    }

    // MARK: - Resume State

    public var hasResumableSession: Bool {
        guard let session = currentSession, session.isActive else {
            return false
        }

        // Check if session is not stale (within 24 hours)
        return !PersistenceManager.shared.isSessionStale(session)
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
        currentSession = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        sessionState = .intro
        currentExerciseLog = nil
        nextPrescription = nil
        isFirstExercise = true

        guard let context = modelContext else { return }
        PersistenceManager.shared.clearCurrentSession(in: context)
        AppLogger.session.info("Session discarded, reset to intro")
    }

    private func serializeSessionState(_ state: SessionState) -> String {
        switch state {
        case .intro:
            return "intro"
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

    public func startSession() {
        guard let context = modelContext else {
            AppLogger.session.error("Cannot start session: ModelContext not available")
            return
        }

        AppLogger.session.notice("Starting new session with dynamic generation")

        // Reset session state
        currentExerciseIndex = 0
        currentSetIndex = 0
        isFirstExercise = true

        AppLogger.session.debug("Session initialized, workout will be generated after pre-workout feeling")

        // Create a new session and insert into SwiftData
        let newSession = Session()
        context.insert(newSession)
        currentSession = newSession

        // Show pre-workout feeling screen
        sessionState = .preWorkout
    }

    public func logPreWorkoutFeeling(_ feeling: PreWorkoutFeeling) {
        currentSession?.preWorkoutFeeling = feeling

        // Dynamically generate next workout based on cycle
        let nextType = workoutCycle?.lastCompletedType?.next ?? .push
        AppLogger.session.notice("Generating \(nextType.rawValue, privacy: .public) workout")
        currentWorkoutTemplate = WorkoutBuilder.build(type: nextType)
        AppLogger.session.info("Workout template generated: \(self.currentWorkoutTemplate?.name ?? "unknown", privacy: .public)")

        persistSession()
        sessionState = .workoutOverview
    }

    // MARK: - Workout Overview

    public func startWorkoutFromTemplate() {
        guard let template = currentWorkoutTemplate else { return }

        // Convert template to ExerciseProfiles for STEEL compatibility
        let profiles = WorkoutTemplateConverter.toExerciseProfiles(from: template)

        // Update session with template
        if let oldSession = currentSession {
            currentSession = Session(
                id: oldSession.id,
                date: oldSession.date,
                preWorkoutFeeling: oldSession.preWorkoutFeeling,
                exerciseLogs: oldSession.exerciseLogs,
                stats: oldSession.stats,
                synced: oldSession.synced,
                workoutTemplate: template,
                isActive: oldSession.isActive,
                currentExerciseIndex: oldSession.currentExerciseIndex,
                currentSetIndex: oldSession.currentSetIndex,
                sessionStateRaw: oldSession.sessionStateRaw,
                currentExerciseLog: oldSession.currentExerciseLog,
                lastUpdated: Date()
            )
        }

        // Populate working dictionary for STEEL lookups
        exerciseProfiles = profiles

        AppLogger.session.info("Workout template stored with \(profiles.count) exercises")

        // Start stretching phase
        startStretchingPhase()
        persistSession()
    }

    // MARK: - Stretching Phase

    public func startStretchingPhase() {
        let stretchDuration = 300  // 5 minutes
        startStretchingTimer(duration: stretchDuration)
        persistSession()
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

        // Only do warmups for the first exercise
        if isFirstExercise {
            sessionState = .warmup(step: 0)
            isFirstExercise = false
        } else {
            // Skip warmups, go directly to working set
            sessionState = .workingSet
            computeInitialPrescription()
        }

        persistSession()

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
              exerciseProfiles[exerciseLog.exerciseId] != nil else { return }

        if step == 0 {
            // Move to 70%×3
            sessionState = .warmup(step: 1)
        } else {
            // Warmup complete, move to working set
            sessionState = .workingSet
            computeInitialPrescription()
        }
    }

    public func getWarmupPrescription() -> (weight: Double, reps: Int)? {
        guard case .warmup(let step) = sessionState else { return nil }
        guard let exerciseLog = currentExerciseLog else { return nil }

        let startWeight = exerciseLog.startWeight

        switch step {
        case 0:
            return (weight: startWeight * 0.5, reps: 5)
        case 1:
            return (weight: startWeight * 0.7, reps: 3)
        default:
            return nil
        }
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
        persistSession()
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

        // Update workout cycle if we used a template
        if let template = currentWorkoutTemplate {
            workoutCycle?.completeWorkout(template.workoutType)
        }

        // Save session
        currentSession = session
        persistSession()

        sessionState = .done

        // End Live Activity
        Task {
            await endLiveActivity()
        }
    }

    // MARK: - Helper Methods

    private func computeInitialPrescription() {
        guard let exerciseLog = currentExerciseLog,
              let profile = exerciseProfiles[exerciseLog.exerciseId] else { return }

        nextPrescription = (
            reps: profile.repRange.lowerBound,
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
        guard let context = modelContext else { return [] }

        // Get all sessions from persistence
        let allSessions = PersistenceManager.shared.loadSessions(from: context)

        // Calculate date 7 days ago
        let calendar = Calendar.current
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            return []
        }

        // Filter sessions from last 7 days
        let recentSessions = allSessions.filter { session in
            session.date >= sevenDaysAgo
        }

        // Extract start weights for the specific exercise
        let startWeights = recentSessions.compactMap { session -> Double? in
            // Find exercise log for this exercise in the session
            guard let exerciseLog = session.exerciseLogs.first(where: { $0.exerciseId == exerciseId }) else {
                return nil
            }
            return exerciseLog.startWeight
        }

        return startWeights
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

    private func persistSession() {
        guard let session = currentSession, let context = modelContext else { return }

        // Update resume state
        session.currentExerciseIndex = currentExerciseIndex
        session.currentSetIndex = currentSetIndex
        session.sessionStateRaw = serializeSessionState(sessionState)
        session.currentExerciseLog = currentExerciseLog  // Save in-progress exercise log
        session.lastUpdated = Date()

        // Mark as inactive if done
        if case .done = sessionState {
            session.isActive = false
        }

        // Save to SwiftData
        do {
            try context.save()
            AppLogger.session.debug("Session persisted to SwiftData")
        } catch {
            AppLogger.session.error("Failed to persist session: \(error.localizedDescription)")
        }
    }

    private func persistExerciseStates() {
        PersistenceManager.shared.saveExerciseStates(exerciseStates)
    }

    private func loadPersistedState() {
        guard let context = modelContext else {
            AppLogger.session.warning("ModelContext not available during init, will load state later")
            return
        }

        AppLogger.session.debug("Loading persisted session state")

        // Load exercise states (always needed for progression tracking)
        exerciseStates = PersistenceManager.shared.loadExerciseStates()

        // IMPORTANT: Skip loading old workout plans and profiles
        // We're now using the template system exclusively
        AppLogger.session.debug("Using template system, skipping legacy workout plans")

        // Load current session if exists
        if let savedSession = PersistenceManager.shared.loadCurrentSession(from: context) {
            // Check if session is stale
            if PersistenceManager.shared.isSessionStale(savedSession) {
                // Clear stale session
                PersistenceManager.shared.clearCurrentSession(in: context)
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