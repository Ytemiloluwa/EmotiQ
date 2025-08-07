//
//  AudioVisualingView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 07-08-2025.
//
import SwiftUI
import Foundation

struct AudioVisualizationView: View {
    let audioLevel: Float
    let isRecording: Bool
    
    private let barCount = 20
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4)
                    .frame(height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 80
        
        if !isRecording {
            return baseHeight
        }
        
        // Create a wave pattern based on audio level
        let normalizedIndex = Float(index) / Float(barCount - 1)
        let waveOffset = sin(normalizedIndex * .pi * 2) * 0.3
        let adjustedLevel = max(0, audioLevel + waveOffset)
        
        return baseHeight + (maxHeight - baseHeight) * CGFloat(adjustedLevel)
    }
    
    private func barColor(for index: Int) -> Color {
        let normalizedIndex = Float(index) / Float(barCount - 1)
        let threshold = audioLevel * 0.8
        
        if normalizedIndex <= threshold {
            return .white
        } else {
            return .white.opacity(0.3)
        }
    }
}

