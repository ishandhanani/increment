import Foundation
import Combine
import Observation

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

    public var workoutPlans: [WorkoutPlan] = []
    public var exerciseProfiles: [UUID: ExerciseProfile] = [:]
    public var exerciseStates: [UUID: ExerciseState] = [:]

    // New workout system
    public var workoutCycle: WorkoutCycle?
    public var currentWorkoutTemplate: WorkoutTemplate?

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
        case load
        case workingSet
        case rest(timeRemaining: Int)
        case review
        case done
    }

    // MARK: - Initialization

    public init() {
        loadDefaultExercises()
        loadDefaultWorkoutPlan()
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
        print("🔄 resumeSession() called")
        print("🔄 currentSession: \(currentSession != nil)")
        print("🔄 isActive: \(currentSession?.isActive ?? false)")

        guard let session = currentSession,
              session.isActive,
              !PersistenceManager.shared.isSessionStale(session) else {
            print("🔄 resumeSession() guard failed")
            return
        }

        print("🔄 resumeSession() proceeding with resume")

        // IMPORTANT: Restore workout data from session-scoped storage
        if let sessionPlan = session.workoutPlan,
           let sessionProfiles = session.exerciseProfilesForSession {
            print("🔄 Restoring workout data from session storage")
            workoutPlans = [sessionPlan]
            exerciseProfiles = sessionProfiles
            print("🔄 Restored \(sessionProfiles.count) exercise profiles and workout plan")
        } else if let template = currentWorkoutTemplate {
            // Fallback: regenerate from template if session data is missing
            print("🔄 Session data missing, regenerating from template: \(template.name)")
            let (plan, profiles) = WorkoutTemplateConverter.toWorkoutPlan(from: template)
            workoutPlans = [plan]
            exerciseProfiles = profiles
            print("🔄 Generated \(profiles.count) exercise profiles and workout plan")
        } else {
            print("🔄 ERROR: No workout data available for resume")
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
            print("🔄 Restored sessionState from raw: \(stateRaw) -> \(sessionState)")
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
            print("🔄 Fallback sessionState set to: \(sessionState)")
        }

        // Restore current exercise log
        // First try to restore the in-progress exercise log saved in the session
        if let savedLog = session.currentExerciseLog {
            currentExerciseLog = savedLog
            print("🔄 Restored currentExerciseLog from session: \(savedLog.exerciseId)")
        } else if currentExerciseIndex < session.exerciseLogs.count {
            // Fall back to completed exercise log at this index
            currentExerciseLog = session.exerciseLogs[currentExerciseIndex]
            print("🔄 Restored currentExerciseLog from exerciseLogs at index \(currentExerciseIndex)")
        } else if let plan = workoutPlans.first(where: { $0.id == session.workoutPlanId }),
                  currentExerciseIndex < plan.order.count {
            // Exercise was started but not logged yet - create a new log
            let exerciseId = plan.order[currentExerciseIndex]
            if exerciseProfiles[exerciseId] != nil {
                let startWeight = exerciseStates[exerciseId]?.lastStartLoad ?? 45.0
                currentExerciseLog = ExerciseSessionLog(
                    exerciseId: exerciseId,
                    startWeight: startWeight
                )
                print("🔄 Created new currentExerciseLog for exerciseId: \(exerciseId)")
            } else {
                print("🔄 ERROR: No profile found for exerciseId: \(exerciseId)")
            }
        } else {
            print("🔄 ERROR: Could not restore currentExerciseLog - no valid source")
        }

        print("🔄 Final currentExerciseLog: \(currentExerciseLog?.exerciseId.uuidString ?? "nil")")

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
        print("🗑️ discardSession() called")
        currentSession = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        sessionState = .intro
        currentExerciseLog = nil
        nextPrescription = nil
        isFirstExercise = true

        PersistenceManager.shared.clearCurrentSession()
        print("🗑️ discardSession() completed, sessionState = .intro")
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
        case .load:
            return "load"
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
        case "load":
            return .load
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
        print("🎯 startSession() called - using dynamic generation system")

        // Reset session state
        currentExerciseIndex = 0
        currentSetIndex = 0
        isFirstExercise = true

        // Don't generate template yet - will happen in logPreWorkoutFeeling()
        print("🎯 Session initialized - workout will be dynamically generated")

        // Create a temporary session (UUID will be replaced when template is generated)
        currentSession = Session(workoutPlanId: UUID())

        // Show pre-workout feeling screen
        sessionState = .preWorkout
    }

    // DEPRECATED: Old method for backward compatibility
    public func startSession(workoutPlanId: UUID) {
        print("🎯 DEPRECATED: startSession(workoutPlanId:) called")
        startSession()
    }

    public func logPreWorkoutFeeling(_ feeling: PreWorkoutFeeling) {
        currentSession?.preWorkoutFeeling = feeling

        // Dynamically generate next workout based on cycle
        let nextType = workoutCycle?.lastCompletedType?.next ?? .push
        print("🏗️ Dynamically generating workout: \(nextType.rawValue)")
        currentWorkoutTemplate = WorkoutBuilder.build(type: nextType)
        print("🏗️ Generated template: \(currentWorkoutTemplate?.name ?? "nil")")

        persistSession()
        sessionState = .workoutOverview
    }

    // MARK: - Workout Overview

    public func startWorkoutFromTemplate() {
        guard let template = currentWorkoutTemplate else { return }

        // Convert template to WorkoutPlan + ExerciseProfiles ONCE for this session
        let (plan, profiles) = WorkoutTemplateConverter.toWorkoutPlan(from: template)

        // Create a new session with the correct workoutPlanId
        if let oldSession = currentSession {
            currentSession = Session(
                id: oldSession.id,
                date: oldSession.date,
                workoutPlanId: plan.id,  // Use the generated plan's ID
                preWorkoutFeeling: oldSession.preWorkoutFeeling,
                exerciseLogs: oldSession.exerciseLogs,
                stats: oldSession.stats,
                synced: oldSession.synced,
                workoutPlan: plan,
                exerciseProfilesForSession: profiles,
                isActive: oldSession.isActive,
                currentExerciseIndex: oldSession.currentExerciseIndex,
                currentSetIndex: oldSession.currentSetIndex,
                sessionStateRaw: oldSession.sessionStateRaw,
                currentExerciseLog: oldSession.currentExerciseLog,
                lastUpdated: Date()
            )
        }

        // Also populate the working dictionaries for this session
        exerciseProfiles = profiles
        workoutPlans = [plan]

        print("✅ Generated workout plan with \(profiles.count) exercises for session")

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
        guard let plan = workoutPlans.first(where: { $0.id == currentSession?.workoutPlanId ?? UUID() }),
              let firstExerciseId = plan.order.first else { return }

        startExercise(exerciseId: firstExerciseId)
    }

    public func finishStretching() {
        print("🏃 finishStretching() called")
        print("🏃 currentSession: \(currentSession != nil)")
        print("🏃 currentSession.workoutPlanId: \(currentSession?.workoutPlanId.uuidString ?? "nil")")
        print("🏃 workoutPlans.count: \(workoutPlans.count)")
        print("🏃 workoutPlans: \(workoutPlans.map { $0.id.uuidString })")

        // Stop the stretching timer
        restTimer?.stop()
        restTimer = nil

        // Start first exercise
        guard let session = currentSession,
              let plan = workoutPlans.first(where: { $0.id == session.workoutPlanId }),
              let firstExerciseId = plan.order.first else {
            print("❌ finishStretching() failed - cannot find workout plan")
            print("❌ Specifically: session=\(currentSession != nil), plan found=\(workoutPlans.contains(where: { $0.id == currentSession?.workoutPlanId }))")
            return
        }

        print("✅ finishStretching() starting exercise: \(firstExerciseId)")
        startExercise(exerciseId: firstExerciseId)
    }

    public func startExercise(exerciseId: UUID) {
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
            // Skip warmups, go directly to load
            sessionState = .load
            computeInitialPrescription()
        }

        persistSession()

        // Update Live Activity
        Task {
            await updateLiveActivity(
                exerciseName: profile.name,
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
            // Warmup complete, move to load
            sessionState = .load
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

    // MARK: - Load Flow

    public func acknowledgeLoad() {
        sessionState = .workingSet
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

        guard let profile = exerciseProfiles[currentExerciseLog?.exerciseId ?? UUID()] else { return }

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
                        exerciseName: profile.name,
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
        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: exerciseLog.startWeight,
            decision: decision,
            baseIncrement: profile.baseIncrement,
            rounding: profile.rounding,
            weeklyCapPct: profile.weeklyCapPct,
            recentLoads: recentLoads,
            plateOptions: profile.plateOptions
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
              let plan = workoutPlans.first(where: { $0.id == session.workoutPlanId }) else { return }

        currentExerciseIndex += 1

        if currentExerciseIndex < plan.order.count {
            let nextExerciseId = plan.order[currentExerciseIndex]
            startExercise(exerciseId: nextExerciseId)
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

    private func getRecentLoads(exerciseId: UUID) -> [Double] {
        // Get all sessions from persistence
        let allSessions = PersistenceManager.shared.loadSessions()

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

    private func updateExerciseState(exerciseId: UUID, startLoad: Double, decision: SessionDecision) {
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
        guard var session = currentSession else { return }

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

        currentSession = session

        // Save current session
        PersistenceManager.shared.saveCurrentSession(session)

        // Add to history
        var sessions = PersistenceManager.shared.loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        PersistenceManager.shared.saveSessions(sessions)
    }

    private func persistExerciseStates() {
        PersistenceManager.shared.saveExerciseStates(exerciseStates)
    }

    private func loadPersistedState() {
        print("💾 loadPersistedState() called")

        // Load exercise states (always needed for progression tracking)
        exerciseStates = PersistenceManager.shared.loadExerciseStates()

        // IMPORTANT: Skip loading old workout plans and profiles
        // We're now using the template system exclusively
        print("💾 Skipping old workout plans and profiles - using template system")

        // Load current session if exists
        if let savedSession = PersistenceManager.shared.loadCurrentSession() {
            // Check if session is stale
            if PersistenceManager.shared.isSessionStale(savedSession) {
                // Clear stale session
                PersistenceManager.shared.clearCurrentSession()
            } else {
                // Keep session for potential resume
                currentSession = savedSession

                // Try to restore the workout template from the session's workoutPlanId
                if let template = workoutCycle?.templates.first(where: { $0.id == savedSession.workoutPlanId }) {
                    currentWorkoutTemplate = template
                    print("💾 Restored workout template: \(template.name)")
                }
            }
        }
    }

    // MARK: - Default Data

    private func loadDefaultExercises() {
        // Deprecated: Now using workout templates instead
        print("📋 loadDefaultExercises() skipped - using workout templates")
    }

    private func loadDefaultWorkoutPlan() {
        // Deprecated: Now using workout templates instead
        print("📋 loadDefaultWorkoutPlan() skipped - using workout templates")
    }

    private func loadDefaultWorkoutCycle() {
        print("📋 loadDefaultWorkoutCycle() called - using dynamic generation")

        // Initialize empty cycle - templates will be generated on-demand
        workoutCycle = WorkoutCycle(
            templates: [],  // Empty - we'll generate dynamically
            lastCompletedType: nil
        )

        print("📋 Workout cycle initialized - templates will be generated dynamically")
    }

    // MARK: - Live Activity Helpers

    private func updateLiveActivity(
        exerciseName: String,
        currentSet: Int,
        totalSets: Int,
        restTimeRemaining: Int?,
        isResting: Bool
    ) async {
        guard let session = currentSession,
              let plan = workoutPlans.first(where: { $0.id == session.workoutPlanId }) else {
            return
        }

        let nextWeight = nextPrescription?.weight ?? 0
        let nextReps = nextPrescription?.reps ?? 0
        let totalExercises = plan.order.count
        let exercisesCompleted = session.exerciseLogs.count

        // Start or update activity
        if liveActivityManager.hasActiveActivity {
            await liveActivityManager.updateActivity(
                exerciseName: exerciseName,
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
                workoutName: plan.name,
                exerciseName: exerciseName,
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
              let plan = workoutPlans.first(where: { $0.id == session.workoutPlanId }) else {
            await liveActivityManager.endActivity()
            return
        }

        let exercisesCompleted = session.exerciseLogs.count
        let totalExercises = plan.order.count
        let finalExercise = exercisesCompleted > 0 ? session.exerciseLogs.last.flatMap { exerciseProfiles[$0.exerciseId]?.name } : nil

        await liveActivityManager.endActivity(
            finalExercise: finalExercise,
            completedExercises: exercisesCompleted,
            totalExercises: totalExercises
        )
    }
}