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
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(player.name)
                        .font(.body)

                    if let date = player.date {
                        Text(date)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                Text(player.totalTime)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            VStack(spacing: 20) {
                progressView

                controllerView
            }
            .padding(.vertical, 20)
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
    }

    private var progressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: player.progress)
                .progressViewStyle(.linear)
                .tint(Color.white)

            HStack(spacing: .zero) {
                Text(player.currentTime)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                Text(player.remainingTime)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var controllerView: some View {
        HStack(spacing: 30) {
            Spacer()

            Button {
                player.rewindPlayback(by: 5)
            } label: {
                Image(systemName: "gobackward.5")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
            }
            .frame(width: 24, height: 24)

            playerButton

            Button {
                player.forwardPlayback(by: 5)
            } label: {
                Image(systemName: "goforward.5")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
            }
            .frame(width: 24, height: 24)

            Spacer()
        }
    }

    private var playerButton: some View {
        Button {
            if !player.isPlaying {
                NotificationCenter.default.post(sckNotification: .stopAllAudioPlayback)
            }

            player.isPlaying ? player.pausePlayback() : player.play()
        } label: {
            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(.blue)
        }
        .frame(width: 30, height: 30)
        .background(Color.white)
        .clipShape(.circle)
        .buttonStyle(.plain)
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
