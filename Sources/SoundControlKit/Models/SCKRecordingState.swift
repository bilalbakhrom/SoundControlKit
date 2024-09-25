//
//  SCKRecordingState.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation

// MARK: - Recording State

/// Represents the possible states of audio recording.
public enum SCKRecordingState: Sendable {
    case stopped
    case paused
    case recording
}
