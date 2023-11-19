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
    /// An array of available recording options based on the preferred input's data sources.
    public let recordingOptions: [SCKRecordingOption] = {
        let orientations: [AVAudioSession.Orientation] = [.front, .back, .bottom]
        let session = AVAudioSession.sharedInstance()
        
        // Retrieve data sources from the preferred input.
        guard let dataSources = session.preferredInput?.dataSources else { return [] }
        
        // Map data sources to recording options based on orientation.
        return dataSources.compactMap {
            switch $0.orientation {
            case AVAudioSession.Orientation.front:
                return SCKRecordingOption(option: .frontStereo, orientation: .front)
            case AVAudioSession.Orientation.back:
                return SCKRecordingOption(option: .backStereo, orientation: .back)
            case AVAudioSession.Orientation.bottom:
                return SCKRecordingOption(option: .mono, orientation: .bottom)
            default:
                return nil
            }
        }
    }()
    
    /// Configures the audio session for recording and playback.
    ///
    /// - Throws: An `AudioSessionError` if the configuration fails.
    public func configureAudioSession() throws {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Set the audio session category to play and record, allowing default to speaker and Bluetooth.
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            
            // Activate the audio session.
            try audioSession.setActive(true)
        } catch {
            // If an error occurs during configuration, throw an appropriate error.
            throw AudioSessionError.configurationFailed
        }
    }
    
    /// Sets the built-in microphone as the preferred input.
    ///
    /// - Note: You must set a preferred input port only after setting the audio session’s category and mode and activating the session.
    ///
    /// - Throws: An `AudioSessionError` if the device does not have a built-in microphone or if setting the built-in microphone as the preferred input fails.
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
