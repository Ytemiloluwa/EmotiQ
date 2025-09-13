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
                        FullWidthSettingsRow(
                            icon: "bell",
                            title: "Push Notifications",
                            subtitle: OneSignalNotificationManager.shared.notificationPermissionGranted ? "Enabled" : "Disabled",
                            action: {
                                HapticManager.shared.selection()
                                OneSignalService.shared.requestNotificationPermission()
                            }
                        )
                        
//                        // Weekly Reports
//                        FullWidthSettingsRow(
//                            icon: "chart.bar",
//                            title: "Weekly Reports",
//                            subtitle: "Get insights about your emotional journey",
//                            action: { }
//                        )
//                        
//                        // Dark Mode
//                        FullWidthSettingsRow(
//                            icon: "moon",
//                            title: "Dark Mode",
//                            subtitle: viewModel.darkModeEnabled ? "On" : "Off",
//                            action: {
//                                HapticManager.shared.selection()
//                                viewModel.toggleDarkMode()
//                            }
//                        )
//                        
//                        // Recording Quality
//                        FullWidthSettingsRow(
//                            icon: "speaker.wave.2",
//                            title: "Recording Quality",
//                            subtitle: "High quality audio analysis",
//                            action: { }
//                        )
//                        
//                        // Noise Reduction
//                        FullWidthSettingsRow(
//                            icon: "waveform",
//                            title: "Noise Reduction",
//                            subtitle: "Improve voice analysis accuracy",
//                            action: { }
//                        )
                        

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
                            subtitle: "1.0.0",
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

