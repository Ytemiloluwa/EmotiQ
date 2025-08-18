//
//  SwipeableRow.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import SwiftUI
import UIKit

struct SwipeableRow<Content: View, ID: Hashable>: View {
    // Identity & callbacks
    let id: ID
    @Binding var openRowID: ID?
    @Binding var isAnyRowDragging: Bool
    let onDelete: () -> Void
    let content: Content

    // UI state
    @State private var baseOffsetX: CGFloat = 0          // settled offset (-actionWidth or 0)
    @GestureState private var dragX: CGFloat = 0          // live drag delta
    @State private var hasLockedDirection = false
    @State private var isHorizontalDrag = false

    // Tunables
    private let actionWidth: CGFloat = 88                 // delete button width
    private let fullSwipeWidth: CGFloat = 160             // trigger delete on hard swipe (optional)
    private let lockThreshold: CGFloat = 8                // px before we decide direction

    init(
        id: ID,
        openRowID: Binding<ID?>,
        isAnyRowDragging: Binding<Bool>,
        @ViewBuilder content: () -> Content,
        onDelete: @escaping () -> Void
    ) {
        self.id = id
        self._openRowID = openRowID
        self._isAnyRowDragging = isAnyRowDragging
        self.content = content()
        self.onDelete = onDelete
    }

    var body: some View {
        let drag = DragGesture(minimumDistance: 5, coordinateSpace: .local)
            .updating($dragX) { value, state, _ in
                // Decide direction once movement is noticeable
                if !hasLockedDirection {
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > lockThreshold || abs(dy) > lockThreshold {
                        hasLockedDirection = true
                        isHorizontalDrag = abs(dx) > abs(dy)
                        if isHorizontalDrag {
                            // close others; claim scroll
                            openRowID = nil
                            isAnyRowDragging = true
                        }
                    }
                }

                guard isHorizontalDrag else { return }
                // Only allow left drag; clamp to -1.25 * actionWidth for elasticity
                let proposed = baseOffsetX + value.translation.width
                state = max(min(proposed, 0), -(actionWidth * 1.25))
            }
            .onEnded { value in
                defer {
                    hasLockedDirection = false
                    isHorizontalDrag = false
                    // Re-enable scroll on next runloop for smoothness
                    DispatchQueue.main.async { isAnyRowDragging = false }
                }

                guard isHorizontalDrag else { return }

                let totalX = baseOffsetX + value.translation.width
                let leftPull = -totalX

                if leftPull >= fullSwipeWidth {
                    // Optional: full swipe → delete immediately
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDelete()
                    openRowID = nil
                    baseOffsetX = 0
                    return
                }

                if leftPull >= actionWidth * 0.6 {
                    // Keep button open
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        baseOffsetX = -actionWidth
                        openRowID = id
                    }
                } else {
                    // Close
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        baseOffsetX = 0
                        if openRowID == id { openRowID = nil }
                    }
                }
            }

        ZStack(alignment: .trailing) {
            // Background action(s)
            HStack(spacing: 0) {
                Spacer()
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        onDelete()
                        openRowID = nil
                        baseOffsetX = 0
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .frame(width: actionWidth, height: 60)
                        .foregroundColor(.white)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.trailing, 8)
                }
            }

            // Foreground content
            content
                .contentShape(Rectangle()) // full hit area
                .background(Color(.systemBackground))
                .offset(x: baseOffsetX + dragX)
                .highPriorityGesture(drag)  // win over ScrollView when horizontal
                .onChange(of: openRowID) { newValue in
                    // Close this row if another one opens
                    if newValue != id {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            baseOffsetX = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            baseOffsetX = -actionWidth
                        }
                    }
                }
        }
        .zIndex(openRowID == id ? 1 : 0) // keep opened row above neighbors
        .clipped()
    }
}

