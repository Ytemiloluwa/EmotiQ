//
//  TodaySummarySection.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI

// Enhanced version with additional visual effects
struct TodaySummarySection: View, Equatable {
    static func == (lhs: TodaySummarySection, rhs: TodaySummarySection) -> Bool {
        lhs.emotionalValence == rhs.emotionalValence &&
        lhs.mostCommonEmotion == rhs.mostCommonEmotion &&
        lhs.averageIntensity == rhs.averageIntensity
    }
    
    let emotionalValence: EmotionValence
    let mostCommonEmotion: EmotionCategory
    let averageIntensity: EmotionIntensity
    @State private var isVisible = false
    @State private var animateCards = false
    @State private var gradientOffset = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Today's Summary")
                    .font(.title3)
//                    .foregroundStyle(
//                        LinearGradient(
//                            colors: [.primary, .blue, .purple],
//                            startPoint: .leading,
//                            endPoint: .trailing
//                        )
//                    )
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : -30)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: isVisible)
                
                Spacer()
                
//                // Animated refresh button
//                Button(action: {
//                    // Refresh action
//                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
//                        gradientOffset += 360
//                    }
//                }) {
//                    Image(systemName: "arrow.clockwise")
//                        .font(.title3)
//                        .foregroundColor(.blue)
//                        .rotationEffect(.degrees(gradientOffset))
//                }
//                .opacity(isVisible ? 1 : 0)
//                .animation(.easeOut(duration: 0.6).delay(0.3), value: isVisible)
            }
            
            VStack(spacing: 16) {
                SummaryRowPremium(
                    title: "Emotional Valence",
                    value: emotionalValence.displayName,
                    subtitle: emotionalValence.emoji,
                    icon: emotionalValence.icon,
                    color: emotionalValence.color,
                    animationDelay: 0.2
                )
                
                SummaryRowPremium(
                    title: "Dominant Emotion",
                    value: mostCommonEmotion.displayName,
                    subtitle: mostCommonEmotion.emoji,
                    icon: "brain.head.profile",
                    color: mostCommonEmotion.hexcolor,
                    animationDelay: 0.4
                )
                
                SummaryRowPremium(
                    title: "Emotional Intensity",
                    value: averageIntensity.IntensitydisplayName,
                    subtitle: "Average Level",
                    icon: "waveform.path.ecg",
                    color: averageIntensity.Intensitycolor,
                    animationDelay: 0.6
                )
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                    
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3), .pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
                .scaleEffect(animateCards ? 1 : 0.9)
                .opacity(animateCards ? 1 : 0)
            )
            .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: animateCards)
        }
        .transaction { $0.animation = nil }
        .onAppear {
            withAnimation {
                isVisible = true
                animateCards = true
            }
        }
    }
}

struct SummaryRowPremium: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let animationDelay: Double
    
    @State private var isPressed = false
    @State private var isVisible = false
    @State private var iconBounce = false
    @State private var shimmerOffset = -200.0
    
    var body: some View {
        HStack(spacing: 20) {
            // Enhanced Icon Container
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.2), color.opacity(0.05)],
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        )
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(iconBounce ? 1.1 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: iconBounce)
                
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isPressed ? 0.85 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    iconBounce.toggle()
                }
                
                // Enhanced haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            
            // Enhanced Content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : 40)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay), value: isVisible)
                
                ZStack(alignment: .leading) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(isVisible ? 1 : 0)
                        .offset(x: isVisible ? 0 : 40)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay + 0.1), value: isVisible)
                    
                    // Shimmer effect
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 100, height: 20)
                        .offset(x: shimmerOffset)
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: shimmerOffset)
                        .mask(
                            Text(value)
                                .font(.title3)
                                .fontWeight(.bold)
                        )
                }
                
                Text(subtitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : 40)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay + 0.2), value: isVisible)
            }
            
            Spacer()
            
            // Progress indicator
//            VStack {
//                Image(systemName: "chevron.right")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                    .opacity(0.6)
//                    .offset(x: isPressed ? 8 : 0)
//                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
//            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isPressed = false
                }
            }
        }
        .onAppear {
            withAnimation {
                isVisible = true
                shimmerOffset = 200
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        TodaySummarySection(
            emotionalValence: .neutral,
            mostCommonEmotion: .neutral,
            averageIntensity: .medium
        )
    }
    .padding()
}

