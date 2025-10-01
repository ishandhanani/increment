import Foundation
import Combine

/// Manages the current workout session state
class SessionManager: ObservableObject {
    // MARK: - Published State

    @Published var currentSession: Session?
    @Published var currentExerciseIndex: Int = 0
    @Published var currentSetIndex: Int = 0
    @Published var sessionState: SessionState = .intro
    @Published var currentExerciseLog: ExerciseSessionLog?
    @Published var nextPrescription: (reps: Int, weight: Double)?

    // MARK: - Data

    var workoutPlans: [WorkoutPlan] = []
    var exerciseProfiles: [UUID: ExerciseProfile] = [:]
    var exerciseStates: [UUID: ExerciseState] = [:]

    // Timer management
    private var restTimer: RestTimer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Session State

    enum SessionState {
        case intro
        case preWorkout
        case warmup(step: Int)  // 0 = 50%×5, 1 = 70%×3
        case load
        case workingSet
        case rest(timeRemaining: Int)
        case review
        case done
    }

    // MARK: - Initialization

    init() {
        loadDefaultExercises()
        loadDefaultWorkoutPlan()
        loadPersistedState()
    }

    // MARK: - Session Control

    func startSession(workoutPlanId: UUID) {
        guard let plan = workoutPlans.first(where: { $0.id == workoutPlanId }) else { return }

        currentSession = Session(workoutPlanId: plan.id)
        currentExerciseIndex = 0
        currentSetIndex = 0

        // Show pre-workout feeling screen
        sessionState = .preWorkout
    }

    func logPreWorkoutFeeling(_ feeling: PreWorkoutFeeling) {
        currentSession?.preWorkoutFeeling = feeling

        // Start first exercise after logging feeling
        guard let plan = workoutPlans.first(where: { $0.id == currentSession?.workoutPlanId ?? UUID() }),
              let firstExerciseId = plan.order.first else { return }

        startExercise(exerciseId: firstExerciseId)
    }

    func startExercise(exerciseId: UUID) {
        guard let profile = exerciseProfiles[exerciseId] else { return }

        // Get starting weight from state or use default
        let startWeight = exerciseStates[exerciseId]?.lastStartLoad ?? 45.0  // Default bar weight

        currentExerciseLog = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: startWeight
        )

        currentSetIndex = 0
        sessionState = .warmup(step: 0)
    }

    // MARK: - Warmup Flow

    func advanceWarmup() {
        guard case .warmup(let step) = sessionState else { return }
        guard let exerciseLog = currentExerciseLog,
              let profile = exerciseProfiles[exerciseLog.exerciseId] else { return }

        if step == 0 {
            // Move to 70%×3
            sessionState = .warmup(step: 1)
        } else {
            // Warmup complete, move to load
            sessionState = .load
            computeInitialPrescription()
        }
    }

    func getWarmupPrescription() -> (weight: Double, reps: Int)? {
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

    func acknowledgeLoad() {
        sessionState = .workingSet
    }

    // MARK: - Working Set Flow

    func logSet(reps: Int, rating: Rating) {
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
    }

    func advanceToNextSet() {
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
                self?.sessionState = .rest(timeRemaining: remaining)
            }
            .store(in: &cancellables)
    }

    func adjustRestTime(by seconds: Int) {
        restTimer?.adjustTime(by: seconds)
    }

    // MARK: - Exercise Completion

    func finishExercise() {
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

    func advanceToNextExercise() {
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

    func finishSession() {
        guard var session = currentSession else { return }

        // Calculate stats
        let totalVolume = session.exerciseLogs.reduce(0.0) { total, log in
            let exerciseVolume = log.setLogs.reduce(0.0) { setTotal, set in
                setTotal + (Double(set.achievedReps) * set.actualWeight)
            }
            return total + exerciseVolume
        }

        session.stats.totalVolume = totalVolume

        // Save session
        currentSession = session
        persistSession()

        sessionState = .done
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
        // TODO: Query last 7 days of sessions for this exercise
        return []
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
        guard let session = currentSession else { return }

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
        // Load exercise states
        exerciseStates = PersistenceManager.shared.loadExerciseStates()

        // Load profiles (or use defaults if none exist)
        let savedProfiles = PersistenceManager.shared.loadExerciseProfiles()
        if !savedProfiles.isEmpty {
            exerciseProfiles = savedProfiles
        }

        // Load workout plans
        let savedPlans = PersistenceManager.shared.loadWorkoutPlans()
        if !savedPlans.isEmpty {
            workoutPlans = savedPlans
        }

        // Resume current session if exists
        if let savedSession = PersistenceManager.shared.loadCurrentSession() {
            currentSession = savedSession
            // TODO: Restore state to allow mid-session resume
        }
    }

    // MARK: - Default Data

    private func loadDefaultExercises() {
        let benchPress = ExerciseProfile(
            name: "Barbell Bench Press",
            category: .barbell,
            priority: .upper,
            repRange: 5...8,
            sets: 3,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0,
            plateOptions: [45, 25, 10, 5, 2.5],
            defaultRestSec: 90
        )

        let squat = ExerciseProfile(
            name: "Barbell Squat",
            category: .barbell,
            priority: .lower,
            repRange: 5...8,
            sets: 4,
            baseIncrement: 10.0,
            rounding: 5.0,
            microAdjustStep: 5.0,
            weeklyCapPct: 10.0,
            plateOptions: [45, 25, 10, 5, 2.5],
            defaultRestSec: 120
        )

        exerciseProfiles[benchPress.id] = benchPress
        exerciseProfiles[squat.id] = squat
    }

    private func loadDefaultWorkoutPlan() {
        let exercises = Array(exerciseProfiles.keys)
        let defaultPlan = WorkoutPlan(
            name: "Default Push/Pull",
            order: exercises
        )
        workoutPlans.append(defaultPlan)
    }
}