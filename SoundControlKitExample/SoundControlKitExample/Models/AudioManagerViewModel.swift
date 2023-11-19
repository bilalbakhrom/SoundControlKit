//
//  AudioManagerViewModel.swift
//  AudioRecorder
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import Foundation
import SoundControlKit

class AudioManagerViewModel: ObservableObject {
    private(set) var audioManager: SCKAudioManager!
    
    @Published var recordingURL: URL?
    @Published var isRecording: Bool = false
    @Published var isPlaying: Bool = false
    @Published var avgPowers: [Float] = []
    
    init() {
        self.audioManager = SCKAudioManager(delegate: self)
    }
    
    func prepare() {
        audioManager.resetPlayback()
    }
        
    func recordAndStop() {
        isRecording ? audioManager.stop() : audioManager.record()
    }
    
    func playAndStop() {
        isPlaying ? audioManager.pause() : audioManager.play()
    }
    
    func forwardPlayback() {
        audioManager.forwardPlayback(by: 5)
    }
    
    func rewindPlayback() {
        audioManager.rewindPlayback(by: 5)
    }
    
    func deleteRecording() {
        audioManager.deleteRecording()
        audioManager.resetPlayback()
        recordingURL = nil
    }
}

extension AudioManagerViewModel: SCKAudioManagerDelegate {
    func audioManagerDidChangeRecordingState(_ audioManager: SCKAudioManager, state: SCKAudioRecorderManager.RecordingState) {
        Task {
            await MainActor.run {
                isRecording = state == .recording
            }
        }
    }
    
    func audioManagerDidChangePlaybackState(_ audioManager: SCKAudioManager, state: SCKAudioManager.PlaybackState) {
        Task {
            await MainActor.run {
                isPlaying = state == .playing
            }
        }
    }
    
    func audioManagerDidFinishRecording(_ audioManager: SCKAudioManager, at location: URL) {
        recordingURL = location
        avgPowers = []
    }
    
    func audioManagerDidFinishPlaying(_ audioManager: SCKAudioManager) {}
    
    func audioManagerLastRecordingLocation(_ audioManager: SCKAudioManager, location: URL) {
        recordingURL = location
    }
}
