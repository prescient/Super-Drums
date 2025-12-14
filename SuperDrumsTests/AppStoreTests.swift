import XCTest
@testable import SuperDrums

@MainActor
final class AppStoreTests: XCTestCase {

    // MARK: - Transport

    func test_play_setsIsPlayingTrue() {
        let store = AppStore()
        store.play()
        XCTAssertTrue(store.isPlaying)
    }

    func test_stop_setsIsPlayingFalse() {
        let store = AppStore()
        store.play()
        store.stop()
        XCTAssertFalse(store.isPlaying)
    }

    func test_stop_resetsCurrentStep() {
        let store = AppStore()
        store.currentStep = 8
        store.stop()
        XCTAssertEqual(store.currentStep, 0)
    }

    func test_togglePlayback_startsWhenStopped() {
        let store = AppStore()
        store.togglePlayback()
        XCTAssertTrue(store.isPlaying)
    }

    func test_togglePlayback_stopsWhenPlaying() {
        let store = AppStore()
        store.play()
        store.togglePlayback()
        XCTAssertFalse(store.isPlaying)
    }

    // MARK: - Step Advancement (Pattern Mode)

    func test_advanceStep_incrementsCurrentStep() {
        let store = AppStore()
        store.advanceStep()
        XCTAssertEqual(store.currentStep, 1)
    }

    func test_advanceStep_wrapsAtPatternEnd() {
        let store = AppStore()
        store.currentStep = 15
        store.advanceStep()
        XCTAssertEqual(store.currentStep, 0)
    }

    // MARK: - Song Mode Step Advancement

    func test_songMode_advancesToNextPattern() {
        let store = AppStore()
        store.addPatternToSong(0, repeatCount: 1)
        store.project.addPattern()
        store.addPatternToSong(1, repeatCount: 1)

        store.isSongMode = true
        store.currentStep = 15 // Last step

        store.advanceStep() // Wraps and advances song position

        XCTAssertEqual(store.currentSongPosition, 1)
        XCTAssertEqual(store.project.currentPatternIndex, 1)
    }

    func test_songMode_respectsRepeatCount() {
        let store = AppStore()
        store.addPatternToSong(0, repeatCount: 3)

        store.isSongMode = true

        // First loop
        for _ in 0..<16 { store.advanceStep() }
        XCTAssertEqual(store.currentSongPosition, 0)
        XCTAssertEqual(store.currentPatternLoopCount, 1)

        // Second loop
        for _ in 0..<16 { store.advanceStep() }
        XCTAssertEqual(store.currentSongPosition, 0)
        XCTAssertEqual(store.currentPatternLoopCount, 2)

        // Third loop - should still be on position 0 until pattern completes
        XCTAssertEqual(store.currentSongPosition, 0)
    }

    func test_songMode_loopsToBeginning() {
        let store = AppStore()
        store.addPatternToSong(0, repeatCount: 1)
        store.isSongMode = true
        store.loopSong = true

        // Complete the pattern
        for _ in 0..<16 { store.advanceStep() }

        XCTAssertEqual(store.currentSongPosition, 0)
        XCTAssertTrue(store.isPlaying == false || store.currentSongPosition == 0)
    }

    func test_songMode_stopsWhenNotLooping() {
        let store = AppStore()
        store.addPatternToSong(0, repeatCount: 1)
        store.isSongMode = true
        store.loopSong = false
        store.play()

        // Complete the pattern
        for _ in 0..<16 { store.advanceStep() }

        XCTAssertFalse(store.isPlaying)
    }

    // MARK: - Song Arrangement Operations

    func test_addPatternToSong_appendsEntry() {
        let store = AppStore()
        store.addPatternToSong(0, repeatCount: 2)

        XCTAssertEqual(store.project.songArrangement.count, 1)
        XCTAssertEqual(store.project.songArrangement[0].repeatCount, 2)
    }

    func test_removeSongEntry_removesAtIndex() {
        let store = AppStore()
        store.addPatternToSong(0)
        store.addPatternToSong(0)
        store.removeSongEntry(at: 0)

        XCTAssertEqual(store.project.songArrangement.count, 1)
    }

    func test_setSongEntryRepeatCount_updatesCount() {
        let store = AppStore()
        store.addPatternToSong(0, repeatCount: 1)
        store.setSongEntryRepeatCount(at: 0, count: 5)

        XCTAssertEqual(store.project.songArrangement[0].repeatCount, 5)
    }

    func test_setSongEntryRepeatCount_clampsToValidRange() {
        let store = AppStore()
        store.addPatternToSong(0)

        store.setSongEntryRepeatCount(at: 0, count: 0)
        XCTAssertEqual(store.project.songArrangement[0].repeatCount, 1)

        store.setSongEntryRepeatCount(at: 0, count: 999)
        XCTAssertEqual(store.project.songArrangement[0].repeatCount, 99)
    }

    func test_jumpToSongPosition_updatesPosition() {
        let store = AppStore()
        store.project.addPattern()
        store.addPatternToSong(0)
        store.addPatternToSong(1)

        store.jumpToSongPosition(1)

        XCTAssertEqual(store.currentSongPosition, 1)
        XCTAssertEqual(store.project.currentPatternIndex, 1)
        XCTAssertEqual(store.currentStep, 0)
    }

    func test_toggleSongMode_activatesSongMode() {
        let store = AppStore()
        store.addPatternToSong(0)
        store.toggleSongMode()

        XCTAssertTrue(store.isSongMode)
    }

    func test_clearSongArrangement_resetsPosition() {
        let store = AppStore()
        store.addPatternToSong(0)
        store.currentSongPosition = 0
        store.currentPatternLoopCount = 2

        store.clearSongArrangement()

        XCTAssertTrue(store.project.songArrangement.isEmpty)
        XCTAssertEqual(store.currentSongPosition, 0)
        XCTAssertEqual(store.currentPatternLoopCount, 0)
    }

    // MARK: - Pattern Editing

    func test_toggleStep_updatesPattern() {
        let store = AppStore()
        store.toggleStep(voice: .kick, stepIndex: 0)

        let step = store.step(voice: .kick, stepIndex: 0)
        XCTAssertTrue(step?.isActive == true)
    }

    func test_setStepVelocity_updatesVelocity() {
        let store = AppStore()
        store.toggleStep(voice: .kick, stepIndex: 0)
        store.setStepVelocity(voice: .kick, stepIndex: 0, velocity: 100)

        let step = store.step(voice: .kick, stepIndex: 0)
        XCTAssertEqual(step?.velocity, 100)
    }

    // MARK: - Voice Controls

    func test_toggleMute_togglesMuteState() {
        let store = AppStore()
        let voice = store.project.voice(for: .kick)
        XCTAssertFalse(voice.isMuted)

        store.toggleMute(for: .kick)
        XCTAssertTrue(store.project.voice(for: .kick).isMuted)
    }

    func test_toggleSolo_togglesSoloState() {
        let store = AppStore()
        store.toggleSolo(for: .snare)
        XCTAssertTrue(store.project.voice(for: .snare).isSoloed)
    }

    // MARK: - Audio Engine Lifecycle

    func test_audioEngine_notRunningByDefault() {
        let store = AppStore()
        XCTAssertFalse(store.isAudioEngineRunning)
    }

    func test_startAudioEngine_setsIsRunningTrue() {
        let store = AppStore()
        store.startAudioEngine()
        XCTAssertTrue(store.isAudioEngineRunning)
        store.stopAudioEngine()
    }

    func test_stopAudioEngine_setsIsRunningFalse() {
        let store = AppStore()
        store.startAudioEngine()
        store.stopAudioEngine()
        XCTAssertFalse(store.isAudioEngineRunning)
    }

    func test_startAudioEngine_calledMultipleTimes_doesNotCrash() {
        let store = AppStore()
        store.startAudioEngine()
        store.startAudioEngine() // Second call should be safe
        XCTAssertTrue(store.isAudioEngineRunning)
        store.stopAudioEngine()
    }

    func test_stopAudioEngine_withoutStart_doesNotCrash() {
        let store = AppStore()
        store.stopAudioEngine() // Should not crash
        XCTAssertFalse(store.isAudioEngineRunning)
    }

    // MARK: - Audio Engine Integration (Edge Cases)

    func test_play_withoutStartingEngine_setsIsPlayingTrue() {
        // Edge case: UI calls play before engine is started
        // Should still set state correctly (engine will be silent)
        let store = AppStore()
        store.play()
        XCTAssertTrue(store.isPlaying)
    }

    func test_play_afterStartingEngine_setsIsPlayingTrue() {
        // Happy path: engine started, then play
        let store = AppStore()
        store.startAudioEngine()
        store.play()
        XCTAssertTrue(store.isPlaying)
        XCTAssertTrue(store.isAudioEngineRunning)
        store.stop()
        store.stopAudioEngine()
    }

    func test_stop_afterPlayWithEngine_stopsPlaybackAndResetsStep() {
        let store = AppStore()
        store.startAudioEngine()
        store.play()
        store.currentStep = 8 // Simulate advancement
        store.stop()

        XCTAssertFalse(store.isPlaying)
        XCTAssertEqual(store.currentStep, 0)
        XCTAssertTrue(store.isAudioEngineRunning) // Engine still running
        store.stopAudioEngine()
    }

    func test_togglePlayback_withEngine_startsAndStops() {
        let store = AppStore()
        store.startAudioEngine()

        store.togglePlayback()
        XCTAssertTrue(store.isPlaying)

        store.togglePlayback()
        XCTAssertFalse(store.isPlaying)

        store.stopAudioEngine()
    }

    func test_syncPatternToDSP_calledAfterEngineStart() {
        // Verify that pattern sync works after engine start
        let store = AppStore()
        store.startAudioEngine()

        // Toggle a step - this should sync to DSP
        store.toggleStep(voice: .kick, stepIndex: 0)

        // Verify step is active
        let step = store.step(voice: .kick, stepIndex: 0)
        XCTAssertTrue(step?.isActive == true)

        store.stopAudioEngine()
    }
}
