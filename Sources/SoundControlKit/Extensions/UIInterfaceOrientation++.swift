//
//  UIInterfaceOrientation++.swift
//
//
//  Created by Bilal Bakhrom on 2023-11-20.
//

import UIKit
import AVFoundation

extension UIInterfaceOrientation {
    var inputOrientation: AVAudioSession.StereoOrientation {
        return AVAudioSession.StereoOrientation(rawValue: rawValue)!
    }
}
