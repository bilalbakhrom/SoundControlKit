//
//  SCKAudioRecorderManager.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import Foundation
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
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        do {
            // Configure the audio session, enable the built-in microphone, and set up the audio recorder.
            try configureAudioSession()
            try enableBuiltInMicrophone()
            try setupAudioRecorder()
        } catch {
            // If any errors occur during initialization, terminate the app with a fatalError.
            fatalError("Error: \(error)")
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
    
    /// Updates the recording option and stereo orientation for the audio session.
    /// - Parameters:
    ///   - option: The selected recording option.
    ///   - stereoOrientation: The desired stereo orientation.
    public func updateRecordingOption(_ option: SCKRecordingOption, stereoOrientation: AVAudioSession.StereoOrientation) async throws {
        // Don't update the data source if the app is currently recording.
        guard state != .recording else { return }
        
        // Get the shared audio session.
        let session = AVAudioSession.sharedInstance()
        
        guard let preferredInput = session.preferredInput,
              let dataSources = preferredInput.dataSources,
              let newDataSource = dataSources.first(where: { $0.orientation == option.orientation }),
              let supportedPolarPatterns = newDataSource.supportedPolarPatterns else {
            return
        }
        
        do {
            if #available(iOS 14.0, *) {
                isStereoSupported = supportedPolarPatterns.contains(.stereo)
                
                if isStereoSupported {
                    try newDataSource.setPreferredPolarPattern(.stereo)
                }
            }
            
            try preferredInput.setPreferredDataSource(newDataSource)
            
            if #available(iOS 14.0, *) {
                try session.setPreferredInputOrientation(stereoOrientation)
            }
        } catch {
            throw RecorderError.unableToSelectDataSource(name: newDataSource.dataSourceName)
        }
    }
    
    /// Initiates the audio recording process.
    public func record() {
        guard state != .recording else { return }
        
        if timer == nil {
            startRecordingTimer()
        }
        
        recorder.record()
        state = .recording
    }
    
    /// Stops the audio recording process.
    public func stop() {
        recorder.stop()
        state = .stopped
        avgPowers = []
        stopTimer()
    }
    
    /// Deletes the current recording.
    public func deleteRecording() {
        stop()
        recorder.deleteRecording()
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
    }
    
    // MARK: - Recording State
    
    /// Represents the possible states of audio recording.
    public enum RecordingState {
        case stopped
        case recording
    }
}
