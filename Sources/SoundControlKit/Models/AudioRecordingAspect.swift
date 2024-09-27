//
//  LockIndex.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 27/09/24.
//

import Foundation

/// Represents various aspects of an audio recording process.
public enum AudioRecordingAspect {
    /// The current state of the recording.
    case recordingState
    /// Indicates the end of the recording.
    case recordingEnd
    /// Represents the recording buffer.
    case recordingBuffer
    /// The average power of the audio.
    case avgPower
    /// The duration of the recording.
    case recordingTime

    var index: Int {
        switch self {
        case .recordingState: return 0
        case .recordingEnd: return 1
        case .recordingBuffer: return 2
        case .avgPower: return 3
        case .recordingTime: return 4
        }
    }
}
