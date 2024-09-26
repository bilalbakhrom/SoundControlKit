//
//  SoundManager.swift
//  AudioRecorder
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import Foundation
import SoundControlKit
import AVFoundation
import Combine

final class SoundManager: NSObject, ObservableObject {
    private(set) var realTimeRecorder: SCKRealTimeAudioRecorder!

    @Published var isRecording: Bool = false
    @Published var avgPowers: [Float] = []
    @Published var isPermissionAlertPresented: Bool = false
    @Published var recordingCurrentTime: String = "00:00"

    @Published var audioURLs: [URL] = []
    @Published var currentAudioTime: TimeInterval = 0
    @Published var totalAudioDuration: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var currentlyPlayingIndex: Int?

    private var audioPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()

    public var isRecordPremissionGranted: Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }

    override init() {
        realTimeRecorder = SCKRealTimeAudioRecorder(fileName: .dateWithTime, outputFormat: .aac)
        super.init()

        realTimeRecorder.delegate = self
        realTimeRecorder.configure()
    }

    func prepare() {
        loadAudioFiles()
    }

    func recordAndStop() {
        guard isRecordPremissionGranted else {
            askRecordingPermission()
            return
        }
        
        if isRecording {
            realTimeRecorder.stop()
        } else {
            try? realTimeRecorder.start()
        }
    }

    func loadAudioFiles() {
        // Load audio files from temporary directory
        self.audioURLs = collectAudioFiles()
    }

    func playAudio(at index: Int) {
        if currentlyPlayingIndex == index {
            // If the same audio is tapped, stop it
            stopAudio()
            return
        }

        // Stop any currently playing audio
        stopAudio()

        // Play the selected audio
        guard index < audioURLs.count else { return }
        let url = audioURLs[index]

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
            currentlyPlayingIndex = index
            totalAudioDuration = audioPlayer?.duration ?? 0

            // Start a timer to update current time
            Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.currentAudioTime = self?.audioPlayer?.currentTime ?? 0
                }
                .store(in: &cancellables)
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }

    func stopAudio() {
        audioPlayer?.stop()
        isPlaying = false
        currentlyPlayingIndex = nil
        currentAudioTime = 0
    }

    func removeAudio(at index: Int) {
        guard index < audioURLs.count else { return }

        // Get the URL of the audio file to be removed
        let audioURL = audioURLs[index]

        // Remove the audio URL from the array
        audioURLs.remove(at: index)

        // Stop audio if it was playing
        if currentlyPlayingIndex == index {
            stopAudio()
        } else if currentlyPlayingIndex != nil && index < currentlyPlayingIndex! {
            // Adjust the currently playing index if necessary
            currentlyPlayingIndex! -= 1
        }

        // Remove the audio file from the file system
        do {
            try FileManager.default.removeItem(at: audioURL)
        } catch {
            print("Error removing audio file: \(error.localizedDescription)")
        }
    }

    private func askRecordingPermission() {
        if AVAudioSession.sharedInstance().recordPermission == .undetermined {
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { [weak self] _ in
                    self?.prepare()
                }
            } else {
                let audioSession = AVAudioSession.sharedInstance()
                audioSession.requestRecordPermission { [weak self] _ in
                    self?.prepare()
                }
            }
        } else {
            isPermissionAlertPresented = true
        }
    }

    private func collectAudioFiles() -> [URL] {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        let audioExtensions = SCKOutputFormat.supportedFormats

        do {
            // Get all files in the temporary directory
            let allFiles = try fileManager.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
            // Filter for audio files based on the defined extensions
            let audioFiles = allFiles.filter { url in
                audioExtensions.contains(url.pathExtension.lowercased())
            }

            return audioFiles
        } catch {
            print("Error while fetching audio files: \(error.localizedDescription)")
            return []
        }
    }
}

extension SoundManager: SCKAudioManagerDelegate {
    func audioManagerDidChangeRecordingState(_ audioManager: SCKAudioManager, state: SCKRecordingState) {
        Task { @MainActor in isRecording = state == .recording }
    }

    func audioManagerDidChangePlaybackState(_ audioManager: SCKAudioManager, state: SCKPlaybackState) {
        Task { @MainActor in isPlaying = state == .playing }
    }

    func audioManagerDidFinishRecording(_ audioManager: SCKAudioManager, at location: URL) {
        avgPowers = []
        prepare()
    }
}

extension SoundManager: SCKRealTimeAudioRecorderDelegate {
    func audioRecorderDidChangeRecordingState(_ audioRecorder: SCKRealTimeAudioRecorder, state: SCKRecordingState) {
        isRecording = state == .recording
    }

    func audioRecorderDidFinishRecording(_ audioRecorder: SCKRealTimeAudioRecorder, at location: URL) {
        avgPowers = []
        prepare()
    }

    func audioRecorderDidUpdateAveragePower(_ audioRecorder: SCKRealTimeAudioRecorder, avgPowers: [Float]) {
        Task { @MainActor in self.avgPowers = avgPowers.reversed() }
    }

    func audioRecorderDidUpdateTime(_ audioRecorder: SCKRealTimeAudioRecorder, time: String) {
        Task { @MainActor in self.recordingCurrentTime = time }
    }
}

extension SoundManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentAudioTime = 0
        currentlyPlayingIndex = nil
    }
}
