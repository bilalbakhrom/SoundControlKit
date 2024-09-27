# SoundControlKit

SoundControlKit is a Swift package for managing audio recording and playback with real-time capabilities. It simplifies audio session management, provides robust audio recorder functionality, and integrates seamless playback features.

## Features

- **Real-Time Audio Recording**: Capture audio with real-time visual feedback.
- **Audio Playback**: Play audio files with controls for managing playback state.
- **Audio Session Management**: Handle audio sessions easily with configurable options.
- **Custom Output Formats**: Allow clients to specify output formats and file names.

## Installation

Add `SoundControlKit` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bilalbakhrom/SoundControlKit.git", from: "3.0.0")
]
```

## Usage

To use **SoundControlKit** in your project, follow these steps:

### SCKAudioRecorderManager

```swift
import SoundControlKit

// Create an instance of `SCKAudioRecorderManager`.
let recorderManager = SCKAudioRecorderManager()
recorderManager.delegate = self

// Start recording audio.
recorderManager.record()
// Pause the recording.
recorderManager.pause()
// Stop the recording.
recorderManager.stop()
```

### SCKRealTimeAudioRecorder

```swift
// Create an instance of `SCKRealTimeAudioRecorder`.
let realTimeRecorder = SCKRealTimeAudioRecorder(fileName: .dateWithTime, outputFormat: .aac)
realTimeRecorder.delegate = self

// Start real-time recording.
realTimeRecorder.record()
// Stop real-time recording.
realTimeRecorder.stop()
```

### SCKAudioPlayer

```swift
// Create an instance of `SCKAudioPlayer`.
let audioPlayer = SCKAudioPlayer(audioURL: recordingURL)

// Play the recorded audio.
audioPlayer.play()
// Pause the playback.
audioPlayer.pause()
// Stop the playback.
audioPlayer.stop()
// Forwards the audio playback by a specified number of seconds.
audioPlayer.forward(by: 5)
// Rewinds the audio playback by a specified number of seconds.
audioPlayer.rewind(by: 5)
```

### Delegate Implementation

Ensure to conform to the appropriate delegate protocols to handle audio events effectively.

### Control Notifications

```swift
// Stop all ongoing audio playbacks.
NotificationCenter.default.post(sckNotification: .soundControlKitRequiredToStopAudioPlayback)

// Stop a specific audio playback with the specified `URL`.
NotificationCenter.default.post(sckNotification: .soundControlKitRequiredToStopAudioPlayback, object: recordingURL)
```

## Dynamic File Naming and Formats

The package supports dynamic file naming options, allowing the client to specify the recording file name based on:

- Current date (`.date`)
- Current date with time (`.dateWithTime`)
- Custom name (`.custom(String)`)

Additionally, it supports various output formats including:

- WAV
- FLAC
- MP3
- AAC

### Example

Explore the [sample project](https://github.com/bilalBakhrom/SoundControlKit/tree/master/SoundControlKitExample) that demonstrates how to use SoundControlKit.

## License

SoundControlKit is released under the [Apache License 2.0](https://github.com/bilalBakhrom/SoundControlKit/blob/master/LICENSE).

## Articles

Explore the intricacies of audio recording with these informative articles:
- [Enhancing Audio Recording Mastery: Part I — Mono Mode](https://medium.com/@bilalbakhrom/enhancing-audio-recording-mastery-part-ii-stereo-mode-a458ed18befb)
- [Enhancing Audio Recording Mastery: Part II — Stereo Mode](https://medium.com/@bilalbakhrom/enhancing-audio-recording-mastery-part-i-mono-mode-895f9d8747e1)

### Key Changes:
- Updated the usage section to reflect the dynamic file naming feature.
- Mentioned the supported output formats.
- Cleaned up formatting for better readability. 

Let me know if you need any more changes!
