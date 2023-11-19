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
                                            .frame(height: power == 0 ? 1.5 : power * 52)
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
            .padding(.top, 16)
            .navigationTitle("All Recordings")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(viewModel.audioManager.recordingCurrentTimePublisher) { timeInMiniutesAndSeconds in
                recordingCurrentTime = timeInMiniutesAndSeconds
            }
            .onReceive(viewModel.audioManager.playbackProgressPublisher) { progress in
                playbackProgress = progress
            }
            .onReceive(viewModel.audioManager.playbackCurrentTimePublisher) { duration in
                playbackCurrentTime = duration
            }
            .onReceive(viewModel.audioManager.playbackRemainingTimePublisher) { duration in
                playbackRemainingTime = duration
            }
            .onReceive(viewModel.audioManager.recordingPowerPublisher) { avgPowers in
                withAnimation(.linear(duration: 0.1)) {
                    viewModel.avgPowers = Array(avgPowers.reversed())
                }
            }
            .onAppear {
                viewModel.prepare()
            }
        }
    }
}

#Preview {
    AudioManagerView()
        .preferredColorScheme(.dark)
}
