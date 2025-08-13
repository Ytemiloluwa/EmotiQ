//
//  AudioVisualingView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 07-08-2025.
//
import SwiftUI
import Foundation

// MARK: - Audio Level Visualization
struct AudioLevelVisualization: View {
    
    // MARK: - Properties
    let audioLevel: Float
    let isRecording: Bool
    
    // MARK: - Configuration
    private let numberOfBars = 20
    private let barSpacing: CGFloat = 3
    private let minBarHeight: CGFloat = 4
    private let maxBarHeight: CGFloat = 60
    private let animationDuration: Double = 0.1
    
    // MARK: - State
    @State private var animatedLevels: [Float] = Array(repeating: 0, count: 20)
    @State private var lastUpdateTime = Date()
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<numberOfBars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barGradient(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeInOut(duration: animationDuration), value: animatedLevels[index])
            }
        }
        .frame(height: maxBarHeight)
        .onChange(of: audioLevel) { _, newLevel in
            updateVisualization(with: newLevel)
        }
        .onChange(of: isRecording) { _, recording in
            if !recording {
                resetVisualization()
            }
        }
        .onAppear {
            initializeVisualization()
        }
    }
    
    // MARK: - Private Methods
    
    private func barHeight(for index: Int) -> CGFloat {
        let level = animatedLevels[index]
        let normalizedLevel = CGFloat(level)
        let height = minBarHeight + (maxBarHeight - minBarHeight) * normalizedLevel
        return max(minBarHeight, height)
    }
    
    private func barGradient(for index: Int) -> LinearGradient {
        let level = animatedLevels[index]
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
    
    private func updateVisualization(with newLevel: Float) {
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now
        
        // Enhanced sensitivity - respond to even small changes
        let sensitivityMultiplier: Float = 3.0
        let enhancedLevel = min(newLevel * sensitivityMultiplier, 1.0)
        
        // Create frequency-like distribution
        let centerIndex = numberOfBars / 2
        let maxDistance = Float(numberOfBars / 2)
        
        for i in 0..<numberOfBars {
            let distance = abs(Float(i - centerIndex))
            let falloff = 1.0 - (distance / maxDistance)
            
            // Add some randomness for natural look
            let randomVariation = Float.random(in: 0.8...1.2)
            let targetLevel = enhancedLevel * falloff * randomVariation
            
            // Smooth interpolation for natural movement
            let smoothingFactor: Float = 0.3
            animatedLevels[i] = animatedLevels[i] * (1 - smoothingFactor) + targetLevel * smoothingFactor
            
            // Ensure minimum activity when recording
            if isRecording && enhancedLevel > 0.01 {
                animatedLevels[i] = max(animatedLevels[i], 0.1)
            }
        }
    }
    
    private func resetVisualization() {
        withAnimation(.easeOut(duration: 0.5)) {
            animatedLevels = Array(repeating: 0, count: numberOfBars)
        }
    }
    
    private func initializeVisualization() {
        animatedLevels = Array(repeating: 0, count: numberOfBars)
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
