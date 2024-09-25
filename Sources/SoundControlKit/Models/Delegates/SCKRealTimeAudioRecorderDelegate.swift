//
//  SCKRealTimeAudioRecorderDelegate.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation
import AVFoundation

public protocol SCKRealTimeAudioRecorderDelegate: AnyObject {
    /// Called when the recording state changes.
    func audioRecorderDidChangeRecordingState(_ audioRecorder: SCKRealTimeAudioRecorder, state: SCKRecordingState)

    /// Called when the recording is finished.
    func audioRecorderDidFinishRecording(_ audioRecorder: SCKRealTimeAudioRecorder, at location: URL)

    /// Called with real-time audio buffers for processing.
    func audioRecorderDidReceiveRealTimeAudioBuffer(_ audioRecorder: SCKRealTimeAudioRecorder, buffer: AVAudioPCMBuffer)
}
