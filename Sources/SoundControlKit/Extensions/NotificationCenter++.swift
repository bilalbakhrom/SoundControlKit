//
//  NotificationCenter++.swift
//
//
//  Created by Bilal Bakhrom on 2023-11-20.
//

import SwiftUI

extension NotificationCenter {
    public func post(sckNotification notification: SCKNotification, object anObject: Any? = nil) {
        self.post(name: notification.name, object: anObject)
    }
    
    public func publisher(for aName: SCKNotification) -> Publisher {
        self.publisher(for: aName.name)
    }
}

extension View {
    public func onReceive(_ notification: SCKNotification, perform action: @escaping NotificationCompletion) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: notification)) { output in
            action(output)
        }
    }
}
