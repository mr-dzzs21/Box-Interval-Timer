import XCTest
@testable import Boxing_timer

final class TimerSessionEngineTests: XCTestCase {
    func testFightTimerPhaseBoundariesAreExact() {
        let preset = FightPreset(
            name: "Test",
            warmupSeconds: 5,
            rounds: 2,
            roundSeconds: 10,
            restSeconds: 3
        )
        var engine = TimerSessionEngine.fight(preset: preset)
        let start = Date(timeIntervalSince1970: 0)

        engine.start(at: start)

        XCTAssertEqual(engine.snapshot(at: start).phase, .warmup)
        XCTAssertEqual(engine.snapshot(at: start).timeRemaining, 5)

        let firstRound = engine.snapshot(at: start.addingTimeInterval(5))
        XCTAssertEqual(firstRound.phase, .round)
        XCTAssertEqual(firstRound.currentStep, 1)
        XCTAssertEqual(firstRound.timeRemaining, 10)

        let rest = engine.snapshot(at: start.addingTimeInterval(15))
        XCTAssertEqual(rest.phase, .rest)
        XCTAssertEqual(rest.timeRemaining, 3)

        let secondRound = engine.snapshot(at: start.addingTimeInterval(18))
        XCTAssertEqual(secondRound.phase, .round)
        XCTAssertEqual(secondRound.currentStep, 2)
        XCTAssertEqual(secondRound.timeRemaining, 10)

        let finished = engine.snapshot(at: start.addingTimeInterval(28))
        XCTAssertEqual(finished.phase, .finished)
        XCTAssertEqual(finished.timeRemaining, 0)
        XCTAssertTrue(finished.isFinished)
    }

    func testPauseAndResumePreserveRemainingTime() {
        let preset = FightPreset(
            name: "Test",
            warmupSeconds: 0,
            rounds: 1,
            roundSeconds: 30,
            restSeconds: 0
        )
        var engine = TimerSessionEngine.fight(preset: preset)
        let start = Date(timeIntervalSince1970: 0)

        engine.start(at: start)
        engine.pause(at: start.addingTimeInterval(8))

        XCTAssertEqual(engine.snapshot(at: start.addingTimeInterval(100)).timeRemaining, 22)

        engine.start(at: start.addingTimeInterval(100))
        XCTAssertEqual(engine.snapshot(at: start.addingTimeInterval(105)).timeRemaining, 17)
    }

    func testIntervalTimerSkipsZeroLengthCooldown() {
        let workout = IntervalWorkout(
            device: .bagWork,
            level: .intermediate,
            warmupSeconds: 0,
            intervals: 1,
            workSeconds: 20,
            restSeconds: 0,
            cooldownSeconds: 0
        )
        var engine = TimerSessionEngine.interval(workout: workout)
        let start = Date(timeIntervalSince1970: 0)

        engine.start(at: start)

        XCTAssertEqual(engine.snapshot(at: start).phase, .round)
        XCTAssertEqual(engine.snapshot(at: start).timeRemaining, 20)
        XCTAssertEqual(engine.snapshot(at: start.addingTimeInterval(20)).phase, .finished)
    }
}
