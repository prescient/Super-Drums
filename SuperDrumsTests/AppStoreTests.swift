import XCTest
@testable import SuperDrums

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
}
