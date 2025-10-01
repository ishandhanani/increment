import Testing
import Foundation
@testable import IncrementFeature

/// Tests for RestTimer
/// Validates timer functionality including start, stop, pause, resume, and time adjustments
@Suite("RestTimer Tests")
struct RestTimerTests {

    /// Test timer starts with correct duration
    @Test("RestTimer: Starts with correct duration")
    func testTimerStart() async {
        // Arrange
        let timer = RestTimer()
        let duration = 10

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        // Assert
        await MainActor.run {
            #expect(timer.timeRemaining == duration)
            #expect(timer.isRunning == true)
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test timer counts down
    @Test("RestTimer: Counts down over time")
    func testTimerCountsDown() async throws {
        // Arrange
        let timer = RestTimer()
        let duration = 5

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        // Wait for timer to tick
        try await Task.sleep(for: .seconds(1.5))

        // Assert - Should have counted down
        await MainActor.run {
            #expect(timer.timeRemaining < duration)
            #expect(timer.timeRemaining >= 0)
            #expect(timer.isRunning == true)
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test timer pause functionality
    @Test("RestTimer: Pause stops countdown")
    func testTimerPause() async throws {
        // Arrange
        let timer = RestTimer()
        let duration = 10

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        try await Task.sleep(for: .seconds(1))

        let timeBeforePause = await MainActor.run { timer.timeRemaining }

        await MainActor.run {
            timer.pause()
        }

        try await Task.sleep(for: .seconds(1))

        let timeAfterPause = await MainActor.run { timer.timeRemaining }

        // Assert
        await MainActor.run {
            #expect(timer.isRunning == false)
            #expect(timeAfterPause == timeBeforePause)  // Should not have changed
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test timer resume functionality
    @Test("RestTimer: Resume continues countdown")
    func testTimerResume() async throws {
        // Arrange
        let timer = RestTimer()
        let duration = 10

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        try await Task.sleep(for: .seconds(1))

        await MainActor.run {
            timer.pause()
        }

        let timeAtPause = await MainActor.run { timer.timeRemaining }

        await MainActor.run {
            timer.resume()
        }

        try await Task.sleep(for: .seconds(1))

        // Assert
        await MainActor.run {
            #expect(timer.isRunning == true)
            #expect(timer.timeRemaining < timeAtPause)  // Should have continued counting
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test timer stop resets state
    @Test("RestTimer: Stop resets timer state")
    func testTimerStop() async {
        // Arrange
        let timer = RestTimer()
        let duration = 10

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        await MainActor.run {
            timer.stop()
        }

        // Assert
        await MainActor.run {
            #expect(timer.timeRemaining == 0)
            #expect(timer.isRunning == false)
        }
    }

    /// Test adjusting time while running adds time
    @Test("RestTimer: Adjust time adds seconds while running")
    func testAdjustTimeRunning() async throws {
        // Arrange
        let timer = RestTimer()
        let duration = 10

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        try await Task.sleep(for: .seconds(0.5))

        let timeBefore = await MainActor.run { timer.timeRemaining }

        await MainActor.run {
            timer.adjustTime(by: 5)  // Add 5 seconds
        }

        // Assert
        await MainActor.run {
            #expect(timer.timeRemaining > timeBefore)
            #expect(timer.isRunning == true)
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test adjusting time while running removes time
    @Test("RestTimer: Adjust time removes seconds while running")
    func testAdjustTimeRemoveRunning() async throws {
        // Arrange
        let timer = RestTimer()
        let duration = 30

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        try await Task.sleep(for: .seconds(0.5))

        let timeBefore = await MainActor.run { timer.timeRemaining }

        await MainActor.run {
            timer.adjustTime(by: -10)  // Remove 10 seconds
        }

        // Assert
        await MainActor.run {
            #expect(timer.timeRemaining < timeBefore)
            #expect(timer.timeRemaining >= 0)  // Should not go negative
            #expect(timer.isRunning == true)
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test adjusting time while paused
    @Test("RestTimer: Adjust time works while paused")
    func testAdjustTimePaused() async throws {
        // Arrange
        let timer = RestTimer()
        let duration = 10

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        try await Task.sleep(for: .seconds(1))

        await MainActor.run {
            timer.pause()
        }

        let timeBefore = await MainActor.run { timer.timeRemaining }

        await MainActor.run {
            timer.adjustTime(by: 5)
        }

        // Assert
        await MainActor.run {
            #expect(timer.timeRemaining == timeBefore + 5)
            #expect(timer.isRunning == false)
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test timer does not go negative when removing too much time
    @Test("RestTimer: Does not go negative with large negative adjustment")
    func testAdjustTimeNoNegative() async throws {
        // Arrange
        let timer = RestTimer()
        let duration = 5

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        try await Task.sleep(for: .seconds(0.5))

        await MainActor.run {
            timer.adjustTime(by: -100)  // Remove more than available
        }

        // Assert
        await MainActor.run {
            #expect(timer.timeRemaining >= 0)
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test timer reaches zero and pauses
    @Test("RestTimer: Reaches zero and pauses")
    func testTimerReachesZero() async throws {
        // Arrange
        let timer = RestTimer()
        let duration = 2  // Short duration

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        // Wait for timer to complete
        try await Task.sleep(for: .seconds(2.5))

        // Assert
        await MainActor.run {
            #expect(timer.timeRemaining == 0)
            #expect(timer.isRunning == false)  // Should auto-pause at zero
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test multiple start calls work correctly
    @Test("RestTimer: Can restart timer with new duration")
    func testRestartTimer() async throws {
        // Arrange
        let timer = RestTimer()

        // Act - First start
        await MainActor.run {
            timer.start(duration: 10)
        }

        try await Task.sleep(for: .seconds(1))

        // Act - Restart with new duration
        await MainActor.run {
            timer.start(duration: 20)
        }

        // Assert
        await MainActor.run {
            #expect(timer.timeRemaining == 20)
            #expect(timer.isRunning == true)
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test timer accuracy over short duration
    @Test("RestTimer: Maintains reasonable accuracy")
    func testTimerAccuracy() async throws {
        // Arrange
        let timer = RestTimer()
        let duration = 3

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        try await Task.sleep(for: .seconds(1))

        let timeRemaining = await MainActor.run { timer.timeRemaining }

        // Assert - Should be approximately 2 seconds remaining (allow 0.5s tolerance)
        #expect(timeRemaining >= 1.5 && timeRemaining <= 2.5)

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }

    /// Test resume does nothing if already running
    @Test("RestTimer: Resume does nothing if already running")
    func testResumeWhileRunning() async throws {
        // Arrange
        let timer = RestTimer()
        let duration = 10

        // Act
        await MainActor.run {
            timer.start(duration: duration)
        }

        try await Task.sleep(for: .seconds(0.5))

        let timeBefore = await MainActor.run { timer.timeRemaining }

        await MainActor.run {
            timer.resume()  // Should have no effect
        }

        let timeAfter = await MainActor.run { timer.timeRemaining }

        // Assert - Time should have continued normally
        await MainActor.run {
            #expect(timer.isRunning == true)
            // Time might have changed slightly but should be close
            #expect(abs(timeAfter - timeBefore) < 1.0)
        }

        // Cleanup
        await MainActor.run {
            timer.stop()
        }
    }
}
