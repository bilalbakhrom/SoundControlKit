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
        didSet { triggerRecordingState(recordingState) }
    }
    /// Holds separate locks for each method
    private let locks = [
        NSLock(), // For recording state
        NSLock(), // For recording end
        NSLock(), // For recording buffer
        NSLock(), // For average power
        NSLock()  // For recording time
    ]

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

    private var fileURL: URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent(recordingDetails.fileName)
    }

    // MARK: - Initialization

    /// Initializes the real-time audio recorder with configurable filename and output format.
    ///
    /// - Parameters:
    ///   - fileName: The naming convention for the output file (default is date).
    ///   - outputFormat: The format for the audio recording (default is AAC).
    public init(fileName: SCKRecordingFileNameOption = .date, outputFormat: SCKOutputFormat = .aac, delegate: SCKRealTimeAudioRecorderDelegate? = nil) {
        self.recordingDetails = RecordingDetails(option: fileName, format: outputFormat)
        self.engine = AVAudioEngine()
        self.mixerNode = AVAudioMixerNode()
        self.inputNode = engine.inputNode
        self.outputNode = engine.outputNode
        self.delegate = delegate
        super.init()
    }
}

extension SCKRealTimeAudioRecorder {
    // MARK: - Actions

    /// Handles the real-time audio buffer by writing to the audio file and notifying the delegate.
    ///
    /// - Parameters:
    ///   - buffer: The audio buffer to be processed.
    ///   - time: The AVAudioTime associated with the buffer.
    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        do {
            // Notify delegate with real-time audio buffer data.
            triggerRecordingBuffer(buffer)
            // Calculate and send average power
            sendAveragePower(with: buffer)
            // Update and send current recording time using the AVAudioTime
            sendCurrentRecordingTime(with: time)
            // Write the buffer to the audio file.
            try audioFile?.write(from: buffer)
        } catch {
            print("Error writing audio buffer: \(error)")
        }
    }

    // MARK: - Triggers

    private func performDelegateCall(lockIndex: LockIndex, action: (SCKRealTimeAudioRecorderDelegate) -> Void) {
        guard let delegate else { return }
        let lock = locks[lockIndex.index]

        lock.lock()
        action(delegate)
        lock.unlock()
    }

    private func triggerRecordingState(_ recordingState: SCKRecordingState) {
        performDelegateCall(lockIndex: .recordingState) { delegate in
            delegate.audioRecorderDidChangeRecordingState(self, state: recordingState)
        }
    }

    private func triggerRecordingEnd(_ audioFileURL: URL) {
        performDelegateCall(lockIndex: .recordingEnd) { delegate in
            delegate.audioRecorderDidFinishRecording(self, at: audioFileURL)
        }
    }

    private func triggerRecordingBuffer(_ buffer: AVAudioPCMBuffer) {
        performDelegateCall(lockIndex: .recordingBuffer) { delegate in
            delegate.audioRecorderDidReceiveRealTimeAudioBuffer(self, buffer: buffer)
        }
    }

    private func triggerAvgPower(_ avgPowers: [Float]) {
        performDelegateCall(lockIndex: .avgPower) { delegate in
            delegate.audioRecorderDidUpdateAveragePower(self, avgPowers: avgPowers)
        }
    }

    private func triggerRecordingTime(_ time: String) {
        performDelegateCall(lockIndex: .recordingTime) { delegate in
            delegate.audioRecorderDidUpdateTime(self, time: time)
        }
    }

    /// Updates the average power based on the provided buffer and sends it to the recordingPowerSubject.
    private func sendAveragePower(with buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride
        ).map { channelDataValue[$0] }

        let rms = sqrt(channelDataValueArray.map { $0 * $0 }
            .reduce(0, +) / Float(buffer.frameLength))

        let power = scaledPower(rms: rms)
        print("Power: \(power)")
        avgPowers.append(power)
        triggerAvgPower(avgPowers)
    }

    private func scaledPower(rms: Float) -> Float {
        let power = rms > 0 ? 20 * log10(rms) : -Float.infinity
        let minDb: Float = -80

        guard power.isFinite else { return 0.0 }

        if power < minDb {
            return 0.0
        } else if power >= 0 {
            return 1.0
        } else {
            return (power - minDb) / (0 - minDb)
        }
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
        triggerRecordingTime(formattedTime)
    }

    /// Sends a UINotificationFeedbackGenerator notification with a success feedback type.
    /// Delays execution briefly to allow for feedback sensation.
    private func sendFeedbackNotification() {
        Task { @MainActor in
            // Create and prepare a UINotificationFeedbackGenerator.
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            // Trigger a success notification feedback.
            generator.notificationOccurred(.success)
            // Introduce a brief delay for the feedback sensation.
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}

// MARK: - Recording Control

extension SCKRealTimeAudioRecorder {
    /// Initiates the audio recording process asynchronously with proper session configuration.
    ///
    /// This method checks if recording is already in progress and ensures that recording permission
    /// has been granted. If the state is `.stopped`, it will provide haptic feedback, configure the
    /// audio session for recording, and start the audio engine to begin recording.
    ///
    /// - Throws: `SCKAudioRecorderError` if the audio session configuration or audio engine fails.
    public func start() throws {
        guard canStartRecording else { return }

        // Start recording and update the state to recording.
        do {
            // Provide haptic feedback if starting from the stopped state.
            if recordingState == .stopped {
                sendFeedbackNotification()
            }

            configure()
            try engine.start()
            startSampleTime = engine.mainMixerNode.lastRenderTime?.sampleTime ?? 0
            setupRealTimeAudioOutput()
            recordingState = .recording
        } catch {
            throw SCKAudioRecorderError.engineStartFailure(error)
        }
    }

    /// Stops the recording process and saves the recorded file.
    public func stop() {
        engine.stop()
        inputNode.removeTap(onBus: 0)
        recordingState = .stopped
        avgPowers = []
        startSampleTime = 0

        // Notify delegate with the file URL where the audio is saved.
        if let audioFileURL = audioFile?.url {
            triggerRecordingEnd(audioFileURL)
        }
    }

    private func stopRecordingIfNeeded() {
        guard recordingState == .recording else { return }
        stop()
    }
}


// MARK: - Configuration

extension SCKRealTimeAudioRecorder {
    /// Updates the filename for the output file and reconfigures the audio engine.
    ///
    /// - Parameter option: The new file naming convention.
    public func setFileName(_ option: SCKRecordingFileNameOption) {
        stopRecordingIfNeeded()
        recordingDetails = RecordingDetails(option: option, format: recordingDetails.format)
        configure()
    }

    /// Updates the output format for the recording and reconfigures the audio engine.
    ///
    /// - Parameter newFormat: The new output format.
    public func setOutputFormat(_ newFormat: SCKOutputFormat) {
        stopRecordingIfNeeded()
        recordingDetails = RecordingDetails(option: recordingDetails.option, format: newFormat)
        configure()
    }

    /// Configures the audio engine by setting up the audio file and real-time audio output.
    public func configure() {
        do {
            try configurePlayAndRecordAudioSession()
            try setupAudio()
            configureEngine()
        } catch {
            print("Error configuring audio engine: \(error)")
        }
    }

    /// Sets up the audio engine, including the equalizer, reverb, and audio connections.
    private func configureEngine() {
        engine.reset()
        mixerNode.volume = 0
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
    private func setupRealTimeAudioOutput() {
        guard engine.isRunning else { return }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        // Ensure that the engine is running before installing the tap
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: inputFormat,
            block: { [weak self] (buffer, time) in
                guard let self else { return }
                handleAudioBuffer(buffer, time: time)
            }
        )
    }
}

extension SCKRealTimeAudioRecorder {
    private enum LockIndex {
        case recordingState, recordingEnd, recordingBuffer, avgPower, recordingTime

        var index: Int {
            switch self {
            case .recordingState: return 0
            case .recordingEnd: return 1
            case .recordingBuffer: return 2
            case .avgPower: return 3
            case .recordingTime: return 4
            }
        }
    }
}
