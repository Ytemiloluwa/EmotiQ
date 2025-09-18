//
//  NotificationHistoryView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 09-09-2025.
//

import Foundation
import SwiftUI

struct NotificationHistoryView: View {
    @StateObject private var historyManager = NotificationHistoryManager.shared
    @State private var selectedFilter: NotificationHistoryType? = nil
    @State private var showingFilterSheet = false
    
    var filteredNotifications: [NotificationHistoryItem] {
        if let filter = selectedFilter {
            return historyManager.notifications.filter { $0.type == filter }
        }
        return historyManager.notifications
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if historyManager.notifications.isEmpty {
                emptyStateView
            } else {
                notificationsList
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        historyManager.markAllAsRead()
                    }) {
                        Label("Mark All Read", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    
                    Button(role: .destructive, action: {
                        historyManager.clearAllNotifications()
                    }) {
                        Label("Clear All", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(ThemeColors.accent)
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            filterSheet
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Notifications Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            Text("Your notifications will appear here when you receive them")
                .font(.body)
                .foregroundColor(ThemeColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if selectedFilter != nil {
                    filterHeader
                }
                
                ForEach(filteredNotifications) { notification in
                    NotificationRowView(notification: notification) {
                        historyManager.markAsRead(notification.id)
                    }
                    .background(Color.clear)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var filterHeader: some View {
        HStack {
            Button(action: {
                selectedFilter = nil
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                    Text("Clear Filter")
                        .foregroundColor(ThemeColors.accent)
                }
            }
            
            Spacer()
            
            if let filter = selectedFilter {
                Text("Showing: \(filter.displayName)")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    private var filterSheet: some View {
        NavigationView {
            List {
                Section("Filter by Type") {
                    Button("Show All") {
                        selectedFilter = nil
                        showingFilterSheet = false
                    }
                    .foregroundColor(selectedFilter == nil ? ThemeColors.accent : ThemeColors.primaryText)
                    
                    ForEach(NotificationHistoryType.allCases, id: \.self) { type in
                        Button(action: {
                            selectedFilter = type
                            showingFilterSheet = false
                        }) {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                                    .frame(width: 20)
                                
                                Text(type.displayName)
                                    .foregroundColor(selectedFilter == type ? ThemeColors.accent : ThemeColors.primaryText)
                                
                                Spacer()
                                
                                let count = historyManager.getNotificationsByType(type).count
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(type.color.opacity(0.2))
                                        .clipShape(Capsule())
                                        .foregroundColor(type.color)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilterSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct NotificationRowView: View {
    let notification: NotificationHistoryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Type icon
                ZStack {
                    Circle()
                        .fill(notification.type.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: notification.type.icon)
                        .foregroundColor(notification.type.color)
                        .font(.system(size: 16, weight: .medium))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(notification.title)
                            .font(.system(size: 16, weight: notification.isRead ? .regular : .semibold))
                            .foregroundColor(ThemeColors.primaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if !notification.isRead {
                            Circle()
                                .fill(ThemeColors.accent)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.body)
                        .font(.system(size: 14))
                        .foregroundColor(ThemeColors.secondaryText)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(notification.type.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(notification.type.color.opacity(0.1))
                            .foregroundColor(notification.type.color)
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        Text(formatDate(notification.receivedAt))
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(notification.isRead ? Color.clear : ThemeColors.accent.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 0)
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

#Preview {
    NotificationHistoryView()
        .environmentObject(NotificationHistoryManager.shared)
}
