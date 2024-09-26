//
//  HomeView.swift
//  AudioRecorder
//
//  Created by Bilal Bakhrom on 2023-11-18.
//

import SwiftUI
import AVFoundation

struct HomeView: View {
    @EnvironmentObject private var soundManager: SoundManager

    @State private var playbackProgress: Double = 0
    @State private var playbackCurrentTime: String = "00:00"
    @State private var playbackRemainingTime: String = "-00:00"

    var body: some View {
        NavigationView {
            content
                .padding(.top, 16)
                .navigationTitle("All Recordings")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    soundManager.prepare()
                }
                .alert(isPresented: $soundManager.isPermissionAlertPresented) {
                    Alert(
                        title: Text("Microphone Access Required"),
                        message: Text("Please enable microphone access in Settings to use this feature."),
                        dismissButton: .cancel()
                    )
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var content: some View {
        VStack(spacing: .zero) {
            RecordingListView()

            Spacer()

            meterLevelsView
        }
    }

    private var meterLevelsView: some View {
        VStack(spacing: 40) {
            if soundManager.isRecording {
                VStack(spacing: 20) {
                    Indicator()

                    Text(soundManager.recordingCurrentTime)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .padding(.top, 16)

                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(0..<soundManager.avgPowers.count, id: \.self) { index in
                            let power = CGFloat(soundManager.avgPowers[index])
                            ZStack {
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: 1.5)
                                    .frame(height: power * 35)
                            }
                            .frame(height: 52)
                        }
                    }
                }
                .rotationEffect(.degrees(180))
                .frame(height: 52)
                .opacity(soundManager.isRecording ? 1 : 0)
            }

            RecorderButton(isRecording: $soundManager.isRecording) {
                soundManager.recordAndStop()
            }
            .padding(.top, soundManager.isRecording ? 0 : 40)
        }
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1))
        .cornerRadius(soundManager.isRecording ? 12 : 0, corners: [.topLeft, .topRight])
        .animation(.easeInOut, value: soundManager.isRecording)
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
