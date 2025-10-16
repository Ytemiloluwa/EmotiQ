//
//  ProfileSettingsViews.swift
//  EmotiQ
//
//  Created by Temiloluwa on 11-08-2025.
//

import SwiftUI

// MARK: - Account & Privacy View
struct AccountPrivacyView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background using ThemeColors
                ThemeColors.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Edit Profile
//                        FullWidthSettingsRow(
//                            icon: "person.circle",
//                            title: "Edit Profile",
//                            subtitle: "Update your personal information",
//                            action: {
//                                HapticManager.shared.selection()
//                                viewModel.showingEditProfile = true
//                            }
//                        )
                        
                        // Face ID
                        FullWidthSettingsRow(
                            icon: "faceid",
                            title: "Face ID",
                            subtitle: viewModel.faceIDEnabled ? "Enabled" : "Disabled",
                            action: {
                                HapticManager.shared.selection()
                                viewModel.toggleFaceID()
                            }
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    )
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Account & Privacy")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $viewModel.showingEditProfile) {
            EditProfileView(viewModel: viewModel)
        }
        .alert("Face ID", isPresented: $viewModel.showingFaceIDAlert) {
            Button("Settings") {
                viewModel.openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(viewModel.faceIDAlertMessage)
        }
    }
}

// MARK: - App Settings View
struct AppSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background using ThemeColors
                ThemeColors.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Push Notifications
                     NotificationToggleRow()

                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    )
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("App Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Support & Info View
struct SupportInfoView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background using ThemeColors
                ThemeColors.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Contact Support
                        FullWidthSettingsRow(
                            icon: "questionmark.circle",
                            title: "Contact Support",
                            subtitle: "Get help with any issues",
                            action: {
                                HapticManager.shared.selection()
                                viewModel.openSupport()
                            }
                        )
                    
                        // Version
                        FullWidthSettingsRow(
                            icon: "info.circle",
                            title: "Version",
                            subtitle: "1.1.1",
                            action: { }
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    )
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Support & Info")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview
struct ProfileSettingsViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AccountPrivacyView(viewModel: ProfileViewModel())
            AppSettingsView(viewModel: ProfileViewModel())
            SupportInfoView(viewModel: ProfileViewModel())
        }
    }
}

// MARK: - Notification Toggle Row
struct NotificationToggleRow: View {
    @StateObject private var notificationManager = OneSignalNotificationManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "bell")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.purple)
                .frame(width: 24, height: 24)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(notificationManager.notificationPermissionGranted ? "Enabled" : "Tap to enable")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { notificationManager.notificationPermissionGranted },
                set: { newValue in
                    if newValue {
                        if notificationManager.notificationPermissionGranted {
                            
                            return
                        }
                        else {
                            
                            notificationManager.showingNotificationSettingsAlert = true
                        }
                        
                    } else {
                        // User wants to disable notifications -
                        notificationManager.showingNotificationSettingsAlert = true
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .purple))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .alert("Notifications", isPresented: $notificationManager.showingNotificationSettingsAlert) {
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Notifications can be enabled and disabled in your iPhone Settings.")
        }
        .onChange(of: notificationManager.showingNotificationSettingsAlert) { oldValue, newValue in

        }
    }
}
