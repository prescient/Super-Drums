# Super Drums User Manual

**Version 1.0 | iPad Drum Synthesizer & Sequencer**

Super Drums is a professional drum synthesizer and step sequencer designed for iPadOS. Create intricate drum patterns with 10 synthesized voices, shape sounds with deep synthesis controls, and perform live with touch-responsive pads.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Navigation](#navigation)
3. [Sequencer](#sequencer)
4. [Mixer](#mixer)
5. [Sound Design](#sound-design)
6. [Perform Mode](#perform-mode)
7. [Settings & Persistence](#settings--persistence)
8. [Quick Reference](#quick-reference)

---

## Getting Started

### First Launch

When you first open Super Drums, you'll see the **Sequencer** screen with a demo pattern loaded. The app is ready to make sound immediately.

### Transport Controls

The transport bar appears at the top of every screen:

| Control | Description |
|---------|-------------|
| **Play/Stop** | Large circular button - tap to start/stop playback |
| **BPM** | Tempo display with +/- stepper (30-300 BPM) |
| **Step Indicator** | Row of dots showing current playback position |
| **Pattern Selector** | Shows current pattern number (e.g., "01/04") |
| **Bank Button** | Opens pattern bank for quick pattern switching |
| **Add Pattern** | Green + button to create a new pattern |

### The 10 Drum Voices

Super Drums includes 10 synthesized drum voices:

| Voice | Abbreviation | Color | Description |
|-------|--------------|-------|-------------|
| Kick | KK | Green | Deep bass drum with pitch sweep |
| Snare | SN | Magenta | Punchy snare with noise/tone mix |
| Closed Hat | CH | Cyan | Tight, crisp hi-hat |
| Open Hat | OH | Blue | Sustained, shimmering hi-hat |
| Clap | CL | Pink | Layered clap with band-pass filter |
| Cowbell | CB | Yellow | Metallic dual-tone percussion |
| Cymbal | CY | Orange | Long crash/ride cymbal |
| Conga | CG | Coral | Warm tonal percussion |
| Maracas | MR | Teal | Short bright shaker |
| Tom | TM | Purple | Deep tom with pitch envelope |

---

## Navigation

The bottom tab bar provides access to five main sections:

| Tab | Icon | Function |
|-----|------|----------|
| **Sequencer** | Grid | Pattern editing and step programming |
| **Mixer** | Sliders | Volume, pan, effects sends, master output |
| **Sound** | Waveform | Synthesis parameters for each voice |
| **Perform** | Hand | Live performance pads and XY controllers |
| **Settings** | Gear | Save/load projects and drum kits |

---

## Sequencer

The Sequencer is where you create and edit drum patterns using a step-based grid interface.

### The Step Grid

The main area displays a grid with:
- **Rows**: One row per drum voice (10 total)
- **Columns**: 16 steps (1 bar at 4/4 time)
- **Voice Labels**: Abbreviated names on the left side

#### Step Interactions

| Action | Result |
|--------|--------|
| **Tap step** | Toggle step on/off |
| **Long-press step** | Open context menu |

#### Step Visual Indicators

Each step cell can display multiple states:

- **Filled color** = Step is active (height indicates velocity)
- **Magenta dot (top-left)** = Probability is set below 100%
- **Yellow dot (top-right)** = Parameter lock is applied
- **Green text (bottom-right)** = Retrigger count (2x, 3x, 4x)
- **Bright border** = Current playing step

#### Step Context Menu

Long-press any step to access:

| Option | Description |
|--------|-------------|
| **Edit Velocity** | Adjust velocity (0-127) |
| **Probability** | Set to 100%, 75%, 50%, or 25% |
| **Retrigger** | Off, 2x, 3x, or 4x ratchets per step |
| **Clear Step** | Remove the step entirely |

### Pattern Mode vs Song Mode

Super Drums supports two playback modes:

#### Pattern Mode (PTN)
- Loops a single pattern continuously
- Default mode for creating and editing

#### Song Mode (SONG)
- Chains multiple patterns in sequence
- Create full arrangements with repeats

Toggle between modes using the **PTN/SONG** button in the toolbar.

### Song Arrangement

When Song Mode is active, the arrangement panel slides up from the bottom:

1. **Add patterns** using the numbered buttons in the picker
2. **Set repeat count** with +/- buttons on each entry (1-99x)
3. **Reorder** by dragging entries
4. **Remove** by long-pressing and selecting "Remove"
5. **Jump to position** by tapping any entry during playback

Enable **Loop** to repeat the entire song, or disable to stop at the end.

### Parameter Locks (P-Locks)

Parameter locks let you set per-step values for synthesis parameters, creating dynamic patterns that change sound on every step.

#### Opening the P-Lock Editor

1. Tap the **P-Locks** button in the toolbar
2. The editor panel slides up from the bottom

#### Available Parameters

| Category | Parameters |
|----------|------------|
| **Step** | VEL (Velocity), PRB (Probability), RTG (Retrigger) |
| **Synth** | PIT (Pitch), DCY (Decay), FLT (Cutoff), RES (Resonance) |
| **Effects** | DRV (Drive), PAN, REV (Reverb Send), DLY (Delay Send) |

#### Using P-Locks

1. Select a voice by tapping its row
2. Choose a parameter from the buttons
3. **Drag up/down** on any step bar to set its value
4. **Double-tap** a bar to clear that lock

### Track Options Panel

Tap the **Track Options** button to access per-voice settings:

#### Randomization Settings

| Setting | Description |
|---------|-------------|
| **Steps** | Include step on/off in randomization |
| **Velocity** | Randomize velocity values |
| **Probability** | Add probability variations |
| **Retriggers** | Random ratcheting effects |
| **Density** | Overall note density (0-100%) |
| **Euclidean Mode** | Use mathematical even-spacing algorithm |
| **Preserve Downbeats** | Keep beat 1 active |

#### Presets

- **Sparse**: 15% density, high velocity
- **Medium**: 35% density, balanced
- **Dense**: 60% density, varied dynamics

#### Track Actions

| Button | Action |
|--------|--------|
| **Clear Track** | Remove all steps from this voice |
| **Fill All** | Activate all 16 steps |
| **Shift Left/Right** | Rotate pattern by one step |
| **Reverse** | Flip pattern backwards |
| **Step Count** | Set steps (1-16) for polymetric rhythms |

### Pattern Bank

Tap the **BANK** button in the transport bar to view all patterns:

- **Thumbnail grid** shows mini previews of each pattern
- Tap a pattern to switch to it
- Use **Add Pattern** (+) to create new patterns

### Sequencer Toolbar

| Button | Function |
|--------|----------|
| **Clear** | Clear all steps in current pattern |
| **Shift L/R** | Rotate entire pattern left or right |
| **Duplicate** | Copy pattern to a new slot |
| **PTN/SONG** | Toggle playback mode |
| **P-Locks** | Open parameter lock editor |
| **Track Options** | Open per-track settings |
| **Randomize** | Open randomization menu |

---

## Mixer

The Mixer provides complete control over levels, panning, and effects sends for all voices plus the master output.

### Channel Strips

Each of the 10 voices has a channel strip containing:

| Control | Range | Description |
|---------|-------|-------------|
| **Voice Label** | - | Tap to select voice |
| **PAN** | -100 to +100 | Left/right positioning (C = center) |
| **REV** | 0-100 | Reverb send amount |
| **DLY** | 0-100 | Delay send amount |
| **Fader** | -∞ to +6 dB | Volume level |
| **M (Mute)** | On/Off | Silence this voice (red when active) |
| **S (Solo)** | On/Off | Solo this voice (yellow when active) |

#### Fader Behavior

- **Drag up/down** to adjust volume
- **Double-tap** to reset to default (0 dB)
- Value displayed in dB below the fader

### Master Channel

The rightmost channel controls the overall output:

- **Master fader**: Final output volume
- **VU Meter**: Stereo level display (green/yellow/red)
- Real-time metering at 30fps

### Master Effects Bar

Located at the bottom of the mixer:

#### Reverb Section

| Control | Range | Default |
|---------|-------|---------|
| **Mix** | 0-100% | 30% |

#### Delay Section

| Control | Range | Default |
|---------|-------|---------|
| **Mix** | 0-100% | 20% |
| **Time** | 0-100% | 50% |
| **Feedback** | 0-95% | 40% |

#### Compressor Section

| Control | Range | Default |
|---------|-------|---------|
| **Threshold** | -40 to 0 dB | -10 dB |
| **Ratio** | 1:1 to 20:1 | 4:1 |

### Mixer Header Actions

| Button | Action |
|--------|--------|
| **Reset All** | Reset all channels to defaults |
| **Clear Solos** | Disable all solo states |
| **Clear Mutes** | Disable all mute states |

---

## Sound Design

The Sound tab provides deep synthesis control over each drum voice.

### Voice Selector (Left Panel)

- Lists all 10 voices with color indicators
- Current voice is highlighted
- Mute/Solo states shown with icons
- **Randomize Sound**: Generate random parameters
- **Reset to Default**: Restore factory settings

### Voice Editor (Right Panel)

#### Header
- Voice name with color accent
- **Trigger button**: Preview the sound

#### Oscillator Section

| Parameter | Range | Description |
|-----------|-------|-------------|
| **Pitch** | 0-100% | Base frequency |
| **Pitch Env Amount** | -100 to +100 | Pitch modulation depth |
| **Pitch Env Decay** | 0-500ms | Pitch envelope time |
| **Tone/Noise** | 0-100% | Tonal vs noise content |

#### Filter Section

| Parameter | Options/Range | Description |
|-----------|---------------|-------------|
| **Type** | LP / HP / BP | Low-pass, high-pass, or band-pass |
| **Cutoff** | 0-100% | Filter frequency |
| **Resonance** | 0-100% | Filter emphasis |
| **Env Amount** | -100 to +100 | Filter modulation depth |

#### Envelope Section (ADSR)

| Parameter | Range | Description |
|-----------|-------|-------------|
| **Attack** | 0-1000ms | Fade-in time |
| **Hold** | 0-500ms | Sustain at peak |
| **Decay** | 0-2000ms | Fade to sustain level |
| **Sustain** | 0-100% | Held level |
| **Release** | 0-1000ms | Fade-out after note off |

An animated envelope visualization shows the current ADSR curve.

#### Effects Section

| Parameter | Range | Description |
|-----------|-------|-------------|
| **Drive** | 0-100% | Saturation/distortion |
| **Bitcrusher** | 0-100% | Lo-fi bit reduction |

#### Output Section

| Parameter | Range | Description |
|-----------|-------|-------------|
| **Volume** | 0-100% | Voice output level |
| **Pan** | L100 to R100 | Stereo position |
| **Reverb Send** | 0-100% | Send to reverb |
| **Delay Send** | 0-100% | Send to delay |

---

## Perform Mode

The Perform tab provides touch-responsive controls for live performance.

### Trigger Pads

A grid of 10 pads, one per drum voice:

- **Tap** to trigger the voice
- **Touch position** determines velocity (top = loud, bottom = soft)
- Pads display voice colors
- Visual feedback on hit

### XY Control Surfaces

Two XY pads for real-time sound shaping:

#### Filter XY Pad
| Axis | Parameter |
|------|-----------|
| **X (horizontal)** | Filter Cutoff (left = closed, right = open) |
| **Y (vertical)** | Filter Resonance (bottom = none, top = high) |

#### Pitch/Decay XY Pad
| Axis | Parameter |
|------|-----------|
| **X (horizontal)** | Pitch (left = low, right = high) |
| **Y (vertical)** | Decay (bottom = short, top = long) |

### Using XY Controls

1. **Tap a pad** to select which voice to control
2. **Drag on XY surfaces** to modify that voice in real-time
3. Changes affect the currently selected voice

---

## Settings & Persistence

The Settings tab manages project and kit saving/loading.

### Project Management

#### Current Project

Displays the project name and pattern count.

#### Project Actions

| Button | Action |
|--------|--------|
| **New** | Create a blank project (with confirmation) |
| **Save** | Save current project |
| **Save As** | Save with a new name |

#### Saved Projects List

Shows all saved projects with:
- Project name
- Pattern count
- Last modified date
- **Load** button to open project
- **Delete** button (with confirmation)

### Drum Kit Management

Drum kits save only the sound design settings, independent of patterns. This lets you reuse sounds across different projects.

#### What's Saved in a Kit

- All 10 voice synthesis parameters
- Master volume
- Effects settings (reverb, delay)

#### Kit Actions

| Button | Action |
|--------|--------|
| **Save Current Kit** | Save current sounds with a name |
| **Load** | Apply kit settings to current project |
| **Delete** | Remove saved kit |

---

## Quick Reference

### Gestures Summary

| Gesture | Location | Action |
|---------|----------|--------|
| Tap | Step cell | Toggle on/off |
| Long-press | Step cell | Context menu |
| Drag vertical | Slider/Fader | Adjust value |
| Double-tap | Slider | Reset to default |
| Drag vertical | P-Lock bar | Set parameter value |
| Double-tap | P-Lock bar | Clear lock |
| Tap | Perform pad | Trigger voice |
| Drag | XY pad | Control two parameters |
| Tap | Song entry | Jump to position |

### Parameter Ranges

| Parameter | Min | Max | Default |
|-----------|-----|-----|---------|
| BPM | 30 | 300 | 120 |
| Velocity | 0 | 127 | 100 |
| Probability | 0% | 100% | 100% |
| Retrigger | 1x | 4x | 1x (off) |
| Volume | -∞ dB | +6 dB | 0 dB |
| Pan | L100 | R100 | Center |
| Sends | 0% | 100% | 0% |

### Voice Abbreviations

| Abbrev | Voice |
|--------|-------|
| KK | Kick |
| SN | Snare |
| CH | Closed Hat |
| OH | Open Hat |
| CL | Clap |
| CB | Cowbell |
| CY | Cymbal |
| CG | Conga |
| MR | Maracas |
| TM | Tom |

### Tips & Tricks

1. **Euclidean rhythms**: Enable Euclidean Mode in Track Options for mathematically even-spaced patterns
2. **Polymetric patterns**: Set different step counts per track (e.g., 16 for kick, 12 for hi-hat)
3. **Dynamic patterns**: Use probability and velocity P-locks for humanized, evolving beats
4. **Ratcheting effects**: Add 2x-4x retriggers for fills and rolls
5. **Quick preview**: Use the trigger button in Sound Design to hear changes immediately
6. **Save often**: Use Save As to create variations of your project
7. **Kit presets**: Save drum kits separately to quickly switch sounds without losing patterns

---

## Troubleshooting

### No Sound

1. Check that the Master fader is up
2. Verify individual voice is not muted
3. Check that steps are active in the pattern
4. Ensure the app has audio permission

### Pattern Not Playing

1. Verify playback is started (Play button should be green)
2. In Song Mode, ensure the arrangement has entries
3. Check that BPM is reasonable (not too slow/fast)

### Can't Save Project

1. Ensure you have storage space available
2. Try saving with a different name
3. Check for error messages in Settings

---

**Super Drums** | Built with SwiftUI and AVAudioEngine

*For support and feedback, visit the project repository.*
