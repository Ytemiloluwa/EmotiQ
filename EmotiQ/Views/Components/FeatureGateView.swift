//
//  FeatureGateView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI

struct FeatureGateView<Content: View>: View {
    let feature: FeatureType
    let subscriptionService: SubscriptionServiceProtocol
    let content: Content
    
    @State private var showingSubscriptionPaywall = false
    
    init(
        feature: FeatureType,
        subscriptionService: SubscriptionServiceProtocol = SubscriptionService.shared,
        @ViewBuilder content: () -> Content
    ) {
        self.feature = feature
        self.subscriptionService = subscriptionService
        self.content = content()
    }
    
    var body: some View {
        Group {
            if subscriptionService.checkFeatureAccess(feature) {
                content
            } else {
                FeatureLockedView(
                    feature: feature,
                    showingSubscriptionPaywall: $showingSubscriptionPaywall
                )
            }
        }
        .sheet(isPresented: $showingSubscriptionPaywall) {
            SubscriptionPaywallView()
        }
    }
}

struct FeatureLockedView: View {
    let feature: FeatureType
    @Binding var showingSubscriptionPaywall: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.purple)
            
            Text("\(feature.displayName) Locked")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(feature.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Upgrade to Pro/Premium") {
                showingSubscriptionPaywall = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - Convenience Modifiers
extension View {
    func featureGate<Content: View>(
        _ feature: FeatureType,
        subscriptionService: SubscriptionServiceProtocol = SubscriptionService.shared,
        @ViewBuilder content: () -> Content
    ) -> some View {
        FeatureGateView(feature: feature, subscriptionService: subscriptionService, content: content)
    }
}

// MARK: - Preview
struct FeatureGateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            FeatureGateView(feature: .voiceCloning) {
                Text("Voice Cloning Feature")
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
            }
            
            FeatureGateView(feature: .dataExport) {
                Text("Data Export Feature")
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}
