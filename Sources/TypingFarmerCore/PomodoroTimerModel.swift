import Foundation

public struct PomodoroTimerModel: Equatable, Sendable {
    public private(set) var durationMinutes: Int
    public private(set) var remainingSeconds: Int
    public private(set) var isRunning: Bool

    public init(settings: PomodoroSettings = PomodoroSettings()) {
        self.durationMinutes = settings.durationMinutes
        self.remainingSeconds = settings.durationMinutes * 60
        self.isRunning = false
    }

    public mutating func start() {
        if remainingSeconds <= 0 {
            remainingSeconds = durationMinutes * 60
        }
        isRunning = true
    }

    public mutating func pause() {
        isRunning = false
    }

    public mutating func reset() {
        isRunning = false
        remainingSeconds = durationMinutes * 60
    }

    public mutating func setDurationMinutes(_ minutes: Int) {
        let clamped = min(180, max(1, minutes))
        durationMinutes = clamped
        remainingSeconds = clamped * 60
        isRunning = false
    }

    @discardableResult
    public mutating func advance(seconds: Int) -> Int {
        guard isRunning, seconds > 0 else {
            return 0
        }

        if seconds >= remainingSeconds {
            remainingSeconds = durationMinutes * 60
            isRunning = false
            return 1
        }

        remainingSeconds -= seconds
        return 0
    }

    public var formattedRemainingTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
