//
//  SCKAudioPlayer++.swift
//  SoundControlKitExample
//
//  Created by Bilal Bakhrom on 27/09/24.
//

import Foundation
import SoundControlKit

extension SCKAudioPlayer {
    var isExpanded: Bool {
        (getParameter(forKey: "player_view_expanded") as? Bool) ?? false
    }

    func setExpanded(_ expanded: Bool) {
        setParameter(forKey: "player_view_expanded", value: expanded)
    }
}

extension Array where Element == SCKAudioPlayer {
    func closeAll() { self.forEach { $0.setExpanded(false) }}
}
