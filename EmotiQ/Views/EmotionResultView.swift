//
//  EmotionResultView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import Foundation
import SwiftUI

struct EmotionResultView: View {
    let result: EmotionAnalysisResult
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Main emotion display
                VStack(spacing: 16) {
                    Text(result.primaryEmotion.emoji)
                        .font(.system(size: 80))
                    
                    Text(result.primaryEmotion.displayName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(result.primaryEmotion.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Confidence indicator
                VStack(spacing: 8) {
                    HStack {
                        Text("Confidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(result.confidencePercentage)%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(result.isHighConfidence ? .green : .orange)
                    }
                    
                    ProgressView(value: result.confidence)
                        .progressViewStyle(LinearProgressViewStyle(
                            tint: result.isHighConfidence ? .green : .orange
                        ))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                )
                
                // Coaching tip
                VStack(alignment: .leading, spacing: 12) {
                    Text("Coaching Tip")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(result.primaryEmotion.coachingTip)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Analysis Result")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
