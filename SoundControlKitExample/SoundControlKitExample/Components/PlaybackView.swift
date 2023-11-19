//
//  PlaybackView.swift
//  AudioRecorder
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import SwiftUI

struct PlaybackView: View {
    @Binding var audioURL: URL?
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    @Binding var currentTime: String
    @Binding var remainedTime: String
    var action: () -> Void
    var onForward: () -> Void
    var onRewind: () -> Void
    var onTrash: () -> Void
    
    private var date: String? {
        guard let audioURL,
              let values = try? audioURL.resourceValues(forKeys: [.creationDateKey]),
              let creationDate = values.creationDate
        else {
            return nil
        }
        
        // Create a DateFormatter instance.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        
        return dateFormatter.string(from: creationDate)
    }
    
    var body: some View {
        ZStack {
            if let audioURL {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(audioURL.lastPathComponent)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            if let date {
                                Text(date)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                        
                        HStack(spacing: .zero) {
                            Text(currentTime)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                            
                            Text(remainedTime)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    HStack(spacing: 30) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 24, height: 24)
                        
                        Spacer()
                        
                        Button {
                            onRewind()
                        } label: {
                            Image(systemName: "gobackward.5")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        }
                        .frame(width: 24, height: 24)
                        
                        PlayerButton(isPlaying: $isPlaying) {
                            action()
                        }
                        
                        Button {
                            onForward()
                        } label: {
                            Image(systemName: "goforward.5")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        }
                        .frame(width: 24, height: 24)
                        
                        Spacer()
                        
                        Button {
                            onTrash()
                        } label: {
                            Image(systemName: "trash")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.accentColor)
                        }
                        .frame(width: 24, height: 24)
                    }
                }
            }
        }
    }
}
