//
//  APLConverter.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 27/09/24.
//

import Foundation
import AVFoundation

/// Audio Power Level Converter
struct APLConverter {
    // Minimum dB value for scaling
    private static let minDb: Float = -80.0
    // Maximum dB value for scaling
    private static let maxDb: Float = 0.0
    // Minimum dB for normalization
    private static let normalizationMinDb: Float = -50.0

    /// Converts the provided audio buffer into an average power level in decibels.
    ///
    /// - Parameter buffer: The audio buffer containing PCM data.
    /// - Returns: The average power level as a `Float` value, scaled between 0.0 and 1.0.
    static func convertToAveragePower(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }

        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride
        ).map { channelDataValue[$0] }

        let rms = sqrt(channelDataValueArray.map { $0 * $0 }
            .reduce(0, +) / Float(buffer.frameLength))
        
        return scalePowerLevel(rms: rms)
    }

    /// Converts the current audio recorder meter levels to a normalized power level between 0 and 1.
    static func normalizedAveragePower(from recorder: AVAudioRecorder, isStereoSupported: Bool) -> Float {
        recorder.updateMeters()

        let avgPower: Float = isStereoSupported ?
        (recorder.averagePower(forChannel: 0) + recorder.averagePower(forChannel: 1)) / 2.0 :
        recorder.averagePower(forChannel: 0)

        return normalizePower(avgPower)
    }

    /// Scales the root mean square (RMS) value to a power level between 0.0 and 1.0.
    ///
    /// - Parameter rms: The root mean square value representing the intensity of the audio signal.
    /// - Returns: The scaled power level as a `Float`, between 0.0 (min) and 1.0 (max).
    private static func scalePowerLevel(rms: Float) -> Float {
        let power = rms > 0 ? 20 * log10(rms) : -Float.infinity

        guard power.isFinite else { return 0.0 }

        if power < minDb {
            return 0.0
        } else if power >= 0 {
            return 1.0
        } else {
            return (power - minDb) / (0 - minDb)
        }
    }

    /// Normalizes the power level to a range of 0 to 1
    private static func normalizePower(_ power: Float) -> Float {
        guard power < normalizationMinDb else { return 0.0 }
        guard power < maxDb else { return 1.0 }

        // Normalize the power level
        return (power - normalizationMinDb) / (maxDb - normalizationMinDb)
    }
}
