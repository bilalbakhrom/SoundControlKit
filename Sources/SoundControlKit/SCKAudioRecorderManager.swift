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
    // MARK: - Properties
    
    /// Current state of audio recording.
    private(set) var state: RecordingState = .stopped {
        didSet {
            audioRecorderDidChangeState(state)
        }
    }
    
    /// Indicates whether stereo recording is supported.
    private var isStereoSupported: Bool = false {
        didSet {
            try? setupAudioRecorder()
        }
    }
    
    /// The AVAudioRecorder instance for handling audio recording.
    private var recorder: AVAudioRecorder!
    
    /// The file name for the audio recording.
    private let recordingFileName = "recording.aac"
    
    /// The current time publisher subject for recording.
    private let recordingCurrentTimeSubject = PassthroughSubject<String, Never>()
    
    private let recordingPowerSubject = PassthroughSubject<[Float], Never>()
    
    private var avgPowers: [Float] = []
    
    /// A cancellable timer for managing recording time (not currently used).
    var timer: AnyCancellable?
    
    /// Publishes the current time for recording in the format: `mm:ss`.
    public var recordingCurrentTimePublisher: AnyPublisher<String, Never> {
        recordingCurrentTimeSubject.eraseToAnyPublisher()
    }
    
    public var recordingPowerPublisher: AnyPublisher<[Float], Never> {
        recordingPowerSubject.eraseToAnyPublisher()
    }
    
    /// The URL where the recording is stored.
    public var recordingURL: URL? {
        let url = FileManager.default.urlInDocumentsDirectory(named: recordingFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    public var isRecordPremissionGranted: Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    public func configureRecorder() throws {
        // Check if the user has granted permission for audio recording.
        guard isRecordPremissionGranted else {
            throw RecorderError.microphonePermissionRequired
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
    
    // MARK: - Audio Recorder Setup
    
    /// Sets up the audio recorder with the necessary configurations.
    private func setupAudioRecorder() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(recordingFileName)
        
        do {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVLinearPCMIsNonInterleaved: false,
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: isStereoSupported ? 2 : 1,
                AVLinearPCMBitDepthKey: 16,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]
            recorder = try AVAudioRecorder(url: fileURL, settings: audioSettings)
        } catch {
            throw RecorderError.unableToCreateAudioRecorder
        }
        
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
    }
    
    // MARK: - Recording Control
    
    
    /// Updates the audio input orientation and data source based on the specified parameters.
    ///
    /// - Parameters:
    ///   - orientation: The desired orientation of the audio input.
    ///   - interfaceOrientation: The current user interface orientation.
    /// - Throws: A `RecorderError` if unable to select the specified data source.
    public func updateOrientation(
        withDataSourceOrientation orientation: AVAudioSession.Orientation = .front,
        interfaceOrientation: UIInterfaceOrientation
    ) async throws {
        // Don't update the data source if the app is currently recording.
        guard state != .recording else { return }

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
            throw RecorderError.unableToSelectDataSource(name: newDataSource.dataSourceName)
        }
    }

    /// Initiates the audio recording process.
    public func record() {
        guard state != .recording else { return }
        
        // Update session configuration for recording.
        try? configurePlayAndRecordAudioSession()
        
        // Start the recording timer if not already initialized.
        startRecordingTimer()
        
        // Begin audio recording and update the state to recording.
        recorder.record()
        state = .recording
    }
    
    /// Initiates the audio recording process asynchronously.
    /// If not already recording, triggers a haptic vibration.
    public func record() async {
        // Do not initiate recording if the app is already recording.
        guard state != .recording else { return }
        
        // Update session configuration for recording.
        try? configurePlayAndRecordAudioSession()

        // If transitioning from a stopped state, provide a success feedback notification.
        if state == .stopped {
            await sendFeedbackNotification()
        }

        // Start the recording timer if not already initialized.
        if timer == nil {
            startRecordingTimer()
        }

        // Begin audio recording and update the state to recording.
        recorder.record()
        state = .recording
    }

    /// Pauses the audio recording process if currently recording.
    public func pauseRecording() {
        // Do not pause if the app is not currently recording.
        guard state == .recording else { return }

        // Pause the audio recorder and update the state to paused.
        recorder.pause()
        state = .paused
    }

    
    /// Stops the audio recording process.
    public func stopRecording() {
        recorder.stop()
        state = .stopped
        avgPowers = []
        stopTimer()
    }
    
    /// Deletes the current recording.
    public func deleteRecording() {
        // Stop audio recorder before deleting.
        stopRecording()
        
        // Delete recording.
        recorder.deleteRecording()
        
        // Post a notification to stop playback if it's playing.
        NotificationCenter.default.post(sckNotification: .soundControlKitRequiredToStopAllAudioPlayback)
    }
    
    func audioRecorderDidChangeState(_ state: RecordingState) {}
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder) {}
    
    // MARK: - Wave Controller
    
    @objc func updateAveragePower() {
        recorder.updateMeters()

        var avgPower: Float = 0.0

        if isStereoSupported {
            // Stereo recording, get power levels for both channels
            let powerChannel0 = recorder.averagePower(forChannel: 0)
            let powerChannel1 = recorder.averagePower(forChannel: 1)

            // Normalize and combine power levels
            avgPower = (powerChannel0 + powerChannel1) / 200.0 + 0.5
        } else {
            // Mono recording, get power level for channel 0
            let powerChannel0 = recorder.averagePower(forChannel: 0)

            // Normalize power level
            avgPower = (powerChannel0 + 50.0) / 100.0
        }

        // Update your wave view based on normalizedPower
        let value = round(avgPower * 10) / 10
        avgPowers.append(value)
        recordingPowerSubject.send(avgPowers)
    }


    
    // MARK: - Timer Methods
    
    /// Initiates a timer to track the duration of the audio recording.
    /// The timer publishes updates every 0.1 seconds on the main thread.
    /// When recording, the timer updates and sends the formatted duration to the `audioRecordingTimerPublisher`.
    private func startRecordingTimer() {
        timer = Timer
            .publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] timer in
                guard let self, self.state == .recording else { return }

                // Format the current recording duration and send it to the publisher.
                let timeInMinutesAndSeconds = self.formatTime(self.recorder.currentTime)
                self.recordingCurrentTimeSubject.send(timeInMinutesAndSeconds)
                self.updateAveragePower()
            }
    }

    /// Stops the recording timer.
    /// Cancels the timer subscription and releases the timer instance.
    func stopTimer() {
        // Cancel the timer subscription and release the timer instance.
        timer?.cancel()
        timer = nil
    }

    /// Formats the given duration in seconds into a string representing minutes and seconds.
    /// - Parameter duration: The duration in seconds.
    /// - Returns: A formatted string in the "MM:SS" (minutes:seconds) format.
    func formatTime(_ duration: TimeInterval) -> String {
        // Calculate minutes and seconds from the duration.
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        // Format the duration as "MM:SS" and return the result.
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Private Methods
    
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

// MARK: - AVAudioRecorderDelegate

extension SCKAudioRecorderManager: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Move the recorded audio file to the documents directory.
        let destURL = FileManager.default.urlInDocumentsDirectory(named: recordingFileName)
        try? FileManager.default.removeItem(at: destURL)
        try? FileManager.default.moveItem(at: recorder.url, to: destURL)
        recorder.prepareToRecord()
        avgPowers = []
        state = .stopped
        audioRecorderDidFinishRecording(recorder)
    }
}

extension SCKAudioRecorderManager {
    // MARK: - Error
    
    /// Errors specific to the `SCKAudioRecorderManager` class.
    public enum RecorderError: Error {
        /// An error indicating failure to create the audio recorder.
        case unableToCreateAudioRecorder
        /// An error indicating failure to select a specific data source for recording.
        case unableToSelectDataSource(name: String)
        /// An error indicating user has not a microphone permission
        case microphonePermissionRequired
    }
    
    // MARK: - Recording State
    
    /// Represents the possible states of audio recording.
    public enum RecordingState {
        case stopped
        case paused
        case recording
    }
}
