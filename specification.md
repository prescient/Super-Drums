# Product Specification: iPad Drum Synthesizer (AUv3)

## 1. App Overview
A professional 10-voice drum synthesizer and sequencer for iPad. The app functions as both a standalone app and an AUv3 Audio Unit plugin. It focuses on deep synthesis (not sampling) and expressive "humanized" sequencing.

## 2. Audio Engine & Synthesis
- **Polyphony:** 10 Simultaneous Voices.
- **Sound Sources:**
  1. **Kick:** Analog-style sine sweep with decay and pitch envelope.
  2. **Snare:** Mixed oscillator (tone) + noise generator (snappy).
  3. **Closed Hat:** Metallic FM noise.
  4. **Open Hat:** Metallic FM noise (Chokes Closed Hat).
  5. **Clap:** Multi-trigger noise burst (sawtooth envelope).
  6. **Cowbell:** Detuned dual-pulse/square wave.
  7. **Cymbal:** High-frequency metallic array.
  8. **Conga:** Resonant sine with pitch modulation.
  9. **Maracas:** High-passed filtered white noise.
  10. **Tom/Perc:** Tunable sine/triangle.
- **Per-Channel Processing:**
  - **Drive/Grit:** Bitcrusher or Overdrive per voice.
  - **Filter:** Low/High pass filter per voice.
  - **Amp Envelope:** Attack, Decay, Sustain, Release (ADSR) or simplified (Decay/Hold).

## 3. Sequencer Core
- **Structure:**
  - 128 Patterns per Project.
  - 16 Steps per Pattern (Default).
  - **Polymetric Mode:** Steps can be adjusted per track (e.g., Kick = 16 steps, Cowbell = 7 steps).
- **Step Features:**
  - **Velocity:** 0-127 per step.
  - **Micro-timing (Nudge):** Shift steps off-grid (-50% to +50%).
  - **Probability:** Chance of step triggering (0-100%).
  - **Sub-steps/Retrigger:** Ratcheting (2x, 3x, 4x repeats within a step).
- **Parameter Locking (Motion):**
  - Ability to record/automate any synth parameter (e.g., Filter Cutoff) per step.
- **Song Mode:**
  - Playlist editor to chain patterns into a full arrangement.

## 4. Modulation & FX
- **LFOs:**
  - 3 Global LFOs routable to any parameter via a Modulation Matrix.
  - Shapes: Sine, Square, Saw, Triangle, Random (Sample & Hold).
- **Master FX:**
  - **Send Effects:** Reverb and Delay (controlled via "Send" amounts on Mixer).
  - **Master Bus:** Compressor/Limiter (The "Glue").
- **Global Settings:**
  - BPM (30-300).
  - Swing/Shuffle (50% - 75%).

## 5. Connectivity & System
- **AUv3 Support:**
  - Full state saving/restoring within host (Logic Pro, GarageBand, AUM).
  - Resizable UI for the plugin window.
- **Sync:**
  - Ableton Link support.
  - MIDI Clock sync (Input).
- **Project Management:**
  - Save/Load Projects (XML or JSON + CoreData).
  - Save/Load Drum Kits (Presets for the 10 voices).
  - "Stem Export": Render individual tracks to audio files.

## 6. UI/UX Requirements
- **Mixer View:** Faders for volume, knobs for Pan, Aux Sends, Mute/Solo buttons.
- **Performance Pads:** XY Pads for live FX manipulation.
- **Randomizer:**
  - "Smart Randomize": Options to randomize just the Pattern, just the Sound Design, or both.
  - Constraints: "Keep Kick/Snare Simple" toggle.
