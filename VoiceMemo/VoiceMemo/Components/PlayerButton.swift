//
//  PlayerButton.swift
//  AudioRecorder
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import SwiftUI

struct PlayerButton: View {
    @Binding var isPlaying: Bool
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .resizable()
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
        }
        .frame(width: 20, height: 20)
        .buttonStyle(CustomButtonStyle())
        .animation(.easeOut, value: isPlaying)
    }
    
    fileprivate struct CustomButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
        }
    }
}

