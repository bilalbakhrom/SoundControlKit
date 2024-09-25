//
//  SCKNotificationName.swift
//  
//
//  Created by Bilal Bakhrom on 2023-11-20.
//

import Foundation

public protocol SCKNotificationName {
    var name: Notification.Name { get }
}

extension SCKNotificationName where Self: RawRepresentable, RawValue == String {
    public var name: Notification.Name {
        get {
            Notification.Name(rawValue)
        }
    }
}
