import Foundation
import SwiftUI

/// Central state management for the app using the Observation framework.
@Observable
@MainActor
final class AppStore {

    // MARK: - Project State

    /// The current project
    var project: Project

    /// Transport state
    var isPlaying: Bool = false

    /// Current step position (0-based)
    var currentStep: Int = 0

    /// Selected voice for editing
    var selectedVoiceType: DrumVoiceType = .kick

    /// Current tab
    var selectedTab: AppTab = .sequencer

    // MARK: - Audio Engine

    /// The DSP engine for audio playback
    private let dspEngine: DSPEngine

    /// Whether audio engine is running
    var isAudioEngineRunning: Bool { dspEngine.isRunning }

    // MARK: - UI State

    /// Whether the app is in AUv3 mode (plugin) vs standalone
    var isAUv3Mode: Bool = false

    /// Show pattern browser
    var showPatternBrowser: Bool = false

    /// Show kit browser
    var showKitBrowser: Bool = false

    /// Show settings
    var showSettings: Bool = false

    /// Show track options panel
    var showTrackOptions: Bool = false

    /// Show parameter lock editor
    var showParameterLocks: Bool = false

    /// Show song arrangement editor
    var showSongArrangement: Bool = false

    // MARK: - Song Mode State

    /// Whether playback is in song mode (vs pattern mode)
    var isSongMode: Bool = false

    /// Current position in song arrangement (index into songArrangement array)
    var currentSongPosition: Int = 0

    /// Loop count remaining for current pattern in song (-1 = infinite when in pattern mode)
    var currentPatternLoopCount: Int = 0

    /// Whether to loop the entire song
    var loopSong: Bool = true

    // MARK: - Initialization

    init(project: Project = Project(), dspEngine: DSPEngine? = nil) {
        self.project = project
        self.dspEngine = dspEngine ?? DSPEngine()
        setupAudioCallbacks()
    }

    /// Sets up callbacks from DSP engine
    private func setupAudioCallbacks() {
        // Handle step advancement from audio thread
        // Note: This closure is called from DispatchQueue.main.async in DSPEngine
        dspEngine.onStepAdvanced = { [weak self] step in
            guard let self = self else { return }
            // Use MainActor.assumeIsolated since we're called from DispatchQueue.main.async
            MainActor.assumeIsolated {
                self.handleStepAdvanced(step)
            }
        }

        // Handle voice triggers for UI feedback
        dspEngine.onVoiceTriggered = { [weak self] voiceType, velocity in
            // Could update UI indicators here
            _ = self
            _ = voiceType
            _ = velocity
        }
    }

    /// Called when the audio engine advances to a new step
    private func handleStepAdvanced(_ newStep: Int) {
        let previousStep = currentStep
        currentStep = newStep

        // Check for pattern wrap (step 0 after step 15)
        if newStep == 0 && previousStep > 0 {
            if isSongMode {
                advanceSongPosition()
            }
        }
    }

    /// Starts the audio engine (call on app launch)
    func startAudioEngine() {
        do {
            try dspEngine.start()
            syncPatternToDSP()
            // Sync master settings
            dspEngine.setMasterVolume(project.masterVolume)
            // Sync effect parameters
            dspEngine.setReverbMix(project.reverbMix)
            dspEngine.setDelayParameters(
                mix: project.delayMix,
                time: project.delayTime,
                feedback: project.delayFeedback
            )
        } catch {
            // Audio engine failed to start - app will operate without sound
        }
    }

    /// Stops the audio engine
    func stopAudioEngine() {
        dspEngine.stop()
    }

    /// Syncs current pattern and voice data to DSP engine
    func syncPatternToDSP() {
        dspEngine.updatePattern(currentPattern, voices: project.voices)
    }

    // MARK: - Computed Properties

    /// Current pattern (convenience accessor)
    var currentPattern: Pattern {
        get { project.currentPattern }
        set { project.currentPattern = newValue }
    }

    /// Current voice being edited
    var selectedVoice: Voice {
        get { project.voice(for: selectedVoiceType) }
        set {
            project.setVoice(newValue, for: selectedVoiceType)
            // Sync to DSP engine so knob changes affect sound immediately
            syncPatternToDSP()
        }
    }

    /// BPM
    var bpm: Double {
        get { project.bpm }
        set {
            project.bpm = max(30, min(300, newValue))
            dspEngine.setBPM(project.bpm)
        }
    }

    /// Swing
    var swing: Float {
        get { project.swing }
        set {
            project.swing = max(0.5, min(0.75, newValue))
            dspEngine.setSwing(project.swing)
        }
    }

    /// Master volume (synced to DSP engine)
    var masterVolume: Float {
        get { project.masterVolume }
        set {
            project.masterVolume = max(0, min(1, newValue))
            dspEngine.setMasterVolume(project.masterVolume)
        }
    }

    /// Gets current output levels for metering (left, right)
    var outputLevels: (Float, Float) {
        dspEngine.getOutputLevels()
    }

    /// Reverb mix (synced to DSP engine)
    var reverbMix: Float {
        get { project.reverbMix }
        set {
            project.reverbMix = max(0, min(1, newValue))
            dspEngine.setReverbMix(project.reverbMix)
        }
    }

    /// Delay mix (synced to DSP engine)
    var delayMix: Float {
        get { project.delayMix }
        set {
            project.delayMix = max(0, min(1, newValue))
            syncDelayParameters()
        }
    }

    /// Delay time
    var delayTime: Float {
        get { project.delayTime }
        set {
            project.delayTime = max(0, min(1, newValue))
            syncDelayParameters()
        }
    }

    /// Delay feedback
    var delayFeedback: Float {
        get { project.delayFeedback }
        set {
            project.delayFeedback = max(0, min(0.95, newValue))
            syncDelayParameters()
        }
    }

    /// Sync delay parameters to DSP
    private func syncDelayParameters() {
        dspEngine.setDelayParameters(
            mix: project.delayMix,
            time: project.delayTime,
            feedback: project.delayFeedback
        )
    }

    // MARK: - Transport Controls

    /// Starts playback
    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        syncPatternToDSP()
        dspEngine.startPlayback(bpm: bpm, stepCount: currentPattern.defaultStepCount)
    }

    /// Stops playback
    func stop() {
        isPlaying = false
        dspEngine.stopPlayback()
        currentStep = 0
        currentSongPosition = 0
        currentPatternLoopCount = 0
    }

    /// Toggles playback
    func togglePlayback() {
        if isPlaying {
            stop()
        } else {
            play()
        }
    }

    /// Advances to next step (called by audio engine callback - no longer used directly)
    func advanceStep() {
        let stepCount = currentPattern.defaultStepCount
        let nextStep = currentStep + 1

        if nextStep >= stepCount {
            // Pattern finished
            currentStep = 0

            if isSongMode {
                advanceSongPosition()
            }
        } else {
            currentStep = nextStep
        }
    }

    /// Advances to next pattern in song arrangement
    private func advanceSongPosition() {
        guard !project.songArrangement.isEmpty else { return }

        // Check if we need to loop the current pattern
        if let entry = currentSongEntry, entry.repeatCount > 1 {
            currentPatternLoopCount += 1
            if currentPatternLoopCount < entry.repeatCount {
                // Stay on current pattern
                return
            }
        }

        // Move to next pattern
        currentPatternLoopCount = 0
        currentSongPosition += 1

        if currentSongPosition >= project.songArrangement.count {
            if loopSong {
                currentSongPosition = 0
            } else {
                stop()
                return
            }
        }

        // Update current pattern to match song position
        if let entry = currentSongEntry {
            project.currentPatternIndex = entry.patternIndex
            syncPatternToDSP()
        }
    }

    /// Current song entry (if in song mode with valid position)
    var currentSongEntry: SongArrangementEntry? {
        guard currentSongPosition < project.songArrangement.count else { return nil }
        return project.songArrangement[currentSongPosition]
    }

    /// Total song length in patterns
    var songLength: Int {
        project.songArrangement.reduce(0) { $0 + $1.repeatCount }
    }

    // MARK: - Pattern Editing

    /// Toggles a step in the current pattern
    func toggleStep(voice: DrumVoiceType, stepIndex: Int) {
        project.currentPattern.toggleStep(voice: voice, stepIndex: stepIndex)
        syncPatternToDSP()
    }

    /// Sets velocity for a step
    func setStepVelocity(voice: DrumVoiceType, stepIndex: Int, velocity: UInt8) {
        project.currentPattern.setStepVelocity(voice: voice, stepIndex: stepIndex, velocity: velocity)
        syncPatternToDSP()
    }

    /// Gets step at position
    func step(voice: DrumVoiceType, stepIndex: Int) -> Step? {
        currentPattern.step(voice: voice, stepIndex: stepIndex)
    }

    /// Clears current pattern
    func clearCurrentPattern() {
        project.currentPattern.clear()
        syncPatternToDSP()
    }

    /// Shifts current pattern
    func shiftPattern(by offset: Int) {
        project.currentPattern.shift(by: offset)
        syncPatternToDSP()
    }

    // MARK: - Voice Controls

    /// Sets mute state for a voice
    func setMute(_ muted: Bool, for voiceType: DrumVoiceType) {
        var voice = project.voice(for: voiceType)
        voice.isMuted = muted
        project.setVoice(voice, for: voiceType)
        syncPatternToDSP()
    }

    /// Toggles mute for a voice
    func toggleMute(for voiceType: DrumVoiceType) {
        let voice = project.voice(for: voiceType)
        setMute(!voice.isMuted, for: voiceType)
    }

    /// Sets solo state for a voice
    func setSolo(_ soloed: Bool, for voiceType: DrumVoiceType) {
        var voice = project.voice(for: voiceType)
        voice.isSoloed = soloed
        project.setVoice(voice, for: voiceType)
        syncPatternToDSP()
    }

    /// Toggles solo for a voice
    func toggleSolo(for voiceType: DrumVoiceType) {
        let voice = project.voice(for: voiceType)
        setSolo(!voice.isSoloed, for: voiceType)
    }

    /// Sets volume for a voice
    func setVolume(_ volume: Float, for voiceType: DrumVoiceType) {
        var voice = project.voice(for: voiceType)
        voice.volume = max(0, min(1, volume))
        project.setVoice(voice, for: voiceType)
        syncPatternToDSP()
    }

    /// Sets pan for a voice
    func setPan(_ pan: Float, for voiceType: DrumVoiceType) {
        var voice = project.voice(for: voiceType)
        voice.pan = max(-1, min(1, pan))
        project.setVoice(voice, for: voiceType)
        syncPatternToDSP()
    }

    // MARK: - Pattern Management

    /// Selects a pattern by index
    func selectPattern(_ index: Int) {
        guard index < project.patterns.count else { return }
        project.currentPatternIndex = index
        syncPatternToDSP()
    }

    /// Adds a new pattern
    func addPattern() {
        project.addPattern()
    }

    /// Duplicates current pattern
    func duplicateCurrentPattern() {
        project.duplicateCurrentPattern()
    }

    /// Deletes pattern at index
    func deletePattern(at index: Int) {
        project.deletePattern(at: index)
    }

    // MARK: - Randomization

    /// Randomizes the current pattern with constraints
    func randomizePattern(keepKickSnareSimple: Bool = true, density: Float = 0.3) {
        for voiceType in DrumVoiceType.allCases {
            guard var track = project.currentPattern.tracks[voiceType.rawValue] else { continue }

            let effectiveDensity: Float
            switch voiceType {
            case .kick where keepKickSnareSimple:
                effectiveDensity = 0.15
            case .snare where keepKickSnareSimple:
                effectiveDensity = 0.12
            case .closedHat, .openHat:
                effectiveDensity = density * 1.5
            default:
                effectiveDensity = density
            }

            track.randomize(density: effectiveDensity)
            project.currentPattern.tracks[voiceType.rawValue] = track
        }
        syncPatternToDSP()
    }

    /// Randomizes sound design for selected voice
    func randomizeSoundDesign(for voiceType: DrumVoiceType) {
        var voice = project.voice(for: voiceType)

        voice.pitch = Float.random(in: 0.2...0.8)
        voice.decay = Float.random(in: 0.1...0.8)
        voice.filterCutoff = Float.random(in: 0.3...1.0)
        voice.drive = Float.random(in: 0...0.5)

        project.setVoice(voice, for: voiceType)
        syncPatternToDSP()
    }

    // MARK: - Per-Track Operations

    /// Randomizes a single track with specific settings
    func randomizeTrack(_ voiceType: DrumVoiceType, with settings: TrackRandomizationSettings) {
        guard var track = project.currentPattern.tracks[voiceType.rawValue] else { return }

        let stepCount = track.stepCount

        // Randomize step pattern (on/off)
        if settings.randomizeSteps {
            if settings.useEuclidean {
                // Use Euclidean distribution
                let pattern = TrackRandomizationSettings.euclideanPattern(
                    hits: settings.euclideanHits,
                    steps: stepCount
                )
                for i in 0..<stepCount {
                    let isDownbeat = i % 4 == 0
                    if settings.preserveDownbeats && isDownbeat && track.steps[i].isActive {
                        continue
                    }
                    track.steps[i].isActive = pattern[i]
                }
            } else {
                // Random distribution based on density
                for i in 0..<stepCount {
                    let isDownbeat = i % 4 == 0
                    if settings.preserveDownbeats && isDownbeat && track.steps[i].isActive {
                        continue
                    }
                    track.steps[i].isActive = Float.random(in: 0...1) < settings.density
                }
            }
        }

        // Randomize velocity (only for active steps)
        if settings.randomizeVelocity {
            for i in 0..<stepCount where track.steps[i].isActive {
                track.steps[i].velocity = UInt8.random(
                    in: settings.velocityMin...settings.velocityMax
                )
            }
        }

        // Randomize probability (only for active steps)
        if settings.randomizeProbability {
            for i in 0..<stepCount where track.steps[i].isActive {
                track.steps[i].probability = Float.random(
                    in: settings.probabilityMin...settings.probabilityMax
                )
            }
        }

        // Randomize retriggers (only for active steps)
        if settings.randomizeRetriggers {
            for i in 0..<stepCount where track.steps[i].isActive {
                if Float.random(in: 0...1) < settings.retriggerChance {
                    track.steps[i].retriggerCount = Int.random(in: 2...settings.retriggerMax)
                } else {
                    track.steps[i].retriggerCount = 1
                }
            }
        }

        project.currentPattern.tracks[voiceType.rawValue] = track
        syncPatternToDSP()
    }

    /// Clears a single track
    func clearTrack(_ voiceType: DrumVoiceType) {
        guard var track = project.currentPattern.tracks[voiceType.rawValue] else { return }
        track.clear()
        project.currentPattern.tracks[voiceType.rawValue] = track
        syncPatternToDSP()
    }

    /// Fills all steps in a track
    func fillTrack(_ voiceType: DrumVoiceType) {
        guard var track = project.currentPattern.tracks[voiceType.rawValue] else { return }
        for i in 0..<track.stepCount {
            track.steps[i].isActive = true
            track.steps[i].velocity = 100
        }
        project.currentPattern.tracks[voiceType.rawValue] = track
        syncPatternToDSP()
    }

    /// Shifts a single track
    func shiftTrack(_ voiceType: DrumVoiceType, by offset: Int) {
        guard var track = project.currentPattern.tracks[voiceType.rawValue] else { return }
        track.shift(by: offset)
        project.currentPattern.tracks[voiceType.rawValue] = track
        syncPatternToDSP()
    }

    /// Reverses a single track
    func reverseTrack(_ voiceType: DrumVoiceType) {
        guard var track = project.currentPattern.tracks[voiceType.rawValue] else { return }
        track.steps.reverse()
        project.currentPattern.tracks[voiceType.rawValue] = track
        syncPatternToDSP()
    }

    /// Sets step count for a track (polymetric mode)
    func setTrackStepCount(_ voiceType: DrumVoiceType, count: Int) {
        guard var track = project.currentPattern.tracks[voiceType.rawValue] else { return }
        track.setStepCount(count)
        project.currentPattern.tracks[voiceType.rawValue] = track
        syncPatternToDSP()
    }

    // MARK: - Parameter Locks

    /// Sets a parameter lock for a specific step
    func setParameterLock(for voiceType: DrumVoiceType, stepIndex: Int, parameter: LockableParameter, value: Float) {
        guard var track = project.currentPattern.tracks[voiceType.rawValue],
              stepIndex < track.steps.count else { return }

        // Handle step parameters vs synth parameter locks
        switch parameter {
        case .velocity:
            track.steps[stepIndex].normalizedVelocity = value
        case .probability:
            track.steps[stepIndex].probability = max(0, min(1, value))
        case .retrigger:
            // Map 0-1 to 1-4 retriggers
            let retriggers = Int(value * 3) + 1
            track.steps[stepIndex].retriggerCount = max(1, min(4, retriggers))
        default:
            track.steps[stepIndex].parameterLocks[parameter.rawValue] = value
        }

        project.currentPattern.tracks[voiceType.rawValue] = track
        syncPatternToDSP()
    }

    /// Clears a parameter lock for a specific step
    func clearParameterLock(for voiceType: DrumVoiceType, stepIndex: Int, parameter: LockableParameter) {
        guard var track = project.currentPattern.tracks[voiceType.rawValue],
              stepIndex < track.steps.count else { return }

        // Handle step parameters vs synth parameter locks
        switch parameter {
        case .velocity:
            track.steps[stepIndex].velocity = 100 // Reset to default
        case .probability:
            track.steps[stepIndex].probability = 1.0 // Reset to 100%
        case .retrigger:
            track.steps[stepIndex].retriggerCount = 1 // Reset to single trigger
        default:
            track.steps[stepIndex].parameterLocks.removeValue(forKey: parameter.rawValue)
        }

        project.currentPattern.tracks[voiceType.rawValue] = track
        syncPatternToDSP()
    }

    /// Clears all locks for a specific parameter across the track
    func clearParameterLocks(for voiceType: DrumVoiceType, parameter: LockableParameter) {
        guard var track = project.currentPattern.tracks[voiceType.rawValue] else { return }

        for i in 0..<track.steps.count {
            switch parameter {
            case .velocity:
                track.steps[i].velocity = 100
            case .probability:
                track.steps[i].probability = 1.0
            case .retrigger:
                track.steps[i].retriggerCount = 1
            default:
                track.steps[i].parameterLocks.removeValue(forKey: parameter.rawValue)
            }
        }

        project.currentPattern.tracks[voiceType.rawValue] = track
        syncPatternToDSP()
    }

    /// Clears all parameter locks for a track
    func clearAllParameterLocks(for voiceType: DrumVoiceType) {
        guard var track = project.currentPattern.tracks[voiceType.rawValue] else { return }
        for i in 0..<track.steps.count {
            track.steps[i].parameterLocks.removeAll()
        }
        project.currentPattern.tracks[voiceType.rawValue] = track
        syncPatternToDSP()
    }

    /// Sets probability for a specific step
    func setStepProbability(voice: DrumVoiceType, stepIndex: Int, probability: Float) {
        guard var track = project.currentPattern.tracks[voice.rawValue],
              stepIndex < track.steps.count else { return }
        track.steps[stepIndex].probability = max(0, min(1, probability))
        project.currentPattern.tracks[voice.rawValue] = track
        syncPatternToDSP()
    }

    /// Sets retrigger count for a specific step
    func setStepRetrigger(voice: DrumVoiceType, stepIndex: Int, count: Int) {
        guard var track = project.currentPattern.tracks[voice.rawValue],
              stepIndex < track.steps.count else { return }
        track.steps[stepIndex].retriggerCount = max(1, min(8, count))
        project.currentPattern.tracks[voice.rawValue] = track
        syncPatternToDSP()
    }

    // MARK: - Song Arrangement

    /// Adds current pattern to song arrangement
    func addCurrentPatternToSong() {
        let entry = SongArrangementEntry(patternIndex: project.currentPatternIndex)
        project.songArrangement.append(entry)
    }

    /// Adds a specific pattern to song arrangement
    func addPatternToSong(_ patternIndex: Int, repeatCount: Int = 1) {
        guard patternIndex < project.patterns.count else { return }
        let entry = SongArrangementEntry(patternIndex: patternIndex, repeatCount: repeatCount)
        project.songArrangement.append(entry)
    }

    /// Removes entry from song arrangement
    func removeSongEntry(at index: Int) {
        guard index < project.songArrangement.count else { return }
        project.songArrangement.remove(at: index)
    }

    /// Moves song entry from one position to another
    func moveSongEntry(from source: Int, to destination: Int) {
        guard source < project.songArrangement.count,
              destination <= project.songArrangement.count else { return }
        let entry = project.songArrangement.remove(at: source)
        let adjustedDestination = destination > source ? destination - 1 : destination
        project.songArrangement.insert(entry, at: adjustedDestination)
    }

    /// Updates repeat count for a song entry
    func setSongEntryRepeatCount(at index: Int, count: Int) {
        guard index < project.songArrangement.count else { return }
        project.songArrangement[index].repeatCount = max(1, min(99, count))
    }

    /// Clears entire song arrangement
    func clearSongArrangement() {
        project.songArrangement.removeAll()
        currentSongPosition = 0
        currentPatternLoopCount = 0
    }

    /// Jumps to a specific position in the song
    func jumpToSongPosition(_ position: Int) {
        guard position < project.songArrangement.count else { return }
        currentSongPosition = position
        currentPatternLoopCount = 0
        currentStep = 0
        if let entry = currentSongEntry {
            project.currentPatternIndex = entry.patternIndex
            syncPatternToDSP()
        }
    }

    /// Toggles between song and pattern mode
    func toggleSongMode() {
        isSongMode.toggle()
        if isSongMode && !project.songArrangement.isEmpty {
            // Start from beginning of song
            currentSongPosition = 0
            currentPatternLoopCount = 0
            if let entry = currentSongEntry {
                project.currentPatternIndex = entry.patternIndex
                syncPatternToDSP()
            }
        }
    }
}

// MARK: - App Tab

/// Main navigation tabs
enum AppTab: String, CaseIterable, Identifiable {
    case sequencer
    case mixer
    case sound
    case perform

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sequencer: return "Sequencer"
        case .mixer: return "Mixer"
        case .sound: return "Sound"
        case .perform: return "Perform"
        }
    }

    var icon: String {
        switch self {
        case .sequencer: return "square.grid.3x3"
        case .mixer: return "slider.vertical.3"
        case .sound: return "waveform"
        case .perform: return "hand.tap"
        }
    }
}
