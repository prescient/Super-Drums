import XCTest
@testable import SuperDrums

@MainActor
final class DSPEngineTests: XCTestCase {

    // MARK: - Initialization

    func test_init_isNotRunning() {
        let engine = DSPEngine()
        XCTAssertFalse(engine.isRunning)
    }

    func test_init_hasDefaultSampleRate() {
        let engine = DSPEngine()
        XCTAssertEqual(engine.sampleRate, 44100.0)
    }

    // MARK: - Engine Lifecycle

    func test_start_setsIsRunningTrue() throws {
        let engine = DSPEngine()
        try engine.start()
        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    func test_stop_setsIsRunningFalse() throws {
        let engine = DSPEngine()
        try engine.start()
        engine.stop()
        XCTAssertFalse(engine.isRunning)
    }

    func test_start_calledTwice_doesNotThrow() throws {
        let engine = DSPEngine()
        try engine.start()
        try engine.start() // Should not throw
        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    // MARK: - Transport Controls

    func test_startPlayback_withBPMAndStepCount() throws {
        let engine = DSPEngine()
        try engine.start()

        engine.startPlayback(bpm: 120.0, stepCount: 16)

        // Engine should be running (playback state is internal)
        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    func test_stopPlayback_afterStart() throws {
        let engine = DSPEngine()
        try engine.start()
        engine.startPlayback(bpm: 120.0, stepCount: 16)

        engine.stopPlayback()

        XCTAssertTrue(engine.isRunning) // Engine still running, just not playing
        engine.stop()
    }

    // MARK: - BPM & Swing

    func test_setBPM_acceptsValidBPM() throws {
        let engine = DSPEngine()
        try engine.start()

        engine.setBPM(140.0)

        // No crash, BPM set internally
        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    func test_setSwing_acceptsValidSwing() throws {
        let engine = DSPEngine()
        try engine.start()

        engine.setSwing(0.6)

        // No crash, swing set internally
        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    // MARK: - Pattern Updates

    func test_updatePattern_withEmptyPattern() throws {
        let engine = DSPEngine()
        try engine.start()

        let pattern = Pattern()
        let voices = DrumVoiceType.allCases.map { Voice(voiceType: $0) }

        engine.updatePattern(pattern, voices: voices)

        // Should not crash with empty pattern
        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    func test_updatePattern_withActiveSteps() throws {
        let engine = DSPEngine()
        try engine.start()

        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 0)
        pattern.toggleStep(voice: .snare, stepIndex: 4)

        let voices = DrumVoiceType.allCases.map { Voice(voiceType: $0) }

        engine.updatePattern(pattern, voices: voices)

        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    func test_updatePattern_handlesMutedVoices() throws {
        let engine = DSPEngine()
        try engine.start()

        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 0)

        var voices = DrumVoiceType.allCases.map { Voice(voiceType: $0) }
        voices[0].isMuted = true

        engine.updatePattern(pattern, voices: voices)

        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    func test_updatePattern_handlesSoloedVoices() throws {
        let engine = DSPEngine()
        try engine.start()

        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 0)
        pattern.toggleStep(voice: .snare, stepIndex: 4)

        var voices = DrumVoiceType.allCases.map { Voice(voiceType: $0) }
        voices[1].isSoloed = true // Solo snare

        engine.updatePattern(pattern, voices: voices)

        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    // MARK: - Voice Triggering

    func test_triggerVoice_doesNotCrash() throws {
        let engine = DSPEngine()
        try engine.start()

        engine.triggerVoice(.kick, velocity: 1.0)
        engine.triggerVoice(.snare, velocity: 0.5)
        engine.triggerVoice(.closedHat, velocity: 0.8)

        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    func test_triggerVoice_allVoiceTypes() throws {
        let engine = DSPEngine()
        try engine.start()

        for voiceType in DrumVoiceType.allCases {
            engine.triggerVoice(voiceType, velocity: 0.75)
        }

        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    func test_triggerVoice_zeroVelocity() throws {
        let engine = DSPEngine()
        try engine.start()

        engine.triggerVoice(.kick, velocity: 0.0)

        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    // MARK: - Metering

    func test_getVoiceLevel_returnsValue() throws {
        let engine = DSPEngine()
        try engine.start()

        let level = engine.getVoiceLevel(.kick)

        // Level should be a valid float (0 or more)
        XCTAssertGreaterThanOrEqual(level, 0.0)
        engine.stop()
    }

    func test_getOutputLevels_returnsTuple() throws {
        let engine = DSPEngine()
        try engine.start()

        let (left, right) = engine.getOutputLevels()

        // Levels should be valid floats
        XCTAssertGreaterThanOrEqual(left, 0.0)
        XCTAssertGreaterThanOrEqual(right, 0.0)
        engine.stop()
    }

    // MARK: - Callbacks

    func test_onStepAdvanced_canBeSet() throws {
        let engine = DSPEngine()

        var callbackCalled = false
        engine.onStepAdvanced = { _ in
            callbackCalled = true
        }

        XCTAssertNotNil(engine.onStepAdvanced)
    }

    func test_onVoiceTriggered_canBeSet() throws {
        let engine = DSPEngine()

        engine.onVoiceTriggered = { _, _ in }

        XCTAssertNotNil(engine.onVoiceTriggered)
    }

    // MARK: - Edge Cases

    func test_stopWithoutStart_doesNotCrash() {
        let engine = DSPEngine()
        engine.stop() // Should not crash
        XCTAssertFalse(engine.isRunning)
    }

    func test_stopPlaybackWithoutStartPlayback_doesNotCrash() throws {
        let engine = DSPEngine()
        try engine.start()

        engine.stopPlayback() // Should not crash

        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    func test_updatePatternWithoutStart_doesNotCrash() {
        let engine = DSPEngine()

        let pattern = Pattern()
        let voices = DrumVoiceType.allCases.map { Voice(voiceType: $0) }

        engine.updatePattern(pattern, voices: voices) // Should not crash
    }

    func test_triggerVoiceWithoutStart_doesNotCrash() {
        let engine = DSPEngine()
        engine.triggerVoice(.kick, velocity: 1.0) // Should not crash
    }
}
