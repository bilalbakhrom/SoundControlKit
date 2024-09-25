//
//  AudioManagerView.swift
//  AudioRecorder
//
//  Created by Bilal Bakhrom on 2023-11-18.
//

import SwiftUI
import AVFoundation

struct AudioManagerView: View {
    @StateObject private var viewModel = AudioManagerViewModel()

    @State private var recordingCurrentTime: String = "00:00"
    @State private var playbackProgress: Double = 0
    @State private var playbackCurrentTime: String = "00:00"
    @State private var playbackRemainingTime: String = "-00:00"

    var body: some View {
        NavigationView {
            if let realTimeRecorder = viewModel.realTimeRecorder {
                contentWithPublishers
                    .onReceive(realTimeRecorder.recordingCurrentTimePublisher) { timeInMiniutesAndSeconds in
                        recordingCurrentTime = timeInMiniutesAndSeconds
                    }
                    .onReceive(realTimeRecorder.recordingPowerPublisher) { avgPowers in
                        withAnimation(.linear(duration: 0.1)) {
                            viewModel.avgPowers = Array(avgPowers.reversed())
                        }
                    }
            } else {
                contentWithPublishers
            }
        }
    }

    private var contentWithPublishers: some View {
        content
            .padding(.top, 16)
            .navigationTitle("All Recordings")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(viewModel.audioManager.playbackProgressPublisher) { progress in
                playbackProgress = progress
            }
            .onReceive(viewModel.audioManager.playbackCurrentTimePublisher) { duration in
                playbackCurrentTime = duration
            }
            .onReceive(viewModel.audioManager.playbackRemainingTimePublisher) { duration in
                playbackRemainingTime = duration
            }
            .onAppear {
                viewModel.prepare()
            }
            .alert(isPresented: $viewModel.isPermissionAlertPresented) {
                Alert(
                    title: Text("Microphone Access Required"),
                    message: Text("Please enable microphone access in Settings to use this feature."),
                    dismissButton: .cancel()
                )
            }
    }

    private var content: some View {
        VStack(spacing: .zero) {
            PlaybackView(
                audioURL: $viewModel.recordingURL,
                isPlaying: $viewModel.isPlaying,
                progress: $playbackProgress,
                currentTime: $playbackCurrentTime,
                remainedTime: $playbackRemainingTime,
                action: { viewModel.playAndStop() },
                onForward: { viewModel.forwardPlayback() },
                onRewind: { viewModel.rewindPlayback() },
                onTrash: { viewModel.deleteRecording() }
            )
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                if viewModel.isRecording {
                    Text(recordingCurrentTime)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(0..<viewModel.avgPowers.count, id: \.self) { index in
                                let power = CGFloat(viewModel.avgPowers[index])
                                ZStack {
                                    Rectangle()
                                        .fill(Color.red)
                                        .frame(width: 1.5)
                                        .frame(height: power == 0 ? 1.5 : power * 10)
                                }
                                .frame(height: 52)
                            }
                        }
                    }
                    .rotationEffect(.degrees(180))
                    .frame(height: 52)
                    .opacity(viewModel.isRecording ? 1 : 0)
                }

                RecorderButton(isRecording: $viewModel.isRecording) {
                    viewModel.recordAndStop()
                }
            }
            .padding(.bottom, 30)
            .animation(.easeInOut, value: viewModel.isRecording)
        }
    }
}

#Preview {
    AudioManagerView()
        .preferredColorScheme(.dark)
}

/// Method to show an alert if the user hasn't granted microphone permission
func showMicrophonePermissionAlert(on viewController: UIViewController) {
    let alertController = UIAlertController(
        title: "Microphone Access Required",
        message: "Please enable microphone access in Settings to use this feature.",
        preferredStyle: .alert
    )

    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

    alertController.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }
    }))

    DispatchQueue.main.async {
        viewController.present(alertController, animated: true)
    }
}
