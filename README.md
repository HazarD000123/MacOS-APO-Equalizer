# APO Equalizer

A mic processor for macOS. It takes your microphone, runs it through a gain
stage, a 10-band EQ, and a few effect plugins, then hands the result to any
app as a virtual microphone called "BlackHole 2ch." Basically a mixing
board that sits between your mic and whatever app you talk through —
Discord, Zoom, OBS, whatever.

It's built in the spirit of [Equalizer
APO](https://sourceforge.net/projects/equalizerapo/), the popular Windows
equalizer, but for Mac and aimed specifically at voice.

## What you get

A preamp (-24 to +50 dB) with a limiter so boosting it doesn't just
distort. A 10-band graphic EQ you can shape by ear, or apply a preset —
Bass Boost, Clear, Warm, a few others. And five effect plugins modeled
after tools people already use for voice: a tone shaper, two different
stereo wideners (one Haas-based, one mid/side-based), a compressor, and a
loudness maximizer. Reorder them, bypass any of them, tweak every knob
live. Presets save your whole setup — preamp, EQ, and the plugin rack — in
one go. There's also a menu bar shortcut so you don't need the full window
open all the time.

## Before you start

You need two things:

**[BlackHole](https://github.com/ExistentialAudio/BlackHole)**, a free
virtual audio driver. Install it with `brew install blackhole-2ch`, or grab
the installer from their GitHub page. You'll probably need to restart your
Mac afterward before it shows up as a device.

**Xcode**, if you want to build it the normal way. If you don't have Xcode,
there's a `build.sh` script that compiles everything with `swiftc`
directly — no Xcode needed. Details further down.

## Running it

Open the project and hit Run (or use `./build.sh` if you're skipping
Xcode). Once it's open:

1. Go to the Devices tab and pick your microphone.
2. Hit Start. macOS will ask for microphone permission the first time —
   allow it, or nothing will work.
3. Adjust the preamp, EQ, and plugins however you like.
4. Open whatever app you actually want to talk through, and in its audio
   settings, pick "BlackHole 2ch" as the input device. That app now hears
   your processed voice instead of your raw mic.

There's a Monitor switch in the sidebar if you want to hear the processed
sound yourself through your speakers or headphones — the easiest way to
check everything's working before jumping into an actual call.

## Worth knowing

This app never touches your Mac's system-wide default mic or speakers. It
only affects apps you've specifically pointed at BlackHole — everything
else keeps working normally the whole time.

If you swap microphones or audio interfaces while it's running, stop and
restart the app so it can resync.

Stick to a built-in or wired mic if you can. Bluetooth mics sometimes
register as more than one device in macOS and can be finicky to select
correctly.

For the architecture, the plugin design, and the reasoning behind some of
the messier decisions, see [TECHNICAL.md](TECHNICAL.md).
