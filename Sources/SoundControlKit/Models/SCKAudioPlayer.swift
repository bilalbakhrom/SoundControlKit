//
//  SCKAudioPlayer.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 26/09/24.
//

import Foundation
import AVFoundation
import Combine

final public class SCKAudioPlayer: NSObject, ObservableObject {
    public let audioURL: URL

    @Published public var currentTime: String = "00:00"
    @Published public var remainingTime: String = "00:00"
    @Published public var progress: Double = 0.0
    @Published public private(set) var playbackState: SCKPlaybackState = .stopped
    @Published public private(set) var parameters: [String: Any] = [:]

    private var player: AVAudioPlayer?
    private var subscriptions: Set<AnyCancellable> = []
    private var timer: AnyCancellable?

    public var name: String {
        audioURL.lastPathComponent
    }

    public var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    public var date: String? {
        guard let values = try? audioURL.resourceValues(forKeys: [.creationDateKey]),
              let creationDate = values.creationDate
        else { return nil }

        return Self.dateFormatter.string(from: creationDate)
    }

    public var totalTime: String {
        guard let duration = player?.duration else { return "00:00" }
        return formatTime(duration)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    public init(audioURL: URL) {
        self.audioURL = audioURL
        super.init()
        bind()
    }

    public func configure() throws {
        guard player == nil else { return }

        // Configure audio player.
        player = try AVAudioPlayer(contentsOf: audioURL)
        player?.isMeteringEnabled = true
        player?.delegate = self
        player?.prepareToPlay()
    }

    public func setParameter(forKey key: String, value: Any) {
        parameters[key] = value
    }

    public func getParameter(forKey key: String) -> Any {
        parameters[key]
    }

    /// Starts a timer to track the progress and duration of the audio playback.
    private func startTimer() {
        timer = Timer
            .publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timer in
                guard let self, playbackState == .playing else { return }
                updatePlaybackTimeAttributes()
            }
    }

    /// Stops the recording timer.
    /// Cancels the timer subscription and releases the timer instance.
    private func stopTimer() {
        // Cancel the timer subscription and release the timer instance.
        timer?.cancel()
        timer = nil
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

        self.progress = progress
        self.currentTime = currentTime
        self.remainingTime = remainingTime
    }

    /// Updates the remaining time of the audio playback and sends the formatted value to the `playbackRemainingTimeSubject`.
    ///
    /// - Note: This method calculates the remaining time by subtracting the current playback time from the total duration.
    private func updateRemainingTime() {
        guard let player else { return }

        let remainingTime = formatRemainingTime(
            currentTime: player.currentTime,
            duration: player.duration
        )
        self.remainingTime = remainingTime
    }
}

// MARK: - Control

extension SCKAudioPlayer {
    /// Plays audio asynchronously.
    public func play() {
        guard playbackState != .playing else { return }

        // Start tracking audio playback if not already started.
        if timer == nil {
            startTimer()
        }

        // Start playback.
        player?.play()
        playbackState = .playing
    }

    /// Pauses the audio playback.
    public func pause() {
        player?.pause()
        playbackState = .paused
    }

    /// Stops the audio playback.
    public func stop() {
        stopTimer()
        player?.stop()
        player?.currentTime = .zero
        playbackState = .stopped
        progress = 0
        currentTime = "00:00"
        updateRemainingTime()
    }

    /// Forwards the audio playback by a specified number of seconds.
    ///
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
    ///
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
        stop()
        // Publish remaining time for current audio record.
        updatePlaybackTimeAttributes()
    }
}

extension SCKAudioPlayer: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }
}

// MARK: - Listeners

extension SCKAudioPlayer {
    /// Binds to notifications related to the SoundControlKit package, responding to the
    /// need to stop audio playback when a specific notification is received.
    private func bind() {
        // Subscribe to the notification indicating the requirement
        // to stop a specific audio playback.
        NotificationCenter.default
            .publisher(for: .stopAudioPlayback)
            .sink { [weak self] notification in
                guard let self,
                      let url = notification.object as? URL,
                      url == audioURL
                else { return }

                // Stop playback if the received notification corresponds to the current recording URL.
                self.stop()
            }
            .store(in: &subscriptions)

        // Subscribe to the notification indicating the requirement
        // to stop all playback.
        NotificationCenter.default
            .publisher(for: .stopAllAudioPlayback)
            .sink { [weak self] _ in
                self?.stop()
            }
            .store(in: &subscriptions)
    }
}

// MARK: - Helper Methods

extension SCKAudioPlayer {
    /// Formats the given duration in seconds into a string representing minutes and seconds.
    ///
    /// - Parameter duration: The duration in seconds.
    /// - Returns: A formatted string in the "MM:SS" (minutes:seconds) format.
    func formatTime(_ duration: TimeInterval) -> String {
        // Calculate minutes and seconds from the duration.
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        // Format the duration as "MM:SS" and return the result.
        return String(format: "%02d:%02d", minutes, seconds)
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
