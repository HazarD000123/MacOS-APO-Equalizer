# Technical notes

Architecture and implementation details. See [README.md](README.md) if you just want to use the app.

## Audio path

A single `AVAudioEngine` cannot read from one device and write to another. On macOS its input and output nodes share the same Core Audio I/O unit, so pointing input at the microphone and output at BlackHole on one engine doesn't work.

The way around it, and what Loopback and VoiceMeeter do, is two engines bridged by hand:

1. A capture engine whose input is the real microphone. A tap on the input node writes samples into a ring buffer.
2. A playback engine where an `AVAudioSourceNode` reads that ring buffer and feeds Preamp -> EQ -> plugin rack, with output pointed at BlackHole.

Start wires up both engines, Stop tears both down. `AudioDeviceManager` assigns devices per engine with `kAudioOutputUnitProperty_CurrentDevice` and never writes the system default, which would affect every other app and behaves badly with Bluetooth.

`AudioRingBuffer` is a lock-free single-producer/single-consumer circular buffer. The capture tap writes, the source node reads, and if the reader falls behind it drops the oldest samples rather than letting latency grow unbounded.

## Plugins

Each rack effect is an `AUAudioUnit` subclass with its own `AUParameterTree`, registered in-process with `AUAudioUnit.registerSubclass(_:as:name:version:)` and inserted into the `AVAudioEngine` graph the same way a third-party plugin would be. All the DSP is written from scratch.

**Tone Shaper.** 3-band Baxandall EQ: low shelf, mid bell, high shelf. Broad and musical rather than surgical.

**Haas Widener.** Delays one channel against the other to exploit the precedence effect. A single bipolar knob controls it, negative pans left and positive pans right, with Mono, Stereo, Dual L and Dual R routing to pick the source before panning.

**Stereo Imager.** Mid/side width control plus an all-pass decorrelation network that generates new stereo content above 100% width. The decorrelation is the important part here: the input is a mono microphone, and a plain mid/side widener has nothing to scale when left and right start out identical. Mono compatibility holds by construction, since `L = mid + side` and `R = mid - side` means `L + R` always collapses to `2 * mid`. A bass-mono filter keeps low frequencies centred so they don't phase out.

**Punch Compressor.** Threshold, ratio and a saturation stage are all derived from one Process knob, with separate Input and Output trims.

**Maximizer.** Upward expansion lifts the quiet parts with a power curve, drive pushes the level, and the signal hard clips at 0 dBFS instead of being soft limited. Peaks can't exceed full scale, so the extra loudness comes from filling the space under the ceiling rather than from a taller peak. An output trim brings it back down without losing that density.

Hosting real third-party AU or VST plugins would need a proper scanning and hosting layer, and isn't implemented.

## Building

With Xcode: open `APOEqualizer.xcodeproj`, pick the APOEqualizer scheme and run. The project file is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen), so re-run `xcodegen generate` after adding or removing source files instead of editing the `.xcodeproj`, which gets overwritten.

Without Xcode: run `./build.sh`. It compiles with `swiftc` and ad-hoc signs the result, which is enough to run locally. Giving the built app to someone else needs a Developer ID signature and notarization.

The app is unsandboxed. In-process Audio Unit hosting and direct Core Audio device access are both awkward under the sandbox, so this is built for distribution outside the App Store, same as BlackHole and Loopback.

macOS prompts for microphone access the first time you press Start. If access is denied, capture quietly delivers silence instead of returning an error, so check that first when there is no audio and no obvious reason why.

## Layout

```
APOEqualizer/
  App/                  Entry point and AppDelegate, which owns the engine
  Audio/
    AudioDeviceManager  Core Audio device enumeration and selection
    AudioRingBuffer     Lock-free SPSC buffer bridging the two engines
    AudioEngineManager  Both engines, graph wiring, plugin lifecycle, presets
  Plugins/
    BaseEffectAudioUnit Shared AUAudioUnit boilerplate
    DSPUtilities        Biquads, delay lines, envelope followers
    PreampAU, ToneShaperAU, HaasWidenerAU, StereoImagerAU,
    PunchCompressorAU, MaximizerAU
    PluginRegistry      Registration and instantiation
  Models/               EQBand, PluginSlot, Preset, all Codable
  Views/                SwiftUI: navigation, EQ, plugin rack, devices, presets
```

## Limitations

Stereo only. Multichannel input gets downmixed by `AVAudioEngine` with no special handling.

Changing the sample rate while running desyncs the ring buffer. BlackHole is pinned to the microphone's rate at Start, so restart after switching hardware.

Bluetooth inputs sometimes register as several Core Audio device objects for different profiles, which makes selection unreliable.

There is one post-processing peak meter and nothing more detailed.
