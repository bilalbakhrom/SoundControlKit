//
//  SCKRealTimeAudioRecorderDelegate.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation
import AVFoundation

public protocol SCKRealTimeAudioRecorderDelegate: AnyObject {
    // Triggered when the recording state changes (e.g., started or stopped)
    func recorderDidChangeState(_ recorder: SCKRealTimeAudioRecorder, state: SCKRecordingState)

    // Triggered when the recording finishes, providing the location of the saved file
    func recorderDidFinish(_ recorder: SCKRealTimeAudioRecorder, at location: URL)

    // Triggered when real-time audio buffers are received during recording
    func recorderDidReceiveBuffer(_ recorder: SCKRealTimeAudioRecorder, buffer: AVAudioPCMBuffer)

    // Triggered when average power levels are updated during recording
    func recorderDidUpdatePowerLevels(_ recorder: SCKRealTimeAudioRecorder, levels: [Float])

    // Triggered when the recording time is updated
    func recorderDidUpdateTime(_ recorder: SCKRealTimeAudioRecorder, time: String)
}

extension SCKRealTimeAudioRecorderDelegate {
    public func recorderDidReceiveBuffer(_ recorder: SCKRealTimeAudioRecorder, buffer: AVAudioPCMBuffer) {}
    public func recorderDidUpdatePowerLevels(_ recorder: SCKRealTimeAudioRecorder, levels: [Float]) {}
    public func recorderDidUpdateTime(_ recorder: SCKRealTimeAudioRecorder, time: String) {}
}
