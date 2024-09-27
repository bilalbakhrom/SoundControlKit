//
//  SCKAudioRecorderError.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation

public enum SCKAudioRecorderError: Error {
    case engineStartFailure(Error)
    case audioSessionFailure(Error)

    public var localizedDescription: String {
        switch self {
        case .engineStartFailure(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .audioSessionFailure(let error):
            return "Audio session error occurred: \(error.localizedDescription)"
        }
    }
}
