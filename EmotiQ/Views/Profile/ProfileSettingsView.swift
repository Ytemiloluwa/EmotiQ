//
//  ProfileSettingsView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import SwiftUI

// MARK: - Account & Privacy View
struct AccountPrivacyView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Edit Profile")
                                .font(.subheadline)
                            Text("Update your personal information")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Edit") {
                            viewModel.showingEditProfile = true
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                }
                
                Section("Security") {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Face ID")
                                .font(.subheadline)
                            Text(viewModel.faceIDEnabled ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { viewModel.faceIDEnabled },
                            set: { _ in viewModel.toggleFaceID() }
                        ))
                    }
                }
                
                Section("Privacy") {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Data Privacy")
                                .font(.subheadline)
                            Text("Manage your data and privacy settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Account & Privacy")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $viewModel.showingEditProfile) {
            EditProfileView(viewModel: viewModel)
        }
    }
}

// MARK: - App Settings View
struct AppSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section("Notifications") {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Push Notifications")
                                .font(.subheadline)
                            Text("Daily reminders and coaching tips")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(true))
                    }
                    
                    HStack {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Reports")
                                .font(.subheadline)
                            Text("Get insights about your emotional journey")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(false))
                    }
                }
                
                Section("Appearance") {
                    HStack {
                        Image(systemName: "moon")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dark Mode")
                                .font(.subheadline)
                            Text(viewModel.darkModeEnabled ? "On" : "Off")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { viewModel.darkModeEnabled },
                            set: { _ in viewModel.toggleDarkMode() }
                        ))
                    }
                }
                
                Section("Audio") {
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recording Quality")
                                .font(.subheadline)
                            Text("High quality audio analysis")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("High")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Noise Reduction")
                                .font(.subheadline)
                            Text("Improve voice analysis accuracy")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(true))
                    }
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
            List {
                Section("Help & Support") {
                    Button(action: { viewModel.openSupport() }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Contact Support")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Get help with any issues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "envelope")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: { viewModel.openPrivacyPolicy() }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Privacy Policy")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Read our privacy policy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section("App") {
                    Button(action: { viewModel.requestAppReview() }) {
                        HStack {
                            Image(systemName: "star")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rate EmotiQ")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Share your experience")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Version")
                                .font(.subheadline)
                            Text("1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
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
