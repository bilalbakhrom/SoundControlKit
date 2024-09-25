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
}
