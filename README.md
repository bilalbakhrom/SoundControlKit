# SoundControlKit (SCK)

SoundControlKit (SCK) is a Swift package designed to simplify audio management in iOS applications. It provides an easy-to-use AudioManager for handling audio recording and playback.

## Overview

The SCK package offers a convenient solution for managing audio-related tasks in your Swift projects. It includes functionalities for configuring the audio session, recording audio, playing audio, and controlling playback.

## Installation

### Swift Package Manager

You can add SoundControlKit as a dependency in your Swift Package Manager-enabled project. Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SoundControlKit.git", from: "1.0.0")
]
```

## Usage

To use SoundControlKit in your project, follow these steps:

1. **Import the SoundControlKit module:**

    ```swift
    import SoundControlKit
    ```

2. **Create an instance of `SCKAudioManager` and start recording:**

    ```swift
    let audioManager = SCKAudioManager()
    // Start recording audio
    try audioManager.record()
    ```

5. **Stop recording:**

    ```swift
    // Stop the recording
    audioManager.stop()
    ```

6. **Playback:**
    ```swift
    // Play the recorded audio
    audioManager.play()
    // Pause the playback
    audioManager.pause()
    // Stop the playback
    audioManager.stopPlayback()
    ```

## Example

Explore the [sample project](https://github.com/bilalBakhrom/SoundControlKit/tree/master/SoundControlKitExample) that demonstrates how to use SoundControlKit.

## License

SoundControlKit is released under the [Apache License 2.0](https://github.com/bilalBakhrom/SoundControlKit/blob/master/LICENSE).


