//
//  SCKAudioManager.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import Foundation
import AVFoundation
import Combine

/// Manager class responsible for handling audio recording and playback.
open class SCKAudioManager: SCKAudioRecorderManager, @unchecked Sendable {
    // MARK: - Properties
    
    /// Current state of audio playback.
    private(set) var playbackState: SCKPlaybackState = .stopped {
        didSet {
            handlePlaybackStateChange(playbackState)
        }
    }
    
    /// The AVAudioPlayer instance for handling audio playback.
    private var player: AVAudioPlayer?
    
    /// Current time publisher subject.
    private let placbackCurrentTimeSubject = PassthroughSubject<String, Never>()
    
    /// Remaining time publisher subject.
    private let playbackRemainingTimeSubject = PassthroughSubject<String, Never>()
    
    /// Progress publisher subject..
    private let playbackProgressSubject = PassthroughSubject<Double, Never>()
    
    /// Set of subscriptions.
    private var subscriptions: Set<AnyCancellable> = []
    
    /// The delegate to receive notifications about changes in recording and playback states.
    public weak var delegate: SCKAudioManagerDelegate?
    
    /// Publishes the current time for audio playback in the format: `mm:ss`.
    public var playbackCurrentTimePublisher: AnyPublisher<String, Never> {
        placbackCurrentTimeSubject.eraseToAnyPublisher()
    }
    
    /// Publishes the remaining time for audio playback in the format: `-mm:ss`.
    public var playbackRemainingTimePublisher: AnyPublisher<String, Never> {
        playbackRemainingTimeSubject.eraseToAnyPublisher()
    }
    
    /// Publishes the progress for audio playback in the range `0` to `1`.
    public var playbackProgressPublisher: AnyPublisher<Double, Never> {
        playbackProgressSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init(
        fileName: SCKRecordingFileNameOption = .dateWithTime,
        format: SCKOutputFormat = .aac,
        delegate: SCKAudioManagerDelegate? = nil
    ) {
        self.delegate = delegate
        super.init(fileName: fileName, format: format)

        bind()
        
        guard let recordingURL else { return }
        delegate?.audioManagerLastRecordingLocation(self, location: recordingURL)
        try? initializeAudioPlayer()
        
        guard let player else { return }
        let remainedDuration = formatRemainingTime(
            currentTime: player.currentTime,
            duration: player.duration
        )
        playbackRemainingTimeSubject.send(remainedDuration)
    }
    
    // MARK: - OVERRIDE
    
    public override func record() {
        // Stop audio player.
        stopPlayback()
        // Notify the delegate about the change in playback time.
        updatePlaybackTimeAttributes()
        // Start recording.
        super.record()
    }
    
    public override func record() async {
        // Stop audio player.
        stopPlayback()
        // Notify the delegate about the change in playback time.
        updatePlaybackTimeAttributes()
        // Start recording.
        await super.record()
    }
    
    // MARK: - Public Methods
    
    /// Initiates the playback of the recorded audio.
    public func play() {
        guard state != .recording else { return }
        
        try? configurePlaybackAudioSession()
        
        if player == nil {
            try? initializeAudioPlayer()
        }
        
        // Start tracking audio playback if not already started.
        if timer == nil {
            startTimerToTrackAudioPlayer()
        }
        
        // Start playback.
        player?.play()
        playbackState = .playing
    }
    
    /// Pauses the audio playback.
    public func pausePlayback() {
        player?.pause()
        playbackState = .paused
    }
    
    /// Stops the audio playback.
    public func stopPlayback() {
        stopTimer()
        player?.stop()
        player?.currentTime = .zero
        playbackState = .stopped
    }

    /// Forwards the audio playback by a specified number of seconds.
    /// - Parameter seconds: The number of seconds to forward the playback.
    public func forwardPlayback(by seconds: TimeInterval) {
        guard let player else { return }
        
        // Calculate the new time after forwarding by the specified number of seconds.
        let newTime = min(player.currentTime + seconds, player.duration)
        
        // Set the player's current time to the calculated new time.
        player.currentTime = newTime
        
        // Notify the delegate about the change in playback time.
        updatePlaybackTimeAttributes()
    }

    /// Rewinds the audio playback by a specified number of seconds.
    /// - Parameter seconds: The number of seconds to rewind the playback.
    public func rewindPlayback(by seconds: TimeInterval) {
        guard let player else { return }
        
        // Calculate the new time after rewinding by the specified number of seconds.
        let newTime = max(player.currentTime - seconds, 0)
        
        // Set the player's current time to the calculated new time.
        player.currentTime = newTime
        
        // Notify the delegate about the change in playback time.
        updatePlaybackTimeAttributes()
    }

    /// Stops the audio playback and resets it to the beginning.
    public func resetPlayback() {
        stopPlayback()
        
        // Setup audio player.
        try? initializeAudioPlayer()
        
        // Publish remaining time for current audio record.
        updatePlaybackTimeAttributes()
    }
    
    // MARK: - Overrides
    
    /// Notifies the delegate about changes in the audio recording state.
    override func audioRecorderDidChangeState(_ state: SCKRecordingState) {
        super.audioRecorderDidChangeState(state)
        delegate?.audioManagerDidChangeRecordingState(self, state: state)
    }
    
    /// Notifies the delegate that audio recording has finished.
    override func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder) {
        super.audioRecorderDidFinishRecording(recorder)
        
        guard let recordingURL else { return }
        delegate?.audioManagerDidFinishRecording(self, at: recordingURL)
        resetPlayback()
    }
    
    // MARK: - Private Methods
    
    /// Binds to notifications related to the SoundControlKit package, responding to the
    /// need to stop audio playback when a specific notification is received.
    private func bind() {
        // Subscribe to the notification indicating the requirement
        // to stop a specific audio playback.
        NotificationCenter.default
            .publisher(for: .soundControlKitRequiredToStopAudioPlayback)
            .sink { [weak self] notification in
                guard let self,
                      let url = notification.object as? URL,
                      let recordingURL, url == recordingURL
                else { return }
                
                // Stop playback if the received notification corresponds to the current recording URL.
                self.stopPlayback()
            }
            .store(in: &subscriptions)
        
        // Subscribe to the notification indicating the requirement
        // to stop all playback.
        NotificationCenter.default
            .publisher(for: .soundControlKitRequiredToStopAllAudioPlayback)
            .sink { [weak self] _ in
                self?.stopPlayback()
            }
            .store(in: &subscriptions)
    }
    
    /// Initializes the audio player with the recorded audio file.
    private func initializeAudioPlayer() throws {
        guard let url = recordingURL else { return }
        
        let session = AVAudioSession.sharedInstance()
        
        do {
            try? session.overrideOutputAudioPort(.speaker)
            player = try AVAudioPlayer(contentsOf: url)
            player?.isMeteringEnabled = true
            player?.delegate = self
            player?.prepareToPlay()
        } catch {
            throw SCKPlaybackError.unableToInitializeAudioPlayer
        }
    }
    
    /// Handles changes in the audio playback state and notifies the delegate.
    private func handlePlaybackStateChange(_ state: SCKPlaybackState) {
        delegate?.audioManagerDidChangePlaybackState(self, state: state)
    }
    
    /// Starts a timer to track the progress and duration of the audio playback.
    private func startTimerToTrackAudioPlayer() {
        timer = Timer
            .publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] timer in
                guard let self, self.playbackState == .playing else { return }
                updatePlaybackTimeAttributes()
            }
    }
    
    /// Updates time-related attributes for the current audio playback, such as progress, current time, and remaining time.
    private func updatePlaybackTimeAttributes() {
        guard let player else { return }
        
        // Calculate the playback progress.
        let progress = player.currentTime / player.duration
        
        // Format the current playback time.
        let currentTime = formatTime(player.currentTime)
        
        // Format the remaining time.
        let remainingTime = formatRemainingTime(currentTime: player.currentTime, duration: player.duration)
        
        // Send the updated attributes to their respective subjects.
        playbackProgressSubject.send(progress)
        placbackCurrentTimeSubject.send(currentTime)
        playbackRemainingTimeSubject.send(remainingTime)
    }

    
    /// Updates the remaining time of the audio playback and sends the formatted value to the `playbackRemainingTimeSubject`.
    ///
    /// - Note: This method calculates the remaining time by subtracting the current playback time from the total duration.
    private func updateRemainingTime() {
        guard let player else { return }
        
        // Calculate the remaining time and send it to the subject.
        let remainingTime = formatRemainingTime(
            currentTime: player.currentTime,
            duration: player.duration
        )
        playbackRemainingTimeSubject.send(remainingTime)
    }

    /// Formats the remaining time based on the provided current time and total duration.
    ///
    /// - Parameters:
    ///   - currentTime: The current playback time.
    ///   - duration: The total duration of the audio.
    /// - Returns: A formatted string representing the remaining time in the "MM:SS" format.
    private func formatRemainingTime(currentTime: TimeInterval, duration: TimeInterval) -> String {
        // Calculate the absolute difference in minutes and seconds between the current time and total duration.
        let minutes = abs((Int(currentTime) / 60) - (Int(duration) / 60))
        let seconds = abs((Int(currentTime) % 60) - (Int(duration) % 60))
        
        // Format the remaining time as "-MM:SS" and return the result.
        return String(format: "-%02d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioPlayerDelegate

extension SCKAudioManager: AVAudioPlayerDelegate {
    /// Notifies the delegate that audio playback has finished.
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playbackProgressSubject.send(1)
        
        // Reset playback to the beginning.
        playbackState = .stopped
        player.currentTime = 0
        player.prepareToPlay()
        
        // Reset player attributes.
        placbackCurrentTimeSubject.send("00:00")
        updateRemainingTime()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.playbackProgressSubject.send(0)
        }
                
        // Tell the delegate that audio player finished playing.
        delegate?.audioManagerDidFinishPlaying(self)
    }
}
