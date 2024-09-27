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
    @Published var audioPlayers: [SCKAudioPlayer] = []

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

    func removeAudio(at index: Int) {
        guard index < audioPlayers.count else { return }

        do {
            // Get the URL of the audio file to be removed
            let audioPlayer = audioPlayers[index]
            audioPlayer.stop()
            // Remove the audio URL from the array
            audioPlayers.remove(at: index)
            // Remove file from directory
            try FileManager.default.removeItem(at: audioPlayer.audioURL)
        } catch {
            print("Error removing audio file: \(error.localizedDescription)")
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

@MainActor
extension SoundManager {
    func prepare() {
        guard isRecordPremissionGranted else {
            Task { await askRecordingPermission() }
            return
        }

        realTimeRecorder.configure()
        loadAudioFiles()
    }

    func recordAndStop() {
        guard isRecordPremissionGranted else {
            Task { await askRecordingPermission() }
            return
        }

        if isRecording {
            realTimeRecorder.stop()
        } else {
            do {
                try realTimeRecorder.start()
            } catch {
                print("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }

    private func loadAudioFiles() {
        let urls = self.collectAudioFiles()
        audioPlayers = urls.map(SCKAudioPlayer.init)
        audioPlayers.forEach { try? $0.configure() }
    }

    private func askRecordingPermission() async {
        if AVAudioSession.sharedInstance().recordPermission == .undetermined {
            if #available(iOS 17.0, *) {
                guard await AVAudioApplication.requestRecordPermission() else { return }
                prepare()
            } else {
                let audioSession = AVAudioSession.sharedInstance()
                audioSession.requestRecordPermission { [weak self] granted in
                    guard granted else { return }
                    self?.prepare()
                }
            }
        } else {
            isPermissionAlertPresented = true
        }
    }
}

extension SoundManager: SCKRealTimeAudioRecorderDelegate {
    func recorderDidFinish(_ recorder: SCKRealTimeAudioRecorder, at location: URL) {
        Task { @MainActor in
            avgPowers = []
            recordingCurrentTime = "00:00"
            prepare()
        }
    }

    func recorderDidUpdateTime(_ recorder: SCKRealTimeAudioRecorder, time: String) {
        Task { @MainActor in self.recordingCurrentTime = time }
    }

    func recorderDidChangeState(_ recorder: SCKRealTimeAudioRecorder, state: SCKRecordingState) {
        Task { @MainActor in isRecording = state == .recording }
    }

    func recorderDidUpdatePowerLevels(_ recorder: SCKRealTimeAudioRecorder, levels: [Float]) {
        Task { @MainActor in self.avgPowers = levels.reversed() }
    }

    func recorderDidReceiveBuffer(_ recorder: SCKRealTimeAudioRecorder, buffer: AVAudioPCMBuffer, recordingLocation location: URL) {
        // You can implement your logic here with buffer and audio url.
    }
}
