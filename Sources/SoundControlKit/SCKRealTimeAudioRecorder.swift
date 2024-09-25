//
//  SCKRealTimeAudioRecorder.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import UIKit
import AVFoundation
import Combine

/// A real-time audio recorder that allows recording and processing audio buffers in real time.
/// It supports configurable output formats, real-time audio effects like equalizer and reverb,
/// and provides delegate methods for recording state and real-time audio buffer handling.
@MainActor
public class SCKRealTimeAudioRecorder: SCKAudioSessionManager {
    // MARK: - Properties

    /// The audio engine used for managing input, output, and effects during recording.
    private let engine: AVAudioEngine
    /// The input node that captures audio from the device's microphone.
    private let inputNode: AVAudioInputNode
    /// The output node used to route audio for playback or further processing.
    private let outputNode: AVAudioOutputNode
    /// The node to hold input nodes.
    private let mixer: AVAudioMixerNode

    /// The current state of the audio recording (stopped, recording, or paused).
    private var recordingState: SCKRecordingState = .stopped {
        didSet { Task { @MainActor in await triggerRecordingState(recordingState) }}
    }
    /// Details about the recording, including filename and format.
    private(set) var recordingDetails: RecordingDetails
    /// The audio file being written to during recording.
    private var audioFile: AVAudioFile?
    /// A weak reference to the delegate that handles recording events and real-time audio data.
    public weak var delegate: SCKRealTimeAudioRecorderDelegate?
    /// The current time publisher subject for recording.
    private let recordingCurrentTimeSubject = PassthroughSubject<String, Never>()
    private let recordingPowerSubject = PassthroughSubject<[Float], Never>()
    private var avgPowers: [Float] = []

    private let sampleRate: Double = 44_100.0
    private var startSampleTime: AVAudioFramePosition = 0

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

    /// Publishes the current time for recording in the format: `mm:ss`.
    public var recordingCurrentTimePublisher: AnyPublisher<String, Never> {
        recordingCurrentTimeSubject.eraseToAnyPublisher()
    }

    public var recordingPowerPublisher: AnyPublisher<[Float], Never> {
        recordingPowerSubject.eraseToAnyPublisher()
    }

    private var canStartRecording: Bool {
        recordingState != .recording && isRecordPremissionGranted
    }

    // MARK: - Initialization

    /// Initializes the real-time audio recorder with configurable filename and output format.
    ///
    /// - Parameters:
    ///   - fileName: The naming convention for the output file (default is date).
    ///   - outputFormat: The format for the audio recording (default is AAC).
    public init(fileName: SCKRecordingFileNameOption = .date, outputFormat: SCKOutputFormat = .aac) {
        self.recordingDetails = RecordingDetails(option: fileName, format: outputFormat)
        self.engine = AVAudioEngine()
        self.mixer = AVAudioMixerNode()
        self.inputNode = engine.inputNode
        self.outputNode = engine.outputNode
        super.init()

        Task { await configure() }
    }

    // MARK: - Actions

    /// Handles the real-time audio buffer by writing to the audio file and notifying the delegate.
    ///
    /// - Parameters:
    ///   - buffer: The audio buffer to be processed.
    ///   - time: The AVAudioTime associated with the buffer.
    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) async {
        do {
            // Notify delegate with real-time audio buffer data.
            await triggerRecordingBuffer(buffer)
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

    private func triggerRecordingState(_ recordingState: SCKRecordingState) async {
        await delegate?.audioRecorderDidChangeRecordingState(self, state: recordingState)
    }

    private func triggerRecordingEnd(_ audioFileURL: URL) async {
        await delegate?.audioRecorderDidFinishRecording(self, at: audioFileURL)
    }

    private func triggerRecordingBuffer(_ buffer: AVAudioPCMBuffer) async {
        await delegate?.audioRecorderDidReceiveRealTimeAudioBuffer(self, buffer: buffer)
    }

    /// Updates the average power based on the provided buffer and sends it to the recordingPowerSubject.
    private func sendAveragePower(with buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(
          from: 0,
          to: Int(buffer.frameLength),
          by: buffer.stride)
          .map { channelDataValue[$0] }

        let rms = sqrt(channelDataValueArray.map {
          return $0 * $0
        }
        .reduce(0, +) / Float(buffer.frameLength))

        let avgPower = 20 * log10(rms)
        avgPowers.append(scaledPower(power: avgPower))

        // Send average powers
        recordingPowerSubject.send(avgPowers)
    }

    private func scaledPower(power: Float) -> Float {
      guard power.isFinite else {
        return 0.0
      }

      let minDb: Float = -80

      if power < minDb {
        return 0.0
      } else if power >= 1.0 {
        return 1.0
      } else {
        return (abs(minDb) - abs(power)) / abs(minDb)
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
        recordingCurrentTimeSubject.send(formattedTime)
    }

    /// Sends a UINotificationFeedbackGenerator notification with a success feedback type.
    /// Delays execution briefly to allow for feedback sensation.
    private func sendFeedbackNotification() async {
        // Create and prepare a UINotificationFeedbackGenerator.
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        // Trigger a success notification feedback.
        generator.notificationOccurred(.success)
        // Introduce a brief delay for the feedback sensation.
        try? await Task.sleep(nanoseconds: 100_000_000)
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
    public func start() async throws {
        guard canStartRecording else { return }

        // Start recording and update the state to recording.
        do {
            // Provide haptic feedback if starting from the stopped state.
            if recordingState == .stopped {
                await sendFeedbackNotification()
            }

            await configure()
            try engine.start()
            startSampleTime = engine.inputNode.lastRenderTime?.sampleTime ?? 0
            setupRealTimeAudioOutput()
            recordingState = .recording
        } catch {
            throw SCKAudioRecorderError.engineStartFailure(error)
        }
    }

    /// Stops the recording process and saves the recorded file.
    public func stop() async {
        engine.stop()
        engine.reset()
        engine.inputNode.removeTap(onBus: 0)
        recordingState = .stopped

        // Notify delegate with the file URL where the audio is saved.
        if let audioFileURL = audioFile?.url {
            await triggerRecordingEnd(audioFileURL)
        }
    }

    private func stopRecordingIfNeeded() async {
        guard recordingState == .recording else { return }
        await stop()
    }
}


// MARK: - Configuration

extension SCKRealTimeAudioRecorder {
    /// Updates the filename for the output file and reconfigures the audio engine.
    ///
    /// - Parameter option: The new file naming convention.
    public func setFileName(_ option: SCKRecordingFileNameOption) async {
        await stopRecordingIfNeeded()
        recordingDetails = RecordingDetails(option: option, format: recordingDetails.format)
        await configure()
    }

    /// Updates the output format for the recording and reconfigures the audio engine.
    ///
    /// - Parameter newFormat: The new output format.
    public func setOutputFormat(_ newFormat: SCKOutputFormat) async {
        await stopRecordingIfNeeded()
        recordingDetails = RecordingDetails(option: recordingDetails.option, format: newFormat)
        await configure()
    }

    /// Configures the audio engine by setting up the audio file and real-time audio output.
    private func configure() async {
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
        // Attach nodes
        engine.attach(mixer)
        // Connect input node to mixer
        engine.connect(inputNode, to: mixer, format: inputNode.outputFormat(forBus: 0))
        engine.prepare()
    }

    /// Sets up the audio file for writing recorded audio data.
    ///
    /// - Throws: If the file setup fails.
    private func setupAudio() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(recordingDetails.fileName)
        // Configure the audio settings.
        let audioSettings: [String: Any] = [
            AVFormatIDKey: Int(recordingDetails.format.audioFormatID),
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: isStereoSupported ? 2 : 1,
            AVLinearPCMBitDepthKey: 16,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]

        // Create a new audio file for writing.
        let audioFile = try AVAudioFile(forWriting: fileURL, settings: audioSettings)
        self.audioFile = audioFile
    }

    /// Installs a tap on the input node to capture real-time audio buffers during recording.
    private func setupRealTimeAudioOutput() {
        let inputFormat = inputNode.outputFormat(forBus: 0)
        // Ensure that the engine is running before installing the tap
        if engine.isRunning {
            inputNode.installTap(
                onBus: 0,
                bufferSize: 1024,
                format: inputFormat
            ) { [weak self] buffer, time in
                guard let self = self else { return }
                Task { @MainActor in await self.handleAudioBuffer(buffer, time: time) }
            }
        } else {
            print("Audio engine is not running when trying to install tap.")
        }
    }
}
