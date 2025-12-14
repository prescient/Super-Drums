# Project Context: iPad Drum Synth (AUv3)
- **Platform:** iPadOS 17.0+
- **Language:** Swift 5.9+
- **Core Frameworks:** SwiftUI (UI), AVFoundation (Audio Engine), AudioToolbox (AUv3).

## Architectural Guidelines
1. **Audio Engine (Critical):**
   - The DSP logic MUST be separated from the UI.
   - Use `AVAudioEngine` and `AVAudioSourceNode` for synthesis where possible, or C++ DSP kernels wrapped in Swift if performance demands it.
   - **Concurrency:** NEVER block the audio render thread. All UI updates driven by audio (e.g., VU meters) must be throttled and dispatched to MainActor.
2. **Data Model:**
   - Use `struct` for data (Pattern, Step, Voice) to ensure thread safety.
   - State Management: Use a central `Store` or `AudioEngineManager` class conforming to `@Observable`.

## Coding Style
- **Input:** Implement `DragGesture` for knobs (vertical drag = value change).
- **Layout:** Use `ViewThatFits` and `GeometryReader` to handle the difference between Standalone (Full Screen) and AUv3 (Resized Window).
- **Files:** Prefix audio files with `DSP` (e.g., `DSPVoice.swift`) and UI files with `UI` (e.g., `UIMixer.swift`).

## Build Instructions
- **Build:** `xcodebuild -scheme SuperDrums -destination 'id=F3C349E9-38A5-488C-9986-779F464DBC00' build`
- **Test:** `xcodebuild test -scheme SuperDrums -destination 'id=F3C349E9-38A5-488C-9986-779F464DBC00'`
- **Lint:** Ensure code compiles without warnings.

---

## Git Workflow

### Branch Strategy
- **`main`** - Stable, working code. Always builds. Tagged for releases.
- **`feature/<name>`** - New features (e.g., `feature/song-mode`, `feature/auv3-plugin`)
- **`fix/<name>`** - Bug fixes (e.g., `fix/step-timing`, `fix/pattern-save`)
- **`refactor/<name>`** - Code improvements without behavior changes

### Commit Convention
Use conventional commits for clear history:
```
<type>(<scope>): <description>

[optional body]
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code restructuring
- `test` - Adding/updating tests
- `docs` - Documentation only
- `style` - Formatting, no code change
- `perf` - Performance improvement

**Scopes:** `sequencer`, `mixer`, `sound`, `transport`, `model`, `dsp`, `ui`

**Examples:**
```
feat(sequencer): add song mode with pattern chaining
fix(transport): correct step advancement at pattern boundary
refactor(model): extract SongArrangementEntry from Project
test(model): add unit tests for Euclidean rhythm generator
```

### Workflow
1. Create feature branch from `main`
2. Make atomic commits (one logical change per commit)
3. Run tests before merging
4. Merge to `main` when feature is complete and tested
5. Tag releases: `v1.0.0`, `v1.1.0`, etc.

---

## Testing Strategy

### Test Pyramid

```
        /  Manual  \        <- Audio output, gestures, real device
       /  UI Tests  \       <- Critical user flows (future)
      / Integration  \      <- AppStore + dependencies
     /   Unit Tests   \     <- Models, algorithms, pure functions
```

### Unit Tests (SuperDrumsTests/)

**What to Test:**
1. **Models** - High value, pure data
   - `Pattern`: step toggling, shift, reverse, clear
   - `Track`: randomization, step count changes
   - `Step`: velocity, probability, parameter locks
   - `SongArrangementEntry`: repeat count bounds
   - `TrackRandomizationSettings`: Euclidean algorithm

2. **AppStore Logic** - State transitions
   - Transport: play/stop state, step advancement
   - Song mode: pattern chaining, loop behavior, position jumping
   - Pattern operations: toggle, velocity, probability

**Test File Naming:** `<ModelName>Tests.swift` (e.g., `PatternTests.swift`, `AppStoreTests.swift`)

**Example Test Structure:**
```swift
final class PatternTests: XCTestCase {
    func test_toggleStep_activatesInactiveStep() {
        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 0)
        XCTAssertTrue(pattern.step(voice: .kick, stepIndex: 0)?.isActive == true)
    }

    func test_shift_movesStepsRight() {
        var pattern = Pattern()
        pattern.toggleStep(voice: .kick, stepIndex: 0)
        pattern.shift(by: 1)
        XCTAssertFalse(pattern.step(voice: .kick, stepIndex: 0)?.isActive == true)
        XCTAssertTrue(pattern.step(voice: .kick, stepIndex: 1)?.isActive == true)
    }

    func test_euclideanPattern_distributes4HitsOver16Steps() {
        let pattern = TrackRandomizationSettings.euclideanPattern(hits: 4, steps: 16)
        XCTAssertEqual(pattern.filter { $0 }.count, 4)
        // Hits should be evenly distributed: indices 0, 4, 8, 12
        XCTAssertTrue(pattern[0])
        XCTAssertTrue(pattern[4])
        XCTAssertTrue(pattern[8])
        XCTAssertTrue(pattern[12])
    }
}
```

### Integration Tests

**AppStore with Mock DSPEngine:**
```swift
final class AppStoreIntegrationTests: XCTestCase {
    func test_songMode_advancesThroughArrangement() {
        let store = AppStore(project: .demo())
        store.addPatternToSong(0, repeatCount: 2)
        store.addPatternToSong(0, repeatCount: 1)
        store.isSongMode = true
        store.play()

        // Simulate 32 steps (2 full patterns)
        for _ in 0..<32 {
            store.advanceStep()
        }

        XCTAssertEqual(store.currentSongPosition, 1)
    }
}
```

### Manual Testing Checklist

Before merging features, verify:

**Sequencer:**
- [ ] Steps toggle on tap
- [ ] Step velocity responds to drag
- [ ] Pattern shifts left/right correctly
- [ ] Randomization respects parameter toggles
- [ ] P-Locks panel opens/closes smoothly
- [ ] Parameter lock bars are draggable

**Song Mode:**
- [ ] PTN/SONG button toggles mode
- [ ] Arrangement panel slides up
- [ ] Patterns can be added from picker
- [ ] Repeat count +/- works
- [ ] Playback chains patterns correctly
- [ ] Loop toggle affects end behavior

**Audio (Requires Device/Simulator with Audio):**
- [ ] All 10 voices produce sound
- [ ] Mute/solo works correctly
- [ ] Timing is tight (no drift)
- [ ] No clicks/pops during playback

### Running Tests
```bash
# Run all tests
xcodebuild test -scheme SuperDrums -destination 'id=F3C349E9-38A5-488C-9986-779F464DBC00'

# Run specific test file
xcodebuild test -scheme SuperDrums -destination 'id=F3C349E9-38A5-488C-9986-779F464DBC00' -only-testing:SuperDrumsTests/PatternTests
```

---

## "Do Not" Rules
- DO NOT use `NavigationView` (Deprecated). Use `NavigationStack` or `NavigationSplitView`.
- DO NOT use generic variable names like `data` or `item`. Be descriptive (e.g., `selectedNote`, `invoiceEntry`).
- DO NOT remove existing comments when editing files unless rewriting the logic entirely.
