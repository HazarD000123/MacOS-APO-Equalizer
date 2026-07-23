# APO Equalizer

Microphone processor for macOS. It captures your mic, runs it through a preamp, a 10-band EQ and a rack of effect plugins, then sends the result to BlackHole so other apps can pick it up as their input device.

Inspired by [Equalizer APO](https://sourceforge.net/projects/equalizerapo/) on Windows, but aimed at voice.

## Requirements

[BlackHole](https://github.com/ExistentialAudio/BlackHole) 2ch, a free virtual audio driver:

```
brew install blackhole-2ch
```

You will probably need to reboot before macOS lists it as a device.

Xcode, if you want to build the usual way. There is also a `build.sh` that compiles with `swiftc` directly if you don't have it.

## Usage

Build and run, then:

1. Open the Devices tab and pick your microphone.
2. Press Start. macOS asks for microphone access the first time, and nothing works if you deny it.
3. Set up the preamp, EQ and plugins.
4. In the app you actually want to talk through (Zoom, OBS, Discord, FaceTime), choose "BlackHole 2ch" as the input device.

The Monitor toggle in the sidebar plays the processed signal out your speakers, which is the quickest way to hear what you are doing without joining a call.

## What's in the rack

* Preamp, -24 to +50 dB, with an optional limiter
* 10-band graphic EQ, with presets like Bass Boost, Clear and Warm
* Tone Shaper, a 3-band Baxandall EQ
* Haas Widener
* Stereo Imager
* Punch Compressor
* Maximizer

Plugins can be reordered and bypassed individually. Saved presets cover the preamp, the EQ and the whole plugin rack at once. There is also a menu bar popover if you don't want the main window open.

## Notes

The app never changes your system default input or output. Only apps you explicitly point at BlackHole are affected.

Restart it if you swap microphones or interfaces while it is running.

Bluetooth mics can show up as several Core Audio devices for different profiles, which makes them awkward to select. Built-in or wired mics are more predictable.

Architecture and implementation details are in [TECHNICAL.md](TECHNICAL.md).
