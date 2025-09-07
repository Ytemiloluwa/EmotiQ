//
//  AudioVisualingView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 07-08-2025.
//
import SwiftUI

// MARK: - Audio Level Visualization
struct AudioLevelVisualization: View {
    
    // MARK: - Properties
    let audioLevels: [Float]
    let isRecording: Bool
    
    // MARK: - Configuration
    private let numberOfBars = 20
    private let barSpacing: CGFloat = 3
    private let minBarHeight: CGFloat = 4
    private let maxBarHeight: CGFloat = 60
    private let animationDuration: Double = 0.1
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<numberOfBars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barGradient(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeInOut(duration: animationDuration), value: audioLevels)
            }
        }
        .frame(height: maxBarHeight)
    }
    //}
    
    // MARK: - Private Methods
    
    private func barHeight(for index: Int) -> CGFloat {
        guard index < audioLevels.count else {
            return minBarHeight
        }
        let level = audioLevels[index]
        let normalizedLevel = CGFloat(level)
        let height = minBarHeight + (maxBarHeight - minBarHeight) * normalizedLevel
        let finalHeight = max(minBarHeight, height)
        
        return finalHeight
    }
    
    private func barGradient(for index: Int) -> LinearGradient {
        guard index < audioLevels.count else {
            return LinearGradient(
                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        let level = audioLevels[index]
        let intensity = Double(level)
        
        if !isRecording {
            return LinearGradient(
                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        
        // Dynamic color based on intensity
        let baseColor: Color
        if intensity > 0.7 {
            baseColor = .red
        } else if intensity > 0.4 {
            baseColor = .orange
        } else if intensity > 0.2 {
            baseColor = .yellow
        } else {
            baseColor = .green
        }
        
        return LinearGradient(
            colors: [
                baseColor.opacity(0.8),
                baseColor.opacity(0.4),
                baseColor.opacity(0.1)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

// MARK: - Circular Audio Level Indicator
struct CircularAudioLevelIndicator: View {
    
    // MARK: - Properties
    let audioLevel: Float
    let isRecording: Bool
    
    // MARK: - Configuration
    private let numberOfRings = 5
    private let maxRadius: CGFloat = 60
    private let minRadius: CGFloat = 20
    
    // MARK: - State
    @State private var animatedLevel: Float = 0
    
    var body: some View {
        ZStack {
            // Background circles
            ForEach(0..<numberOfRings, id: \.self) { ring in
                Circle()
                    .stroke(
                        Color.gray.opacity(0.2),
                        lineWidth: 2
                    )
                    .frame(width: ringRadius(for: ring) * 2, height: ringRadius(for: ring) * 2)
            }
            
            // Active level circles
            ForEach(0..<numberOfRings, id: \.self) { ring in
                Circle()
                    .stroke(
                        ringColor(for: ring),
                        lineWidth: ringLineWidth(for: ring)
                    )
                    .frame(width: ringRadius(for: ring) * 2, height: ringRadius(for: ring) * 2)
                    .opacity(ringOpacity(for: ring))
                    .scaleEffect(ringScale(for: ring))
                    .animation(.easeInOut(duration: 0.1), value: animatedLevel)
            }
            
            // Center microphone icon
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.title2)
                .foregroundColor(isRecording ? .red : .gray)
                .scaleEffect(isRecording ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isRecording)
        }
        .onChange(of: audioLevel) { _, newLevel in
            updateLevel(newLevel)
        }
    }
    
    // MARK: - Private Methods
    
    private func ringRadius(for ring: Int) -> CGFloat {
        let step = (maxRadius - minRadius) / CGFloat(numberOfRings - 1)
        return minRadius + CGFloat(ring) * step
    }
    
    private func ringColor(for ring: Int) -> Color {
        let intensity = Double(animatedLevel)
        let ringThreshold = Double(ring) / Double(numberOfRings - 1)
        
        if intensity > ringThreshold {
            if intensity > 0.8 {
                return .red
            } else if intensity > 0.6 {
                return .orange
            } else if intensity > 0.3 {
                return .yellow
            } else {
                return .green
            }
        } else {
            return .clear
        }
    }
    
    private func ringOpacity(for ring: Int) -> Double {
        let intensity = Double(animatedLevel)
        let ringThreshold = Double(ring) / Double(numberOfRings - 1)
        
        if intensity > ringThreshold {
            return min(intensity * 2, 1.0)
        } else {
            return 0
        }
    }
    
    private func ringLineWidth(for ring: Int) -> CGFloat {
        let intensity = CGFloat(animatedLevel)
        let baseWidth: CGFloat = 2
        return baseWidth + intensity * 3
    }
    
    private func ringScale(for ring: Int) -> CGFloat {
        let intensity = CGFloat(animatedLevel)
        let ringThreshold = CGFloat(ring) / CGFloat(numberOfRings - 1)
        
        if intensity > ringThreshold {
            return 1.0 + intensity * 0.2
        } else {
            return 1.0
        }
    }
    
    private func updateLevel(_ newLevel: Float) {
        // Enhanced sensitivity for subtle sounds
        let enhancedLevel = min(newLevel * 4.0, 1.0)
        
        // Smooth interpolation
        let smoothingFactor: Float = 0.4
        animatedLevel = animatedLevel * (1 - smoothingFactor) + enhancedLevel * smoothingFactor
    }
}

