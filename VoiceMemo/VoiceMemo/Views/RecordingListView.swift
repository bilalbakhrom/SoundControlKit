//
//  RecordingListView.swift
//  SoundControlKitExample
//
//  Created by Bilal Bakhrom on 26/09/24.
//

import SwiftUI

struct RecordingListView: View {
    @EnvironmentObject private var soundManager: SoundManager

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(Array(soundManager.audioPlayers.enumerated()), id: \.element) { index, player in
                    VStack(spacing: .zero) {
                        PlayerView(player: player, index: index)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    soundManager.removeAudio(at: index)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                        if !isLastAudio(at: index) {
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func isLastAudio(at index: Int) -> Bool {
        index == soundManager.audioPlayers.count - 1
    }
}
