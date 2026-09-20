# Dark fantasy audio R1

Active audio registry: `events.json` (71 events, 189 variations). Dynamic score: `music.json` (three original 32-bar suites, four phase-locked stems per suite).

## Credits / permissions

- Foley recordings: **Kenney**, RPG Audio and Impact Sounds, CC0 1.0. https://kenney.nl/assets/rpg-audio and https://kenney.nl/assets/impact-sounds . Original licenses are in `licenses/`.
- Orchestral recordings: **Versilian Studios / Sam Gossner and VSCO 2 CE contributors**. https://github.com/sgossner/VSCO-2-CE and https://vis.versilstudios.com/vsco-community.html . CC0 1.0, pinned tree `440300901dfe9275fd84e0b7763af1f8443ae62e`. Original LICENSE and readme are preserved in the delivery sources; license also ships here.
- Composition, orchestration, cue recipes and integration: newly authored for Fantasy Parkour. No Ghostrunner or Vermintide audio, melodies, stems or archive extracts are included.
- Changes: source trimming, resampling, dynamic envelopes, panning, layered Foley, short room reflections, original note sequencing and orchestration, circular music tails, Ogg/WAV encoding. Sample roots were checked; harp uses a different octave convention and is corrected in the renderer.

The three score titles are **Ash beneath the Ramparts** (112 BPM, 68.57s), **The Iron Procession** (120 BPM, 64s), **Vigil of the Hollow Seal** (96 BPM, 80s). Recorded cellos, violins, horns, harp, flute, bass drum, timpani, snare and gong replace the previous oscillator-led score. Reuse of the same licensed percussion sample across themes is intentional; melodies, pacing and arrangement vary.

`sfx-recipes.json` records every source layer, gain, resampling, onset and room tail. `music/score-*.json` preserves every note's layer, beat, instrument, MIDI pitch, duration, gain and pan. Re-render tools and unmodified source recordings live in `tools/workstreams/audio/` and `deliverables/audio/sources/`. That source directory must travel with the worktree for reproducibility; only this game asset directory is required at runtime.

Historical `assets/audio/sfx/` and `assets/audio/music/` remain for comparison/reference; TrialAudio now loads this registry. Earlier global credits describe the old score, not this replacement. Integration should append these credits to the release's master credits file.

## Mix / timing

- Instant sound events with reserved danger/parry voices; 24 local and 16 spatial voices, per-event limits, no adjacent identical variant, per-emitter cooldown.
- Music: two crossfading synchronized banks, four looping streams in each. Gain changes occur on beats and smooth over time; region changes crossfade 1.8s. Music pitch never follows world time.
- Master ceiling −1 dBFS. Music trim −7 dB, SFX −3 dB before the user's sliders; normal user defaults .4 and .65. Impact duck target .58 for .22s; danger duck .36 for .55s; rapid attacks extend the envelope. All envelopes use real time.
- World focus filter 20 kHz → 2.4 kHz; world pitch bounded at .45 to preserve material identity. Local blade/parry, danger routing and UI bypass the world low-pass. Danger cue pitch does follow explicit focus state, independently of its filter bypass.
- Phase pause suspends music transport and clears SFX/sustains/focus. Resume needs fresh active gameplay events. Death/retry reset battle state; death and retry cues are emitted once by the phase API. The audio layer never changes world time itself.
- Categories already support `set_category_volume`. UI persistence of those extra categories is an integration request, while existing sound/music sliders remain compatible.

## Validation limits

Automated signal and runtime checks do not establish pleasant sound, production-reference fidelity, headphone localization or real final-animation contact timing. The isolated review scene and captured mix demonstrate actual events and transport. Listen via `deliverables/audio/index.html`, then verify final gameplay event bindings. Do not mark Q46 artistically complete solely on these files/tests.
