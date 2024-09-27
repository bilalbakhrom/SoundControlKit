//
//  LockIndex.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 27/09/24.
//

import Foundation

enum LockIndex {
    case recordingState, recordingEnd, recordingBuffer, avgPower, recordingTime

    var index: Int {
        switch self {
        case .recordingState: return 0
        case .recordingEnd: return 1
        case .recordingBuffer: return 2
        case .avgPower: return 3
        case .recordingTime: return 4
        }
    }
}
