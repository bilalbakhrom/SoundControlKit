//
//  SCKAudioRecorderManager.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import UIKit
import AVFoundation
import Combine

/// Manages audio recording functionality, including setup, configuration, and control.
open class SCKAudioRecorderManager: SCKAudioSessionManager {
    public weak var delegate: SCKAudioRecorderManagerDelegate?
    
    /// The AVAudioRecorder instance for handling audio recording.
    private var recorder: AVAudioRecorder?
    /// The file name option for the recording.
    private(set) var recordingDetails: RecordingDetails
    /// Recording meter levels.
    private var avgPowers: [Float] = []
    /// A cancellable timer for managing recording time (not currently used).
    private var timer: AnyCancellable?
    /// Holds separate locks for each method.
    private let locks = Array(repeating: NSLock(), count: 5)
    /// Coordinator to hold `AVAudioRecorderDelegate`.
    private weak var coordinator: Coordinator?

    /// The current state of the audio recording (stopped, recording, or paused).
    private var recordingState: SCKRecordingState = .stopped {
        didSet { triggerRecorderDidChangeState(recordingState) }
    }

    /// Indicates whether stereo recording is supported.
    private var isStereoSupported: Bool = false {
        didSet {
            try? setupAudioRecorder()
        }
    }

    public var isRecordPremissionGranted: Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }
    
    // MARK: - Initialization
    
    public init(
        fileName: SCKRecordingFileNameOption = .dateWithTime,
        format: SCKOutputFormat = .aac,
        delegate: SCKAudioRecorderManagerDelegate? = nil
    ) {
        self.recordingDetails = RecordingDetails(option: fileName, format: format)
        self.delegate = delegate
        super.init()

        coordinator = Coordinator(parent: self)
    }

    public func configureRecorder() throws {
        // Check if the user has granted permission for audio recording.
        guard isRecordPremissionGranted else {
            throw SCKRecorderError.microphonePermissionRequired
        }
        
        // Continue with the configuration if permission is granted.
        try configurePlayAndRecordAudioSession()
        try enableBuiltInMicrophone()
        try setupAudioRecorder()
        
        // Asynchronously set the default data source and orientation.
        Task {
            // Attempt to update the orientation to portrait.
            // Note: We're not handling errors here; if any occur, they will be silently ignored.
            try? await updateOrientation(interfaceOrientation: .portrait)
        }
    }

    /// Updates the file name if the client wants to change it.
    public func updateFileName(_ option: SCKRecordingFileNameOption) {
        self.recordingDetails = RecordingDetails(
            option: option,
            format: recordingDetails.format
        )
        try? configureRecorder()
    }

    /// Updates the output format if the client wants to change it.
    public func updateOutputFormat(_ newFormat: SCKOutputFormat) {
        self.recordingDetails = RecordingDetails(
            option: recordingDetails.option,
            format: newFormat
        )
        try? configureRecorder()
    }

    // MARK: - Triggers

    private func performDelegateCall(lockIndex: LockIndex, action: (SCKAudioRecorderManagerDelegate) -> Void) {
        guard let delegate else { return }
        let lock = locks[lockIndex.index]

        lock.lock()
        action(delegate)
        lock.unlock()
    }

    private func triggerRecorderDidChangeState(_ recordingState: SCKRecordingState) {
        performDelegateCall(lockIndex: .recordingState) { delegate in
            delegate.recorderManagerDidChangeState(self, state: recordingState)
        }
    }

    private func triggerRecorderDidFinish(_ audioFileURL: URL) {
        performDelegateCall(lockIndex: .recordingEnd) { delegate in
            delegate.recorderManagerDidFinishRecording(self, at: audioFileURL)
        }
    }

    private func triggerRecorderDidUpdatePowerLevels(_ avgPowers: [Float]) {
        performDelegateCall(lockIndex: .avgPower) { delegate in
            delegate.recorderManagerDidUpdatePowerLevels(self, levels: avgPowers)
        }
    }

    private func triggerRecorderDidUpdateTime(_ time: String) {
        performDelegateCall(lockIndex: .recordingTime) { delegate in
            delegate.recorderManagerDidUpdateTime(self, time: time)
        }
    }

    // MARK: - Audio Recorder Setup
    
    /// Sets up the audio recorder with the necessary configurations.
    private func setupAudioRecorder() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(recordingDetails.fileName)

        do {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: Int(recordingDetails.format.audioFormatID),
                AVLinearPCMIsNonInterleaved: false,
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: isStereoSupported ? 2 : 1,
                AVLinearPCMBitDepthKey: 16,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]
            recorder = try AVAudioRecorder(url: fileURL, settings: audioSettings)
        } catch {
            throw SCKRecorderError.unableToCreateAudioRecorder
        }
        
        recorder?.delegate = coordinator
        recorder?.isMeteringEnabled = true
        recorder?.prepareToRecord()
    }
    
    // MARK: - Wave Controller
    
    private func updateAveragePower() {
        guard let recorder else { return }
        let power = APLConverter.normalizedAveragePower(
            from: recorder,
            isStereoSupported: isStereoSupported
        )
        avgPowers.append(power)
        triggerRecorderDidUpdatePowerLevels(avgPowers)
    }

    // MARK: - Timer Methods
    
    /// Initiates a timer to track the duration of the audio recording.
    /// The timer publishes updates every 0.1 seconds on the main thread.
    /// When recording, the timer updates and sends the formatted duration to the `audioRecordingTimerPublisher`.
    private func startTimer() {
        timer = Timer
            .publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] timer in
                guard let self, let recorder, self.recordingState == .recording else { return }

                // Format the current recording duration and send it to the publisher.
                let timeInMinutesAndSeconds = self.formatTime(recorder.currentTime)
                triggerRecorderDidUpdateTime(timeInMinutesAndSeconds)
                self.updateAveragePower()
            }
    }

    /// Stops the recording timer.
    /// Cancels the timer subscription and releases the timer instance.
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
}

// MARK: - Controller

extension SCKAudioRecorderManager {
    /// Initiates the audio recording process.
    public func record() {
        guard recordingState != .recording && isRecordPremissionGranted else { return }

        // Update session configuration for recording.
        try? configurePlayAndRecordAudioSession()

        // Start the recording timer if not already initialized.
        startTimer()

        // Begin audio recording and update the state to recording.
        recorder?.record()
        recordingState = .recording
    }

    /// Initiates the audio recording process asynchronously.
    /// If not already recording, triggers a haptic vibration.
    @MainActor
    public func record() async {
        // Do not initiate recording if the app is already recording.
        guard recordingState != .recording && isRecordPremissionGranted else { return }

        // Update session configuration for recording.
        try? await configurePlayAndRecordAudioSession()

        // If transitioning from a stopped state, provide a success feedback notification.
        if recordingState == .stopped {
            await sendFeedbackNotification()
        }

        // Start the recording timer if not already initialized.
        if timer == nil {
            startTimer()
        }

        // Begin audio recording and update the state to recording.
        recorder?.record()
        recordingState = .recording
    }

    /// Pauses the audio recording process if currently recording.
    public func pause() {
        // Do not pause if the app is not currently recording.
        guard recordingState == .recording else { return }

        // Pause the audio recorder and update the state to paused.
        recorder?.pause()
        recordingState = .paused
    }


    /// Stops the audio recording process.
    public func stop() {
        recorder?.stop()
        recordingState = .stopped
        avgPowers = []
        stopTimer()
    }

    /// Deletes the current recording.
    public func delete() {
        // Stop audio recorder before deleting.
        stop()
        // Delete recording.
        recorder?.deleteRecording()
        // Post a notification to stop playback if it's playing.
        NotificationCenter.default.post(sckNotification: .stopAllAudioPlayback)
    }

    /// Updates the audio input orientation and data source based on the specified parameters.
    ///
    /// - Parameters:
    ///   - orientation: The desired orientation of the audio input.
    ///   - interfaceOrientation: The current user interface orientation.
    /// - Throws: A `SCKRecorderError` if unable to select the specified data source.
    public func updateOrientation(
        withDataSourceOrientation orientation: AVAudioSession.Orientation = .front,
        interfaceOrientation: UIInterfaceOrientation
    ) async throws {
        // Don't update the data source if the app is currently recording.
        guard recordingState != .recording else { return }

        // Get the shared audio session.
        let session = AVAudioSession.sharedInstance()

        // Find the data source matching the specified orientation.
        guard let preferredInput = session.preferredInput,
              let dataSources = preferredInput.dataSources,
              let newDataSource = dataSources.first(where: { $0.orientation == orientation }),
              let supportedPolarPatterns = newDataSource.supportedPolarPatterns else {
            return
        }

        do {
            // Check for iOS 14.0 availability to handle stereo support.
            if #available(iOS 14.0, *) {
                isStereoSupported = supportedPolarPatterns.contains(.stereo)

                // Set the preferred polar pattern to stereo if supported.
                if isStereoSupported {
                    try newDataSource.setPreferredPolarPattern(.stereo)
                }
            }

            // Set the preferred data source.
            try preferredInput.setPreferredDataSource(newDataSource)

            // Set the preferred input orientation based on the interface orientation.
            if #available(iOS 14.0, *) {
                try session.setPreferredInputOrientation(interfaceOrientation.inputOrientation)
            }
        } catch {
            throw SCKRecorderError.unableToSelectDataSource(name: newDataSource.dataSourceName)
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension SCKAudioRecorderManager {
    public final class Coordinator: NSObject, AVAudioRecorderDelegate {
        public let parent: SCKAudioRecorderManager

        public init(parent: SCKAudioRecorderManager) {
            self.parent = parent
        }

        public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
            // Move the recorded audio file to the documents directory.
            let destURL = FileManager.default.urlInDocumentsDirectory(named: parent.recordingDetails.fileName)
            try? FileManager.default.removeItem(at: destURL)
            try? FileManager.default.moveItem(at: recorder.url, to: destURL)
            recorder.prepareToRecord()

            parent.avgPowers = []
            parent.recordingState = .stopped
            parent.triggerRecorderDidFinish(recorder.url)
        }
    }
}

// MARK: - Helper Methods

extension SCKAudioRecorderManager {
    /// Formats the given duration in seconds into a string representing minutes and seconds.
    /// - Parameter duration: The duration in seconds.
    /// - Returns: A formatted string in the "MM:SS" (minutes:seconds) format.
    private func formatTime(_ duration: TimeInterval) -> String {
        // Calculate minutes and seconds from the duration.
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        // Format the duration as "MM:SS" and return the result.
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Sends a UINotificationFeedbackGenerator notification with a success feedback type.
    /// Delays execution briefly to allow for feedback sensation.
    private func sendFeedbackNotification() async {
        // Create and prepare a UINotificationFeedbackGenerator.
        let generator = await UINotificationFeedbackGenerator()
        await generator.prepare()
        // Trigger a success notification feedback.
        await generator.notificationOccurred(.success)
        // Introduce a brief delay for the feedback sensation.
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
}
