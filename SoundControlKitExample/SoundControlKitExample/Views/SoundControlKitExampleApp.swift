//
//  SoundControlKitExampleApp.swift
//  SoundControlKitExample
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import SwiftUI

@main
struct SoundControlKitExampleApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
                .environmentObject(SoundManager())
        }
    }
}
