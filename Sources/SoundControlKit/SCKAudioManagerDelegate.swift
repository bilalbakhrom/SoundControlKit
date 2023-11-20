//
//  SCKAudioManagerDelegate.swift
//
//
//  Created by Bilal Bakhrom on 2023-11-20.
//

import Foundation

/// Protocol for the delegate of the `SCKAudioManager` to receive notifications about changes in recording and playback states.
public protocol SCKAudioManagerDelegate: AnyObject {
    func audioManagerDidChangeRecordingState(_ audioManager: SCKAudioManager, state: SCKAudioManager.RecordingState)
    func audioManagerDidChangePlaybackState(_ audioManager: SCKAudioManager, state: SCKAudioManager.PlaybackState)
    func audioManagerDidFinishRecording(_ audioManager: SCKAudioManager, at location: URL)
    func audioManagerDidFinishPlaying(_ audioManager: SCKAudioManager)
    func audioManagerLastRecordingLocation(_ audioManager: SCKAudioManager, location: URL)
}

// MARK: - Optional Methods

extension SCKAudioManagerDelegate {
    func audioManagerDidChangeRecordingState(_ audioManager: SCKAudioManager, state: SCKAudioManager.RecordingState) {}
    func audioManagerDidChangePlaybackState(_ audioManager: SCKAudioManager, state: SCKAudioManager.PlaybackState) {}
    func audioManagerDidFinishPlaying(_ audioManager: SCKAudioManager) {}
    func audioManagerLastRecordingLocation(_ audioManager: SCKAudioManager, location: URL) {}
}
