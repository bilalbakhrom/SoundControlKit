//
//  SCKNotification.swift
//
//
//  Created by Bilal Bakhrom on 2023-11-20.
//

import Foundation

public typealias NotificationOutput = NotificationCenter.Publisher.Output
public typealias NotificationCompletion = (NotificationOutput) -> Void

public enum SCKNotification: String, SCKNotificationName {
    case soundControlKitRequiredToStopAudioPlayback
    case soundControlKitRequiredToStopAllAudioPlayback
    
    public var key: String {
        self.rawValue
    }
}

