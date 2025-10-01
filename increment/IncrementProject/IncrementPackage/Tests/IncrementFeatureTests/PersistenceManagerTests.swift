import Testing
import Foundation
@testable import IncrementFeature

/// Tests for PersistenceManager
/// Validates data persistence using UserDefaults for sessions, exercise states, and profiles
@Suite("PersistenceManager Tests")
struct PersistenceManagerTests {

    /// Test saving and loading sessions
    @Test("PersistenceManager: Saves and loads sessions correctly")
    func testSaveLoadSessions() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()  // Start fresh

        let workoutPlanId = UUID()
        let exerciseId = UUID()
        let exerciseLog = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: 100.0
        )

        let session1 = Session(
            workoutPlanId: workoutPlanId,
            exerciseLogs: [exerciseLog],
            stats: SessionStats(totalVolume: 2400.0)
        )

        let session2 = Session(
            workoutPlanId: workoutPlanId,
            stats: SessionStats(totalVolume: 3000.0)
        )

        let sessions = [session1, session2]

        // Act
        manager.saveSessions(sessions)
        let loaded = manager.loadSessions()

        // Assert
        #expect(loaded.count == 2)
        #expect(loaded[0].id == session1.id)
        #expect(loaded[1].id == session2.id)
        #expect(loaded[0].stats.totalVolume == 2400.0)
        #expect(loaded[1].stats.totalVolume == 3000.0)

        // Cleanup
        manager.clearAll()
    }

    /// Test loading sessions when none exist returns empty array
    @Test("PersistenceManager: Returns empty array when no sessions")
    func testLoadSessionsEmpty() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        // Act
        let loaded = manager.loadSessions()

        // Assert
        #expect(loaded.isEmpty)
    }

    /// Test saving and loading current session
    @Test("PersistenceManager: Saves and loads current session")
    func testSaveLoadCurrentSession() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        let workoutPlanId = UUID()
        let feeling = PreWorkoutFeeling(rating: 4, note: "Ready to go")
        let session = Session(
            workoutPlanId: workoutPlanId,
            preWorkoutFeeling: feeling
        )

        // Act
        manager.saveCurrentSession(session)
        let loaded = manager.loadCurrentSession()

        // Assert
        #expect(loaded != nil)
        #expect(loaded?.id == session.id)
        #expect(loaded?.workoutPlanId == workoutPlanId)
        #expect(loaded?.preWorkoutFeeling?.rating == 4)
        #expect(loaded?.preWorkoutFeeling?.note == "Ready to go")

        // Cleanup
        manager.clearAll()
    }

    /// Test saving nil current session removes it
    @Test("PersistenceManager: Saving nil removes current session")
    func testSaveCurrentSessionNil() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        let session = Session(workoutPlanId: UUID())
        manager.saveCurrentSession(session)

        // Act - Save nil
        manager.saveCurrentSession(nil)
        let loaded = manager.loadCurrentSession()

        // Assert
        #expect(loaded == nil)

        // Cleanup
        manager.clearAll()
    }

    /// Test loading current session when none exists returns nil
    @Test("PersistenceManager: Returns nil when no current session")
    func testLoadCurrentSessionNil() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        // Act
        let loaded = manager.loadCurrentSession()

        // Assert
        #expect(loaded == nil)
    }

    /// Test saving and loading exercise states
    @Test("PersistenceManager: Saves and loads exercise states")
    func testSaveLoadExerciseStates() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        let exerciseId1 = UUID()
        let exerciseId2 = UUID()

        let state1 = ExerciseState(
            exerciseId: exerciseId1,
            lastStartLoad: 105.0,
            lastDecision: .up_1,
            lastUpdatedAt: Date()
        )

        let state2 = ExerciseState(
            exerciseId: exerciseId2,
            lastStartLoad: 225.0,
            lastDecision: .hold,
            lastUpdatedAt: Date()
        )

        let states = [
            exerciseId1: state1,
            exerciseId2: state2
        ]

        // Act
        manager.saveExerciseStates(states)
        let loaded = manager.loadExerciseStates()

        // Assert
        #expect(loaded.count == 2)
        #expect(loaded[exerciseId1]?.lastStartLoad == 105.0)
        #expect(loaded[exerciseId1]?.lastDecision == .up_1)
        #expect(loaded[exerciseId2]?.lastStartLoad == 225.0)
        #expect(loaded[exerciseId2]?.lastDecision == .hold)

        // Cleanup
        manager.clearAll()
    }

    /// Test loading exercise states when none exist returns empty dictionary
    @Test("PersistenceManager: Returns empty dict when no exercise states")
    func testLoadExerciseStatesEmpty() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        // Act
        let loaded = manager.loadExerciseStates()

        // Assert
        #expect(loaded.isEmpty)
    }

    /// Test saving and loading exercise profiles
    @Test("PersistenceManager: Saves and loads exercise profiles")
    func testSaveLoadExerciseProfiles() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        let benchPress = ExerciseProfile(
            name: "Bench Press",
            category: .barbell,
            priority: .upper,
            repRange: 5...8,
            sets: 3,
            baseIncrement: 5.0,
            rounding: 2.5,
            weeklyCapPct: 5.0,
            defaultRestSec: 90
        )

        let squat = ExerciseProfile(
            name: "Squat",
            category: .barbell,
            priority: .lower,
            repRange: 5...8,
            sets: 4,
            baseIncrement: 10.0,
            rounding: 5.0,
            weeklyCapPct: 10.0,
            defaultRestSec: 120
        )

        let profiles = [
            benchPress.id: benchPress,
            squat.id: squat
        ]

        // Act
        manager.saveExerciseProfiles(profiles)
        let loaded = manager.loadExerciseProfiles()

        // Assert
        #expect(loaded.count == 2)
        #expect(loaded[benchPress.id]?.name == "Bench Press")
        #expect(loaded[benchPress.id]?.category == .barbell)
        #expect(loaded[benchPress.id]?.priority == .upper)
        #expect(loaded[benchPress.id]?.repRange == 5...8)
        #expect(loaded[squat.id]?.name == "Squat")
        #expect(loaded[squat.id]?.sets == 4)
        #expect(loaded[squat.id]?.baseIncrement == 10.0)

        // Cleanup
        manager.clearAll()
    }

    /// Test loading exercise profiles when none exist returns empty dictionary
    @Test("PersistenceManager: Returns empty dict when no profiles")
    func testLoadExerciseProfilesEmpty() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        // Act
        let loaded = manager.loadExerciseProfiles()

        // Assert
        #expect(loaded.isEmpty)
    }

    /// Test saving and loading workout plans
    @Test("PersistenceManager: Saves and loads workout plans")
    func testSaveLoadWorkoutPlans() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        let exerciseIds1 = [UUID(), UUID()]
        let exerciseIds2 = [UUID(), UUID(), UUID()]

        let plan1 = WorkoutPlan(name: "Push Day", order: exerciseIds1)
        let plan2 = WorkoutPlan(name: "Pull Day", order: exerciseIds2)

        let plans = [plan1, plan2]

        // Act
        manager.saveWorkoutPlans(plans)
        let loaded = manager.loadWorkoutPlans()

        // Assert
        #expect(loaded.count == 2)
        #expect(loaded[0].name == "Push Day")
        #expect(loaded[0].order.count == 2)
        #expect(loaded[1].name == "Pull Day")
        #expect(loaded[1].order.count == 3)

        // Cleanup
        manager.clearAll()
    }

    /// Test loading workout plans when none exist returns empty array
    @Test("PersistenceManager: Returns empty array when no plans")
    func testLoadWorkoutPlansEmpty() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        // Act
        let loaded = manager.loadWorkoutPlans()

        // Assert
        #expect(loaded.isEmpty)
    }

    /// Test clearAll removes all persisted data
    @Test("PersistenceManager: ClearAll removes all data")
    func testClearAll() {
        // Arrange
        let manager = PersistenceManager.shared

        // Add some data
        let session = Session(workoutPlanId: UUID())
        manager.saveCurrentSession(session)
        manager.saveSessions([session])

        let exerciseId = UUID()
        let state = ExerciseState(
            exerciseId: exerciseId,
            lastStartLoad: 100.0,
            lastDecision: .hold,
            lastUpdatedAt: Date()
        )
        manager.saveExerciseStates([exerciseId: state])

        let profile = ExerciseProfile(
            name: "Test",
            category: .barbell,
            priority: .upper,
            repRange: 5...8,
            sets: 3,
            baseIncrement: 5.0,
            rounding: 2.5,
            weeklyCapPct: 5.0,
            defaultRestSec: 90
        )
        manager.saveExerciseProfiles([profile.id: profile])

        let plan = WorkoutPlan(name: "Test Plan", order: [exerciseId])
        manager.saveWorkoutPlans([plan])

        // Act
        manager.clearAll()

        // Assert - All should be empty/nil
        #expect(manager.loadCurrentSession() == nil)
        #expect(manager.loadSessions().isEmpty)
        #expect(manager.loadExerciseStates().isEmpty)
        #expect(manager.loadExerciseProfiles().isEmpty)
        #expect(manager.loadWorkoutPlans().isEmpty)
    }

    /// Test exportData returns all persisted data
    @Test("PersistenceManager: ExportData returns all data")
    func testExportData() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        let session = Session(workoutPlanId: UUID())
        manager.saveSessions([session])

        let exerciseId = UUID()
        let state = ExerciseState(
            exerciseId: exerciseId,
            lastStartLoad: 100.0,
            lastDecision: .hold,
            lastUpdatedAt: Date()
        )
        manager.saveExerciseStates([exerciseId: state])

        // Act
        let exported = manager.exportData()

        // Assert
        #expect(exported["sessions"] != nil)
        #expect(exported["exerciseStates"] != nil)
        #expect(exported["exerciseProfiles"] != nil)
        #expect(exported["workoutPlans"] != nil)

        // Cleanup
        manager.clearAll()
    }

    /// Test data persists across manager instances (singleton behavior)
    @Test("PersistenceManager: Data persists across manager instances")
    func testSingletonPersistence() {
        // Arrange
        let manager1 = PersistenceManager.shared
        manager1.clearAll()

        let session = Session(workoutPlanId: UUID())
        manager1.saveSessions([session])

        // Act - Access shared instance again
        let manager2 = PersistenceManager.shared
        let loaded = manager2.loadSessions()

        // Assert
        #expect(loaded.count == 1)
        #expect(loaded[0].id == session.id)

        // Cleanup
        manager1.clearAll()
    }

    /// Test updating existing session in sessions array
    @Test("PersistenceManager: Can update existing session")
    func testUpdateExistingSession() {
        // Arrange
        let manager = PersistenceManager.shared
        manager.clearAll()

        let workoutPlanId = UUID()
        var session = Session(
            workoutPlanId: workoutPlanId,
            stats: SessionStats(totalVolume: 1000.0)
        )

        manager.saveSessions([session])

        // Act - Update the session
        session.stats.totalVolume = 2000.0
        var sessions = manager.loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        manager.saveSessions(sessions)

        // Assert
        let loaded = manager.loadSessions()
        #expect(loaded.count == 1)
        #expect(loaded[0].stats.totalVolume == 2000.0)

        // Cleanup
        manager.clearAll()
    }
}
