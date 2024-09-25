//
//  RecordingDetails.swift
//  SoundControlKit
//
//  Created by Bilal Bakhrom on 25/09/24.
//

import Foundation

struct RecordingDetails {
    let option: SCKRecordingFileNameOption
    let format: SCKOutputFormat

    var fileName: String {
        option.fileName(format: format)
    }

    init(
        option: SCKRecordingFileNameOption,
        format: SCKOutputFormat
    ) {
        self.option = option
        self.format = format
    }
}
