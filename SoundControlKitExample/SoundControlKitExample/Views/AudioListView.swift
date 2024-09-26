//
//  AudioListView.swift
//  SoundControlKitExample
//
//  Created by Bilal Bakhrom on 26/09/24.
//

import SwiftUI

struct AudioListView: View {
    @ObservedObject var viewModel: AudioManagerViewModel

    init(viewModel: AudioManagerViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            ForEach(viewModel.audioURLs.indices, id: \.self) { index in
                buildPlayerView(for: index)
            }
        }
    }

    private func buildPlayerView(for index: Int) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(viewModel.audioURLs[index].lastPathComponent)
                    .font(.headline)

                if isPlaying(index) {
                    Text("Playing")
                } else {
                    Text("Paused")
                }

                Text("\(formattedTime(viewModel.currentAudioTime)) / \(formattedTime(viewModel.totalAudioDuration))")
                    .font(.subheadline)
            }

            Spacer()

            HStack(spacing: 20) {
                Button {
                    viewModel.playAudio(at: index)
                } label: {
                    Image(systemName: isPlaying(index) ? "stop.circle" : "play.circle")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.blue)
                }

                Button {
                    viewModel.removeAudio(at: index)
                } label: {
                    Image(systemName: "trash")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
    }

    private func isPlaying(_ index: Int) -> Bool {
        viewModel.currentlyPlayingIndex == index && viewModel.isPlaying
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
