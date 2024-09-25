//
//  SCKRealTimeAudioRecorder.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation
import AVFoundation

public class SCKRealTimeAudioRecorder: SCKAudioSessionManager {
    private let audioEngine: AVAudioEngine
    private let inputNode: AVAudioInputNode
    private let outputNode: AVAudioOutputNode
    private let equalizer: AVAudioUnitEQ
    private let reverb: AVAudioUnitReverb
    private var recordingState: SCKRecordingState = .stopped {
        didSet {
            delegate?.audioRecorderDidChangeRecordingState(self, state: recordingState)
        }
    }
    private(set) var recordingDetails: RecordingDetails
    private var audioFile: AVAudioFile?
    public weak var delegate: SCKRealTimeAudioRecorderDelegate?

    /// Checks if stereo is supported based on the current input node format.
    private var isStereoSupported: Bool {
        let format = inputNode.outputFormat(forBus: 0)
        return format.channelCount >= 2
    }

    public init(fileName: SCKRecordingFileNameOption = .dateWithTime, outputFormat: SCKOutputFormat = .aac) {
        recordingDetails = RecordingDetails(option: fileName, format: outputFormat)
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        outputNode = audioEngine.outputNode
        equalizer = AVAudioUnitEQ(numberOfBands: 1)
        reverb = AVAudioUnitReverb()
        super.init()

        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let band = equalizer.bands[0]
        band.filterType = .parametric
        band.frequency = 1000
        band.bypass = false

        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 50

        audioEngine.attach(equalizer)
        audioEngine.attach(reverb)

        audioEngine.connect(inputNode, to: equalizer, format: inputNode.outputFormat(forBus: 0))
        audioEngine.connect(equalizer, to: reverb, format: inputNode.outputFormat(forBus: 0))
        audioEngine.connect(reverb, to: outputNode, format: inputNode.outputFormat(forBus: 0))
    }

    public func startRecording() throws {
        do {
            configureAudioEngine()
            try audioEngine.start()
            recordingState = .recording
        } catch {
            throw SCKAudioRecorderError.engineStartFailure(error)
        }
    }

    public func stopRecording() {
        audioEngine.stop()
        recordingState = .stopped

        // Notify delegate with the file URL
        if let audioFileURL = audioFile?.url {
            delegate?.audioRecorderDidFinishRecording(self, at: audioFileURL)
        }
    }

    public func pauseRecording() {
        recordingState = .paused
    }

    public func updateFileName(_ option: SCKRecordingFileNameOption) {
        self.recordingDetails = RecordingDetails(
            option: option,
            format: recordingDetails.format
        )
        configureAudioEngine()
    }

    public func updateOutputFormat(_ newFormat: SCKOutputFormat) {
        self.recordingDetails = RecordingDetails(
            option: recordingDetails.option,
            format: newFormat
        )
        configureAudioEngine()
    }

    // MARK: - Configuration

    private func setupAudioFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(recordingDetails.fileName)
        // Configure audio settings.
        let audioSettings: [String: Any] = [
            AVFormatIDKey: Int(recordingDetails.format.audioFormatID),
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: isStereoSupported ? 2 : 1,
            AVLinearPCMBitDepthKey: 16,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]
        // Create audio file
        audioFile = try AVAudioFile(forWriting: fileURL, settings: audioSettings)
    }

    private func setupRealTimeAudioOutput() {
        // Get format from node.
        let format = inputNode.outputFormat(forBus: 0)
        // Listen for real-time audio recording.
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format,
            block: { [weak self] (buffer, time) in
                self?.handleAudioBuffer(buffer)
            }
        )
    }

    private func configureAudioEngine() {
        if recordingState == .recording {
            stopRecording()
        }

        do {
            // Create a new audio file with updated settings
            try setupAudioFile()
            // Install the tap for real-time audio output
            setupRealTimeAudioOutput()
        } catch {
            print("Error reconfiguring audio engine: \(error)")
        }
    }

    // MARK: - Actions

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let audioFile else { return }

        do {
            delegate?.audioRecorderDidReceiveRealTimeAudioBuffer(self, buffer: buffer)
            try audioFile.write(from: buffer)
        } catch {
            print("Error writing audio buffer: \(error)")
        }
    }
}
