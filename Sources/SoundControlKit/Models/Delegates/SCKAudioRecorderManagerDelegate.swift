//
//  SCKAudioRecorderManagerDelegate.swift
//
//
//  Created by Bilal Bakhrom on 2023-11-20.
//

import Foundation

/// Protocol for the delegate of the `SCKAudioRecorderManager` to receive notifications about changes in recording and playback states.
public protocol SCKAudioRecorderManagerDelegate: AnyObject {
    // Triggered when the recording state changes (e.g., started or stopped)
    func recorderManagerDidChangeState(_ manager: SCKAudioRecorderManager, state: SCKRecordingState)

    // Triggered when the recording finishes, providing the location of the saved file
    func recorderManagerDidFinishRecording(_ manager: SCKAudioRecorderManager, at location: URL)

    // Triggered when the average power levels are updated during recording
    func recorderManagerDidUpdatePowerLevels(_ manager: SCKAudioRecorderManager, levels: [Float])

    // Triggered when the recording time is updated
    func recorderManagerDidUpdateTime(_ manager: SCKAudioRecorderManager, time: String)
}

// MARK: - Optional Methods

extension SCKAudioRecorderManagerDelegate {
    public func recorderManagerDidChangeState(_ manager: SCKAudioRecorderManager, state: SCKRecordingState) {}
    public func recorderManagerDidFinishRecording(_ manager: SCKAudioRecorderManager, at location: URL) {}
    public func recorderManagerDidUpdatePowerLevels(_ manager: SCKAudioRecorderManager, levels: [Float]) {}
    public func recorderManagerDidUpdateTime(_ manager: SCKAudioRecorderManager, time: String) {}
}
