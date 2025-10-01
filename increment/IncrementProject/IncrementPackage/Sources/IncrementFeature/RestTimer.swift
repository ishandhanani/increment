import Foundation
import Combine

/// Background-resilient rest timer using monotonic clock
public class RestTimer: ObservableObject {
    @Published var timeRemaining: Int = 0
    @Published var isRunning: Bool = false

    private var timer: AnyCancellable?
    private var startTime: CFAbsoluteTime?
    private var targetDuration: Int = 0
    private var pausedTimeRemaining: Int = 0

    // MARK: - Timer Control

    public func start(duration: Int) {
        targetDuration = duration
        timeRemaining = duration
        startTime = CFAbsoluteTimeGetCurrent()
        isRunning = true

        startMonotonicTimer()
    }

    public func pause() {
        isRunning = false
        pausedTimeRemaining = timeRemaining
        timer?.cancel()
        timer = nil
    }

    public func resume() {
        guard !isRunning else { return }

        targetDuration = pausedTimeRemaining
        timeRemaining = pausedTimeRemaining
        startTime = CFAbsoluteTimeGetCurrent()
        isRunning = true

        startMonotonicTimer()
    }

    public func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
        timeRemaining = 0
        startTime = nil
    }

    public func adjustTime(by seconds: Int) {
        guard isRunning, let start = startTime else {
            // If paused, adjust paused time
            pausedTimeRemaining = max(0, pausedTimeRemaining + seconds)
            timeRemaining = pausedTimeRemaining
            return
        }

        // Calculate new target duration
        let elapsed = Int(CFAbsoluteTimeGetCurrent() - start)
        let newTargetDuration = max(0, targetDuration + seconds)

        // Restart timer with adjusted duration
        targetDuration = newTargetDuration
        timeRemaining = max(0, targetDuration - elapsed)
    }

    // MARK: - Private Methods

    private func startMonotonicTimer() {
        timer?.cancel()

        // Use a timer that fires every 100ms for smooth updates
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTimeRemaining()
            }
    }

    private func updateTimeRemaining() {
        guard let start = startTime else {
            stop()
            return
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let remaining = targetDuration - Int(elapsed)

        if remaining <= 0 {
            timeRemaining = 0
            pause()
            // Timer reached 0 - show "Ready" state but don't auto-advance
        } else {
            timeRemaining = remaining
        }
    }

    // MARK: - Background Handling

    public func applicationDidEnterBackground() {
        // Timer continues running; CFAbsoluteTime is monotonic
        // No special action needed
    }

    public func applicationWillEnterForeground() {
        // Timer will automatically resume with correct time
        // The monotonic clock ensures accuracy
        if isRunning {
            updateTimeRemaining()
        }
    }
}