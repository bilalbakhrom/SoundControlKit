//
//  SCKPlaybackState.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation

/// Represents the possible states of audio playback.
public enum SCKPlaybackState: Sendable {
    /// Audio is currently playing.
    case playing

    /// Audio playback is paused.
    case paused

    /// Audio playback has stopped.
    case stopped
}
