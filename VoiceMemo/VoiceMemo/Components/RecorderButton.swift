//
//  RecorderButton.swift
//  AudioRecorder
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import SwiftUI

struct RecorderButton: View {
    @Binding var isRecording: Bool
    var action: () -> Void
    
    private var itemSize: CGFloat {
        isRecording ? 30 : 45
    }
    
    private var cornerRadius: CGFloat {
        isRecording ? 4 : 24
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: itemSize, height: itemSize)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .frame(width: 60, height: 60)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .strokeBorder(Color.white, lineWidth: 3)
            )
        }
        .buttonStyle(CustomButtonStyle())
        .animation(.easeOut, value: isRecording)
    }
    
    fileprivate struct CustomButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
        }
    }
}
