//
//  SCKAudioSessionManager.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import Foundation
import AVFoundation

/// Manages audio sessions and provides functionality for configuration and microphone selection.
open class SCKAudioSessionManager: NSObject {    
    /// Configures the audio session for recording and playback.
    ///
    /// - Throws: An `AudioSessionError` if the configuration fails.
    public func configurePlayAndRecordAudioSession() throws {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Set the audio session category to play and record, allowing default to speaker and Bluetooth.
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )

            // Activate the audio session.
            try audioSession.setActive(true)
        } catch {
            // If an error occurs during configuration, throw an appropriate error.
            throw AudioSessionError.configurationFailed
        }
    }
    
    /// Configures the audio session for playing recorded music or other sounds
    ///
    /// - Throws: An `AudioSessionError` if the configuration fails.
    public func configurePlaybackAudioSession() throws {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Set the audio session category to playback.
            try audioSession.setCategory(.playback, mode: .default)
            
            // Activate the audio session.
            try audioSession.setActive(true)
        } catch {
            throw AudioSessionError.configurationFailed
        }
    }
    
    /// Sets the built-in microphone as the preferred input.
    ///
    /// - Note: You must set a preferred input port only after setting 
    /// the audio session’s category and mode and activating the session.
    ///
    /// - Throws: An `AudioSessionError` if the device does not have 
    /// a built-in microphone or if setting the built-in microphone as the preferred 
    /// input fails.
    public func enableBuiltInMicrophone() throws {
        let audioSession = AVAudioSession.sharedInstance()
        let availableInputs = audioSession.availableInputs
        
        // Find the available input that corresponds to the built-in microphone.
        guard let builtInMicInput = availableInputs?.first(where: { $0.portType == .builtInMic }) else {
            // If no built-in microphone is found, throw an error.
            throw AudioSessionError.missingBuiltInMicrophone
        }
        
        do {
            // Set the built-in microphone as the preferred input.
            try audioSession.setPreferredInput(builtInMicInput)
        } catch {
            // If an error occurs while setting the preferred input, throw an appropriate error.
            throw AudioSessionError.unableToSetBuiltInMicrophone
        }
    }
}

extension SCKAudioSessionManager {
    /// Errors specific to the `SCKAudioSessionManager` class.
    public enum AudioSessionError: Error {
        /// An error indicating failure in configuring the audio session.
        case configurationFailed
        
        /// An error indicating that the device must have a built-in microphone for the operation.
        case missingBuiltInMicrophone
        
        /// An error indicating failure to set the built-in microphone as the preferred input.
        case unableToSetBuiltInMicrophone
    }
}
