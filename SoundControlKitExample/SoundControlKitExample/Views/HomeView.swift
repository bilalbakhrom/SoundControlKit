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

    var body: some View {
        NavigationView {
            content
                .padding(.top, 16)
                .navigationTitle("All Recordings")
                .navigationBarTitleDisplayMode(.inline)
                .alert(isPresented: $soundManager.isPermissionAlertPresented) {
                    Alert(
                        title: Text("Microphone Access Required"),
                        message: Text("Please enable microphone access in Settings to use this feature."),
                        dismissButton: .cancel()
                    )
                }
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    soundManager.prepare()
                }
        }
    }

    private var content: some View {
        VStack(spacing: .zero) {
            RecordingListView()

            Spacer()

            RecordingControllerView()
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
