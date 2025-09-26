//
//  AudioVisualingView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 07-08-2025.
//
import SwiftUI

struct AudioLevelVisualization: View {
    
    // MARK: - Properties
    let audioLevels: [Float]
    let isRecording: Bool
    
    // MARK: - Configuration
    private let numberOfBars = 20
    private let barSpacing: CGFloat = 2
    private let minBarHeight: CGFloat = 3
    private let maxBarHeight: CGFloat = 60
    private let animationDuration: Double = 0.08
    
    // MARK: - State for professional behavior
    @State private var peakLevels: [Float] = Array(repeating: 0.0, count: 20)
    @State private var currentLevels: [Float] = Array(repeating: 0.0, count: 20)
    @State private var lastUpdateTime = Date()
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<numberOfBars, id: \.self) { index in
                ZStack(alignment: .bottom) {
                    // Main bar
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor(for: index))
                        .frame(width: 3.5, height: barHeight(for: index))
                        .animation(.easeOut(duration: animationDuration), value: currentLevels)
                    
                    // Peak indicator
                    if peakLevels[index] > 0.1 {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(peakColor(for: index))
                            .frame(width: 3.5, height: 2)
                            .offset(y: -peakHeight(for: index))
                            .animation(.easeOut(duration: 0.05), value: peakLevels)
                    }
                }
            }
        }
        .frame(height: maxBarHeight)
        .onAppear {
            initializeArrays()
        }
        .onChange(of: audioLevels) { _, newLevels in
            updateProfessionalLevels(newLevels)
        }
        .onReceive(Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()) { _ in
            if isRecording {
                decayPeaks()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func barHeight(for index: Int) -> CGFloat {
        // If not recording, return minimum height (static state)
        guard isRecording else {
            return minBarHeight
        }
        
        // Use professional current levels
        guard index < currentLevels.count else {
            return minBarHeight
        }
        
        let level = currentLevels[index]
        let normalizedLevel = CGFloat(level)
        let height = minBarHeight + (maxBarHeight - minBarHeight) * normalizedLevel
        let finalHeight = max(minBarHeight, height)
        
        return finalHeight
    }
    
    private func barColor(for index: Int) -> Color {
        guard isRecording, index < currentLevels.count else {
            return ThemeColors.tertiaryText.opacity(0.2)
        }
        
        let level = currentLevels[index]
        let intensity = Double(level)
        
        // Professional audio software colors using solid colors
        let frequencyPosition = Double(index) / Double(numberOfBars - 1)
        
        // Create frequency-based colors using only green, yellow, and red
        let baseColor: Color
        if frequencyPosition < 0.3 {
            // Low frequencies (bass) - green
            baseColor = .green
        } else if frequencyPosition < 0.7 {
            // Mid frequencies - yellow
            baseColor = .yellow
        } else {
            // High frequencies - red
            baseColor = .red
        }
        
        // Intensity-based opacity only
        let opacity = max(0.4, intensity * 0.9)
        return baseColor.opacity(opacity)
    }
    
    // MARK: - Professional Audio Methods
    
    private func initializeArrays() {
        currentLevels = Array(repeating: 0.0, count: numberOfBars)
        peakLevels = Array(repeating: 0.0, count: numberOfBars)
    }
    
    private func updateProfessionalLevels(_ newLevels: [Float]) {
        guard isRecording, newLevels.count >= numberOfBars else { return }
        
        let currentTime = Date()
        let deltaTime = currentTime.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = currentTime
        
        for i in 0..<numberOfBars {
            let rawLevel = newLevels[min(i, newLevels.count - 1)]
            
            // Simulate frequency-based response
            let processedLevel = simulateFrequencyResponse(rawLevel, for: i)
            
            // Apply attack and decay
            let attackRate: Float = 8.0  // Fast attack
            let decayRate: Float = 3.0   // Slower decay
            
            if processedLevel > currentLevels[i] {
                // Attack (fast response to increases)
                currentLevels[i] = min(1.0, currentLevels[i] + (processedLevel - currentLevels[i]) * Float(deltaTime) * attackRate)
            } else {
                // Decay (slower response to decreases)
                currentLevels[i] = max(0.0, currentLevels[i] - (currentLevels[i] - processedLevel) * Float(deltaTime) * decayRate)
            }
            
            // Update peak levels
            if currentLevels[i] > peakLevels[i] {
                peakLevels[i] = currentLevels[i]
            }
        }
    }
    
    private func simulateFrequencyResponse(_ level: Float, for index: Int) -> Float {
        let frequencyPosition = Float(index) / Float(numberOfBars - 1)
        
        // Add some randomness to simulate real frequency content
        let randomVariation = Float.random(in: 0.8...1.2)
        let baseLevel = level * randomVariation
        
        // Simulate frequency response characteristics
        var processedLevel: Float
        
        if frequencyPosition < 0.3 {
            // Low frequencies - more consistent, less variation
            processedLevel = baseLevel * Float.random(in: 0.9...1.1)
        } else if frequencyPosition < 0.7 {
            // Mid frequencies - most active for voice
            processedLevel = baseLevel * Float.random(in: 0.7...1.3)
        } else {
            // High frequencies - more sporadic
            processedLevel = baseLevel * Float.random(in: 0.5...1.4)
        }
        
        return min(1.0, max(0.0, processedLevel))
    }
    
    private func decayPeaks() {
        for i in 0..<numberOfBars {
            // Peak decay rate
            let peakDecayRate: Float = 0.02
            peakLevels[i] = max(currentLevels[i], peakLevels[i] - peakDecayRate)
        }
    }
    
    private func peakHeight(for index: Int) -> CGFloat {
        let level = peakLevels[index]
        let normalizedLevel = CGFloat(level)
        let height = (maxBarHeight - minBarHeight) * normalizedLevel
        return height
    }
    
    private func peakColor(for index: Int) -> Color {
        let level = peakLevels[index]
        let intensity = Double(level)
        
        if intensity > 0.8 {
            return Color.red.opacity(0.9)      // Red for high peaks
        } else if intensity > 0.6 {
            return Color.yellow.opacity(0.8)   // Yellow for medium peaks
        } else {
            return Color.green.opacity(0.7)    // Green for low peaks
        }
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
        // Keep circular indicator static - don't animate based on audio levels
        animatedLevel = 0
    }
}
