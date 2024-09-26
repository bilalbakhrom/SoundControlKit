//
//  PlayerView.swift
//  SoundControlKitExample
//
//  Created by Bilal Bakhrom on 26/09/24.
//

import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var soundManager: SoundManager
    let audioURL: URL
    let index: Int

    private var isPlaying: Bool {
        soundManager.currentlyPlayingIndex == index && soundManager.isPlaying
    }

    private var date: String? {
        guard let values = try? audioURL.resourceValues(forKeys: [.creationDateKey]),
              let creationDate = values.creationDate
        else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yyyy"
        return dateFormatter.string(from: creationDate)
    }

    init(audioURL: URL, index: Int) {
        self.audioURL = audioURL
        self.index = index
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                // Recording file name
                Text(audioURL.lastPathComponent)
                    .font(.headline)

                if let date {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                // Time info (elapsed time / total time)
                Text("\(formattedTime(soundManager.currentAudioTime)) / \(formattedTime(soundManager.totalAudioDuration))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Play/Pause button
            Button(action: {
                // Check if index is still valid before playing audio
                if index < soundManager.audioURLs.count {
                    soundManager.playAudio(at: index)
                }
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())  // Ensures tap area is large
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
