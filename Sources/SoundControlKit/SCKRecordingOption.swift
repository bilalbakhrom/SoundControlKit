//
//  SCKRecordingOption.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import Foundation
import AVFoundation

/// Represents the options available for audio recording.
public struct SCKRecordingOption {
    /// The recording option, such as front stereo, back stereo, or mono.
    public let option: Option
    
    /// The orientation associated with the recording option.
    public let orientation: AVAudioSession.Orientation
    
    /// Enum representing the available recording options.
    public enum Option {
        case frontStereo
        case backStereo
        case mono
    }
}
