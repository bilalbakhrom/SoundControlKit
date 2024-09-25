//
//  SCKRealTimeAudioRecorder.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation
import AVFoundation

/// A real-time audio recorder that allows recording and processing audio buffers in real time.
/// It supports configurable output formats, real-time audio effects like equalizer and reverb,
/// and provides delegate methods for recording state and real-time audio buffer handling.
public class SCKRealTimeAudioRecorder: SCKAudioSessionManager {
    // MARK: - Properties

    /// The audio engine used for managing input, output, and effects during recording.
    private let audioEngine: AVAudioEngine
    /// The input node that captures audio from the device's microphone.
    private let inputNode: AVAudioInputNode
    /// The output node used to route audio for playback or further processing.
    private let outputNode: AVAudioOutputNode
    /// An equalizer applied to the audio input, with configurable bands.
    private let equalizer: AVAudioUnitEQ
    /// A reverb unit that adds reverberation effect to the audio signal.
    private let reverb: AVAudioUnitReverb
    /// The current state of the audio recording (stopped, recording, or paused).
    private var recordingState: SCKRecordingState = .stopped {
        didSet {
            delegate?.audioRecorderDidChangeRecordingState(self, state: recordingState)
        }
    }
    /// Details about the recording, including filename and format.
    private(set) var recordingDetails: RecordingDetails
    /// The audio file being written to during recording.
    private var audioFile: AVAudioFile?
    /// A weak reference to the delegate that handles recording events and real-time audio data.
    public weak var delegate: SCKRealTimeAudioRecorderDelegate?

    /// Checks if stereo is supported based on the current input node format.
    private var isStereoSupported: Bool {
        let format = inputNode.outputFormat(forBus: 0)
        return format.channelCount >= 2
    }

    // MARK: - Initialization

    /// Initializes the real-time audio recorder with configurable filename and output format.
    ///
    /// - Parameters:
    ///   - fileName: The naming convention for the output file (default is date with time).
    ///   - outputFormat: The format for the audio recording (default is AAC).
    public init(fileName: SCKRecordingFileNameOption = .dateWithTime, outputFormat: SCKOutputFormat = .aac) {
        self.recordingDetails = RecordingDetails(option: fileName, format: outputFormat)
        self.audioEngine = AVAudioEngine()
        self.inputNode = audioEngine.inputNode
        self.outputNode = audioEngine.outputNode
        self.equalizer = AVAudioUnitEQ(numberOfBands: 1)
        self.reverb = AVAudioUnitReverb()
        super.init()

        setupAudioEngine()
    }

    // MARK: - Setup Methods

    /// Sets up the audio engine, including the equalizer, reverb, and audio connections.
    private func setupAudioEngine() {
        // Configure the equalizer band.
        let band = equalizer.bands[0]
        band.filterType = .parametric
        band.frequency = 1000
        band.bypass = false

        // Configure the reverb effect.
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 50

        // Attach and connect nodes in the audio engine.
        audioEngine.attach(equalizer)
        audioEngine.attach(reverb)
        audioEngine.connect(inputNode, to: equalizer, format: inputNode.outputFormat(forBus: 0))
        audioEngine.connect(equalizer, to: reverb, format: inputNode.outputFormat(forBus: 0))
        audioEngine.connect(reverb, to: outputNode, format: inputNode.outputFormat(forBus: 0))
    }

    // MARK: - Recording Control

    /// Starts the recording process by configuring the audio engine and starting it.
    ///
    /// - Throws: `SCKAudioRecorderError.engineStartFailure` if the audio engine fails to start.
    public func startRecording() throws {
        do {
            configureAudioEngine()
            try audioEngine.start()
            recordingState = .recording
        } catch {
            throw SCKAudioRecorderError.engineStartFailure(error)
        }
    }

    /// Stops the recording process and saves the recorded file.
    public func stopRecording() {
        audioEngine.stop()
        recordingState = .stopped

        // Notify delegate with the file URL where the audio is saved.
        if let audioFileURL = audioFile?.url {
            delegate?.audioRecorderDidFinishRecording(self, at: audioFileURL)
        }
    }

    /// Pauses the recording process.
    public func pauseRecording() {
        recordingState = .paused
    }

    // MARK: - Configuration Updates

    /// Updates the filename for the output file and reconfigures the audio engine.
    ///
    /// - Parameter option: The new file naming convention.
    public func updateFileName(_ option: SCKRecordingFileNameOption) {
        self.recordingDetails = RecordingDetails(option: option, format: recordingDetails.format)
        configureAudioEngine()
    }

    /// Updates the output format for the recording and reconfigures the audio engine.
    ///
    /// - Parameter newFormat: The new output format.
    public func updateOutputFormat(_ newFormat: SCKOutputFormat) {
        self.recordingDetails = RecordingDetails(option: recordingDetails.option, format: newFormat)
        configureAudioEngine()
    }

    // MARK: - Audio Engine Configuration

    /// Configures the audio engine by setting up the audio file and real-time audio output.
    private func configureAudioEngine() {
        // If currently recording, stop the recording before reconfiguring.
        if recordingState == .recording {
            stopRecording()
        }

        do {
            // Set up the audio file with the new settings.
            try setupAudioFile()
            // Install the tap for capturing real-time audio buffers.
            setupRealTimeAudioOutput()
        } catch {
            print("Error reconfiguring audio engine: \(error)")
        }
    }

    /// Sets up the audio file for writing recorded audio data.
    ///
    /// - Throws: If the file setup fails.
    private func setupAudioFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(recordingDetails.fileName)

        // Configure the audio settings.
        let audioSettings: [String: Any] = [
            AVFormatIDKey: Int(recordingDetails.format.audioFormatID),
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: isStereoSupported ? 2 : 1,
            AVLinearPCMBitDepthKey: 16,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]

        // Create a new audio file for writing.
        audioFile = try AVAudioFile(forWriting: fileURL, settings: audioSettings)
    }

    /// Installs a tap on the input node to capture real-time audio buffers during recording.
    private func setupRealTimeAudioOutput() {
        // Get the format from the input node.
        let format = inputNode.outputFormat(forBus: 0)

        // Install the tap to handle real-time audio data.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.handleAudioBuffer(buffer)
        }
    }

    // MARK: - Real-Time Audio Handling

    /// Handles the real-time audio buffer by writing to the audio file and notifying the delegate.
    ///
    /// - Parameter buffer: The audio buffer to be processed.
    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let audioFile else { return }

        do {
            // Notify delegate with real-time audio buffer data.
            delegate?.audioRecorderDidReceiveRealTimeAudioBuffer(self, buffer: buffer)

            // Write the buffer to the audio file.
            try audioFile.write(from: buffer)
        } catch {
            print("Error writing audio buffer: \(error)")
        }
    }
}
