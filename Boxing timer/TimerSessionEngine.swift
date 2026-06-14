import Foundation

struct TimerSessionSnapshot: Equatable {
    let phase: TimerPhase
    let timeRemaining: Int
    let elapsedSeconds: Int
    let currentStep: Int
    let totalSteps: Int
    let progress: Double
    let segmentIndex: Int
    let isFinished: Bool
}

private struct TimerSessionSegment {
    let phase: TimerPhase
    let duration: Int
    let currentStep: Int
    let totalSteps: Int
}

struct TimerSessionEngine {
    private var segments: [TimerSessionSegment]
    private var elapsedBeforeRun: TimeInterval = 0
    private var runningStartedAt: Date?

    static func fight(preset: FightPreset) -> TimerSessionEngine {
        var segments: [TimerSessionSegment] = []
        let rounds = max(1, preset.rounds)
        if preset.warmupSeconds > 0 {
            segments.append(TimerSessionSegment(phase: .warmup, duration: preset.warmupSeconds, currentStep: 0, totalSteps: rounds))
        }
        for round in 1...rounds {
            segments.append(TimerSessionSegment(phase: .round, duration: preset.roundSeconds, currentStep: round, totalSteps: rounds))
            if round < rounds && preset.restSeconds > 0 {
                segments.append(TimerSessionSegment(phase: .rest, duration: preset.restSeconds, currentStep: round, totalSteps: rounds))
            }
        }
        return TimerSessionEngine(segments: segments.filter { $0.duration > 0 })
    }

    static func interval(workout: IntervalWorkout) -> TimerSessionEngine {
        var segments: [TimerSessionSegment] = []
        let intervals = max(1, workout.intervals)
        if workout.warmupSeconds > 0 {
            segments.append(TimerSessionSegment(phase: .warmup, duration: workout.warmupSeconds, currentStep: 0, totalSteps: intervals))
        }
        for interval in 1...intervals {
            segments.append(TimerSessionSegment(phase: .round, duration: workout.workSeconds, currentStep: interval, totalSteps: intervals))
            if interval < intervals && workout.restSeconds > 0 {
                segments.append(TimerSessionSegment(phase: .rest, duration: workout.restSeconds, currentStep: interval, totalSteps: intervals))
            }
        }
        if workout.cooldownSeconds > 0 {
            segments.append(TimerSessionSegment(phase: .cooldown, duration: workout.cooldownSeconds, currentStep: intervals, totalSteps: intervals))
        }
        return TimerSessionEngine(segments: segments.filter { $0.duration > 0 })
    }

    var isRunning: Bool {
        runningStartedAt != nil
    }

    var totalDuration: Int {
        segments.reduce(0) { $0 + $1.duration }
    }

    mutating func start(at date: Date) {
        guard runningStartedAt == nil else { return }
        runningStartedAt = date
    }

    mutating func pause(at date: Date) {
        elapsedBeforeRun = elapsed(at: date)
        runningStartedAt = nil
    }

    mutating func reset() {
        elapsedBeforeRun = 0
        runningStartedAt = nil
    }

    mutating func skip(at date: Date) {
        let current = snapshot(at: date)
        elapsedBeforeRun = TimeInterval(segmentEndElapsed(for: current.segmentIndex))
        if runningStartedAt != nil {
            runningStartedAt = date
        }
    }

    func snapshot(at date: Date) -> TimerSessionSnapshot {
        let clampedElapsed = min(max(elapsed(at: date), 0), TimeInterval(totalDuration))
        let elapsedSeconds = Int(clampedElapsed.rounded(.down))

        guard !segments.isEmpty, elapsedSeconds < totalDuration else {
            return TimerSessionSnapshot(
                phase: .finished,
                timeRemaining: 0,
                elapsedSeconds: totalDuration,
                currentStep: segments.last?.totalSteps ?? 0,
                totalSteps: segments.last?.totalSteps ?? 0,
                progress: 1,
                segmentIndex: segments.count,
                isFinished: true
            )
        }

        var segmentStart = 0
        for (index, segment) in segments.enumerated() {
            let segmentEnd = segmentStart + segment.duration
            if elapsedSeconds < segmentEnd {
                let elapsedInSegment = elapsedSeconds - segmentStart
                let remaining = max(segment.duration - elapsedInSegment, 0)
                let progress = segment.duration > 0 ? Double(elapsedInSegment) / Double(segment.duration) : 1
                return TimerSessionSnapshot(
                    phase: segment.phase,
                    timeRemaining: remaining,
                    elapsedSeconds: elapsedSeconds,
                    currentStep: segment.currentStep,
                    totalSteps: segment.totalSteps,
                    progress: progress,
                    segmentIndex: index,
                    isFinished: false
                )
            }
            segmentStart = segmentEnd
        }

        return TimerSessionSnapshot(
            phase: .finished,
            timeRemaining: 0,
            elapsedSeconds: totalDuration,
            currentStep: segments.last?.totalSteps ?? 0,
            totalSteps: segments.last?.totalSteps ?? 0,
            progress: 1,
            segmentIndex: segments.count,
            isFinished: true
        )
    }

    private func elapsed(at date: Date) -> TimeInterval {
        guard let runningStartedAt else { return elapsedBeforeRun }
        return elapsedBeforeRun + max(0, date.timeIntervalSince(runningStartedAt))
    }

    private func segmentEndElapsed(for segmentIndex: Int) -> Int {
        guard segmentIndex < segments.count else { return totalDuration }
        return segments.prefix(segmentIndex + 1).reduce(0) { $0 + $1.duration }
    }

    func futureTransitions(from date: Date) -> [(Date, TimerPhase)] {
        guard isRunning else { return [] }
        var transitions: [(Date, TimerPhase)] = []
        
        let currentElapsed = elapsed(at: date)
        guard currentElapsed < TimeInterval(totalDuration) else { return [] }
        
        var segmentStart = 0
        for (index, segment) in segments.enumerated() {
            let segmentEnd = segmentStart + segment.duration
            if Double(segmentEnd) > currentElapsed {
                let secondsUntilEnd = Double(segmentEnd) - currentElapsed
                let transitionDate = date.addingTimeInterval(secondsUntilEnd)
                let nextPhase: TimerPhase = index + 1 < segments.count ? segments[index + 1].phase : .finished
                transitions.append((transitionDate, nextPhase))
            }
            segmentStart = segmentEnd
        }
        return transitions
    }
}
