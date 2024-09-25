//
//  SCKAudioManagerDelegate.swift
//
//
//  Created by Bilal Bakhrom on 2023-11-20.
//

import Foundation

/// Protocol for the delegate of the `SCKAudioManager` to receive notifications about changes in recording and playback states.
public protocol SCKAudioManagerDelegate: AnyObject {
    func audioManagerDidChangeRecordingState(_ audioManager: SCKAudioManager, state: SCKRecordingState)
    func audioManagerDidChangePlaybackState(_ audioManager: SCKAudioManager, state: SCKPlaybackState)
    func audioManagerDidFinishRecording(_ audioManager: SCKAudioManager, at location: URL)
    func audioManagerDidFinishPlaying(_ audioManager: SCKAudioManager)
    func audioManagerLastRecordingLocation(_ audioManager: SCKAudioManager, location: URL)
}

// MARK: - Optional Methods

extension SCKAudioManagerDelegate {
    public func audioManagerDidChangeRecordingState(_ audioManager: SCKAudioManager, state: SCKRecordingState) {}
    public func audioManagerDidChangePlaybackState(_ audioManager: SCKAudioManager, state: SCKPlaybackState) {}
    public func audioManagerDidFinishPlaying(_ audioManager: SCKAudioManager) {}
    public func audioManagerLastRecordingLocation(_ audioManager: SCKAudioManager, location: URL) {}
}
