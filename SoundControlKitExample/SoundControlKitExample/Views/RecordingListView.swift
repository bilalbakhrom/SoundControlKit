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
        List {
            ForEach(Array(soundManager.audioPlayers.enumerated()), id: \.element) { index, player in
                PlayerView(player: player, index: index)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            soundManager.removeAudio(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
}
