//
//  SCKRealTimeAudioRecorder.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import UIKit
import AVFoundation
import Combine

public class SCKRealTimeAudioRecorder: SCKAudioSessionManager {
    /// The audio engine used for managing input, output, and effects during recording.
    private let engine: AVAudioEngine
    /// The input node that captures audio from the device's microphone.
    private let inputNode: AVAudioInputNode
    /// The output node used to route audio for playback or further processing.
    private let outputNode: AVAudioOutputNode
    /// The node to hold input nodes.
    private let mixerNode: AVAudioMixerNode
    /// Details about the recording, including filename and format.
    private(set) var recordingDetails: RecordingDetails
    /// The audio file being written to during recording.
    private var audioFile: AVAudioFile?
    /// A weak reference to the delegate that handles recording events and real-time audio data.
    public weak var delegate: SCKRealTimeAudioRecorderDelegate?
    /// Holding recording meter levels.
    private var avgPowers: [Float] = []
    private let sampleRate: Double = 44_100.0
    private var startSampleTime: AVAudioFramePosition = 0
    /// The current state of the audio recording (stopped, recording, or paused).
    private var recordingState: SCKRecordingState = .stopped {
        didSet { triggerRecorderDidChangeState(recordingState) }
    }
    /// Holds separate locks for each method
    private let locks = Array(repeating: NSLock(), count: 5)

    /// Checks if stereo is supported based on the current input node format.
    private var isStereoSupported: Bool {
        let format = inputNode.outputFormat(forBus: 0)
        return format.channelCount >= 2
    }

    public var isRecordPremissionGranted: Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }

    private var canStartRecording: Bool {
        recordingState != .recording && isRecordPremissionGranted
    }

    private var cachedFileURL: URL?

    private var audioSettings: [String: Any] {
        [
            AVFormatIDKey: Int(recordingDetails.format.audioFormatID),
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: isStereoSupported ? 2 : 1,
            AVLinearPCMBitDepthKey: 16,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]
    }
    let label = DispatchQueue(label: "recorder.configure")
    private var fileURL: URL {
        if let cachedFileURL {
            return cachedFileURL
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(recordingDetails.fileName)
        cachedFileURL = fileURL
        return fileURL
    }

    // MARK: - Initialization

    /// Initializes the real-time audio recorder with configurable filename and output format.
    ///
    /// - Parameters:
    ///   - fileName: The naming convention for the output file (default is date).
    ///   - outputFormat: The format for the audio recording (default is AAC).
    public init(
        fileName: SCKRecordingFileNameOption = .date,
        outputFormat: SCKOutputFormat = .aac,
        delegate: SCKRealTimeAudioRecorderDelegate? = nil
    ) {
        self.recordingDetails = RecordingDetails(option: fileName, format: outputFormat)
        self.engine = AVAudioEngine()
        self.mixerNode = AVAudioMixerNode()
        self.inputNode = engine.inputNode
        self.outputNode = engine.outputNode
        self.delegate = delegate
        super.init()
    }
}

// MARK: - Actions

extension SCKRealTimeAudioRecorder {
    /// Handles the real-time audio buffer by writing to the audio file and notifying the delegate.
    ///
    /// - Parameters:
    ///   - buffer: The audio buffer to be processed.
    ///   - time: The AVAudioTime associated with the buffer.
    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Calculate and send average power
        sendAveragePower(with: buffer)
        // Update and send current recording time using the AVAudioTime
        sendCurrentRecordingTime(with: time)
        // Write the buffer to the audio file.
        try? audioFile?.write(from: buffer)
        // Notify delegate with real-time audio buffer data.
        triggerRecorderDidReceiveBuffer(buffer, recordingLocation: fileURL)
    }
}

// MARK: - Setters

extension SCKRealTimeAudioRecorder {
    /// Updates the filename for the output file and reconfigures the audio engine.
    ///
    /// - Parameter option: The new file naming convention.
    public func setFileName(_ option: SCKRecordingFileNameOption) {
        stopRecordingIfNeeded()
        recordingDetails = RecordingDetails(option: option, format: recordingDetails.format)
    }

    /// Updates the output format for the recording and reconfigures the audio engine.
    ///
    /// - Parameter newFormat: The new output format.
    public func setOutputFormat(_ newFormat: SCKOutputFormat) {
        stopRecordingIfNeeded()
        recordingDetails = RecordingDetails(option: recordingDetails.option, format: newFormat)
    }
}

// MARK: - Triggers

extension SCKRealTimeAudioRecorder {
    private func performDelegateCall(lockIndex: LockIndex, action: (SCKRealTimeAudioRecorderDelegate) -> Void) {
        guard let delegate else { return }
        let lock = locks[lockIndex.index]

        lock.lock()
        action(delegate)
        lock.unlock()
    }

    private func triggerRecorderDidChangeState(_ recordingState: SCKRecordingState) {
        performDelegateCall(lockIndex: .recordingState) { delegate in
            delegate.recorderDidChangeState(self, state: recordingState)
        }
    }

    private func triggerRecorderDidFinish(_ audioFileURL: URL) {
        performDelegateCall(lockIndex: .recordingEnd) { delegate in
            delegate.recorderDidFinish(self, at: audioFileURL)
        }
    }

    private func triggerRecorderDidReceiveBuffer(_ buffer: AVAudioPCMBuffer, recordingLocation: URL) {
        performDelegateCall(lockIndex: .recordingBuffer) { delegate in
            delegate.recorderDidReceiveBuffer(self, buffer: buffer, recordingLocation: recordingLocation)
        }
    }

    private func triggerRecorderDidUpdatePowerLevels(_ avgPowers: [Float]) {
        performDelegateCall(lockIndex: .avgPower) { delegate in
            delegate.recorderDidUpdatePowerLevels(self, levels: avgPowers)
        }
    }

    private func triggerRecorderDidUpdateTime(_ time: String) {
        performDelegateCall(lockIndex: .recordingTime) { delegate in
            delegate.recorderDidUpdateTime(self, time: time)
        }
    }

    /// Updates the average power based on the provided buffer and sends it to the recordingPowerSubject.
    private func sendAveragePower(with buffer: AVAudioPCMBuffer) {
        let power = APLConverter.convertToAveragePower(from: buffer)
        avgPowers.append(power)
        triggerRecorderDidUpdatePowerLevels(avgPowers)
    }

    /// Updates and sends the current recording time using the provided AVAudioTime.
    ///
    /// - Parameter time: The AVAudioTime associated with the audio buffer.
    private func sendCurrentRecordingTime(with time: AVAudioTime) {
        let currentSampleTime = time.sampleTime
        // Calculate elapsed time in seconds
        let timeInSeconds = Double(currentSampleTime - startSampleTime) / sampleRate
        // Format the time into minutes and seconds
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        let formattedTime = String(format: "%02d:%02d", minutes, seconds)
        // Send the formatted time
        triggerRecorderDidUpdateTime(formattedTime)
    }

    private func playRecordingStartSound() {
        let systemSoundID: SystemSoundID = 1117
        AudioServicesPlaySystemSound(systemSoundID)
    }

    private func playRecordingStopSound() {
        let systemSoundID: SystemSoundID = 1118
        AudioServicesPlaySystemSound(systemSoundID)
    }
}

// MARK: - Recording Control

extension SCKRealTimeAudioRecorder {
    @MainActor
    public func prepare() {
        configure()
    }

    /// Initiates the audio recording process asynchronously with proper session configuration.
    ///
    /// - Throws: `SCKAudioRecorderError` if the audio session configuration or audio engine fails.
    @MainActor
    public func start() throws {
        guard canStartRecording else { return }

        Task { @MainActor in
            do {
                try await startEngine()
            } catch {
                stop()
                throw SCKAudioRecorderError.engineStartFailure(error)
            }
        }
    }

    /// Stops the recording process and saves the recorded file.
    public func stop() {
        recordingState = .stopped
        engine.stop()
        engine.reset()
        inputNode.removeTap(onBus: 0)
        mixerNode.removeTap(onBus: 0)
        playRecordingStopSound()
        avgPowers = []
        cachedFileURL = nil
        startSampleTime = 0

        // Notify delegate with the file URL where the audio is saved.
        if let audioFileURL = audioFile?.url {
            triggerRecorderDidFinish(audioFileURL)
        }
    }

    @MainActor
    private func startEngine() async throws {
        if recordingState == .stopped {
            startSampleTime = 0
            playRecordingStartSound()
            // Start recording
            recordingState = .recording
            // Wait 0.5 seconds before starting engine.
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        configureEngine()
        try engine.start()
        try setupRealTimeAudioOutput()
    }

    private func stopRecordingIfNeeded() {
        guard recordingState == .recording else { return }
        stop()
    }
}

// MARK: - Configuration

extension SCKRealTimeAudioRecorder {
    /// Configures the audio engine by setting up the audio file and real-time audio output.
    @MainActor
    public func configure() {
        Task {
            do {
                try await configurePlayAndRecordAudioSession(mode: .voiceChat)
            } catch {
                print("Error configuring audio engine: \(error)")
            }
        }
    }

    /// Sets up the audio engine, including the equalizer, reverb, and audio connections.
    private func configureEngine() {
        mixerNode.volume = 0
        inputNode.isVoiceProcessingAGCEnabled = true
        // Attach nodes
        engine.attach(mixerNode)
        // Connect input node to mixer
        engine.connect(inputNode, to: mixerNode, format: inputNode.outputFormat(forBus: 0))
        engine.connect(mixerNode, to: engine.mainMixerNode, format: inputNode.outputFormat(forBus: 0))
        engine.prepare()
    }

    /// Sets up the audio file for writing recorded audio data.
    ///
    /// - Throws: If the file setup fails.
    private func setupAudio() throws {
        audioFile = try AVAudioFile(forWriting: fileURL, settings: audioSettings)
    }

    /// Installs a tap on the input node to capture real-time audio buffers during recording.
    private func setupRealTimeAudioOutput() throws {
        guard engine.isRunning else { return }

        // Initialize audio file.
        try setupAudio()
        // Get input format.
        let inputFormat = inputNode.outputFormat(forBus: 0)
        // Ensure that the engine is running before installing the tap
        inputNode.installTap(
            onBus: 0,
            bufferSize: 2048,
            format: inputFormat,
            block: { [weak self] (buffer, time) in
                guard let self else { return }

                if startSampleTime == 0 {
                    startSampleTime = time.sampleTime
                }

                handleAudioBuffer(buffer, time: time)
            }
        )
    }
}
