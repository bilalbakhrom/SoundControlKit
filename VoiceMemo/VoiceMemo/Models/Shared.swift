//
//  Shared.swift
//  SoundControlKitExample
//
//  Created by Bilal Bakhrom on 26/09/24.
//

import UIKit

/// Method to show an alert if the user hasn't granted microphone permission
func showMicrophonePermissionAlert(on viewController: UIViewController) {
    let alertController = UIAlertController(
        title: "Microphone Access Required",
        message: "Please enable microphone access in Settings to use this feature.",
        preferredStyle: .alert
    )

    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

    alertController.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }
    }))

    DispatchQueue.main.async {
        viewController.present(alertController, animated: true)
    }
}
