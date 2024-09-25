//
//  SCKRecorderError.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation

/// Errors specific to the `SCKAudioRecorderManager` class.
public enum SCKRecorderError: Error {
    /// An error indicating failure to create the audio recorder.
    case unableToCreateAudioRecorder
    /// An error indicating failure to select a specific data source for recording.
    case unableToSelectDataSource(name: String)
    /// An error indicating user has not a microphone permission
    case microphonePermissionRequired
}
