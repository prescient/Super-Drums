import XCTest
@testable import SuperDrums

final class PatternTests: XCTestCase {

    // MARK: - Step Toggling

    func test_toggleStep_activatesInactiveStep() {
        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 0)

        let step = pattern.step(voice: .kick, stepIndex: 0)
        XCTAssertTrue(step?.isActive == true)
    }

    func test_toggleStep_deactivatesActiveStep() {
        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 0)
        pattern.toggleStep(voice: .kick, stepIndex: 0)

        let step = pattern.step(voice: .kick, stepIndex: 0)
        XCTAssertFalse(step?.isActive == true)
    }

    func test_toggleStep_worksForAllVoiceTypes() {
        var pattern = Pattern()

        for voiceType in DrumVoiceType.allCases {
            pattern.toggleStep(voice: voiceType, stepIndex: 0)
            let step = pattern.step(voice: voiceType, stepIndex: 0)
            XCTAssertTrue(step?.isActive == true, "Failed for \(voiceType)")
        }
    }

    // MARK: - Velocity

    func test_setStepVelocity_updatesVelocity() {
        var pattern = Pattern()
        pattern.toggleStep(voice: .snare, stepIndex: 4)
        pattern.setStepVelocity(voice: .snare, stepIndex: 4, velocity: 100)

        let step = pattern.step(voice: .snare, stepIndex: 4)
        XCTAssertEqual(step?.velocity, 100)
    }

    // MARK: - Shift

    func test_shift_movesStepsRight() {
        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 0)
        pattern.shift(by: 1)

        XCTAssertFalse(pattern.step(voice: .kick, stepIndex: 0)?.isActive == true)
        XCTAssertTrue(pattern.step(voice: .kick, stepIndex: 1)?.isActive == true)
    }

    func test_shift_movesStepsLeft() {
        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 4)
        pattern.shift(by: -1)

        XCTAssertFalse(pattern.step(voice: .kick, stepIndex: 4)?.isActive == true)
        XCTAssertTrue(pattern.step(voice: .kick, stepIndex: 3)?.isActive == true)
    }

    func test_shift_wrapsAroundRight() {
        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 15)
        pattern.shift(by: 1)

        XCTAssertFalse(pattern.step(voice: .kick, stepIndex: 15)?.isActive == true)
        XCTAssertTrue(pattern.step(voice: .kick, stepIndex: 0)?.isActive == true)
    }

    func test_shift_wrapsAroundLeft() {
        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 0)
        pattern.shift(by: -1)

        XCTAssertFalse(pattern.step(voice: .kick, stepIndex: 0)?.isActive == true)
        XCTAssertTrue(pattern.step(voice: .kick, stepIndex: 15)?.isActive == true)
    }

    // MARK: - Clear

    func test_clear_removesAllActiveSteps() {
        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 0)
        pattern.toggleStep(voice: .snare, stepIndex: 4)
        pattern.toggleStep(voice: .closedHat, stepIndex: 8)

        pattern.clear()

        for voiceType in DrumVoiceType.allCases {
            for i in 0..<16 {
                XCTAssertFalse(pattern.step(voice: voiceType, stepIndex: i)?.isActive == true)
            }
        }
    }

    // MARK: - Duplicate

    func test_duplicate_createsNewPatternWithDifferentID() {
        let original = Pattern(name: "Original")
        let copy = original.duplicate()

        XCTAssertNotEqual(original.id, copy.id)
        XCTAssertTrue(copy.name.contains("Copy"))
    }

    func test_duplicate_preservesStepData() {
        var original = Pattern(name: "Original")
        original.toggleStep(voice: .kick, stepIndex: 0)
        original.setStepVelocity(voice: .kick, stepIndex: 0, velocity: 127)

        let copy = original.duplicate()

        let originalStep = original.step(voice: .kick, stepIndex: 0)
        let copyStep = copy.step(voice: .kick, stepIndex: 0)

        XCTAssertEqual(originalStep?.isActive, copyStep?.isActive)
        XCTAssertEqual(originalStep?.velocity, copyStep?.velocity)
    }
}
