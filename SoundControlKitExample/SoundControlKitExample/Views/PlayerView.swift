//
//  PlayerView.swift
//  SoundControlKitExample
//
//  Created by Bilal Bakhrom on 26/09/24.
//

import SwiftUI
import SoundControlKit

struct PlayerView: View {
    @ObservedObject var player: SCKAudioPlayer
    @EnvironmentObject private var soundManager: SoundManager
    private let index: Int

    init(player: SCKAudioPlayer, index: Int) {
        self.player = player
        self.index = index
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(player.name)
                    .font(.headline)

                if let date = player.date {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Text("\(player.currentTime) / \(player.totalTime)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button {
                NotificationCenter.default.post(sckNotification: .stopAllAudioPlayback)
                player.isPlaying ? player.stop() : player.play()
            } label: {
                Image(systemName: player.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
