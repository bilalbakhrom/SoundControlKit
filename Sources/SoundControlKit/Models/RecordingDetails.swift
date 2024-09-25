//
//  RecordingDetails.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation

struct RecordingDetails {
    private let initialFileName: String
    let option: SCKRecordingFileNameOption
    let format: SCKOutputFormat

    var fileName: String {
        option.fileName(format: format)
    }

    var fileNameForRealTime: String {
        "\(initialFileName).\(format.fileExtension)"
    }

    init(
        option: SCKRecordingFileNameOption,
        format: SCKOutputFormat
    ) {
        self.option = option
        self.format = format
        self.initialFileName = option.fileName(format: format)
    }
}
