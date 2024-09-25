//
//  SCKRecordingFileNameOption.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation

public enum SCKRecordingFileNameOption: Sendable {
    case date
    case dateWithTime
    case custom(String)

    /// Generates the actual file name string based on the selected option.
    var actualFileName: String {
        let dateFormatter = DateFormatter()

        switch self {
        case .date:
            dateFormatter.dateFormat = "yyyyMMdd"
            return dateFormatter.string(from: Date())

        case .dateWithTime:
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            return dateFormatter.string(from: Date())

        case .custom(let name):
            return name
        }
    }

    func fileName(format: SCKOutputFormat) -> String {
        "\(actualFileName).\(format.fileExtension)"
    }
}
