//
//  VoiceMemo.swift
//  SoundControlKitExample
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import SwiftUI

@main
struct VoiceMemo: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
                .environmentObject(SoundManager())
        }
    }
}
