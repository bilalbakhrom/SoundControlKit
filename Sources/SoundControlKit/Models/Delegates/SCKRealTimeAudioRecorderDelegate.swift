//
//  SCKRealTimeAudioRecorderDelegate.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation
import AVFoundation

@MainActor
public protocol SCKRealTimeAudioRecorderDelegate: AnyObject {
    /// Called when the recording state changes.
    func audioRecorderDidChangeRecordingState(_ audioRecorder: SCKRealTimeAudioRecorder, state: SCKRecordingState) async

    /// Called when the recording is finished.
    func audioRecorderDidFinishRecording(_ audioRecorder: SCKRealTimeAudioRecorder, at location: URL) async

    /// Called with real-time audio buffers for processing.
    func audioRecorderDidReceiveRealTimeAudioBuffer(_ audioRecorder: SCKRealTimeAudioRecorder, buffer: AVAudioPCMBuffer) async
}
