//
//
//  VoiceCloningSetupView.swift
//  EmotiQ
//
//  Voice cloning setup interface with guided recording flow
//

import SwiftUI
import AVFoundation
import Accelerate

// MARK: - User-Friendly Error Types
enum VoiceCloningError: LocalizedError {
    case noRecordingFound
    case noVoiceProfileFound
    case networkConnection
    case timeout
    case serviceUnavailable
    case recordingTooShort
    case recordingTooLong
    case poorAudioQuality
    case invalidAudioFormat
    case processingFailed
    case testFailed
    case microphonePermission
    case audioSessionSetup
    
    var errorDescription: String? {
        switch self {
        case .noRecordingFound:
            return "No voice recording found. Please record your voice sample first."
        case .noVoiceProfileFound:
            return "Voice profile not found. Please complete the voice setup process."
        case .networkConnection:
            return "Network connection issue. Please check your internet connection and try again."
        case .timeout:
            return "Request timed out. Please try again in a moment."
        case .serviceUnavailable:
            return "Service temporarily unavailable. Please try again later."
        case .recordingTooShort:
            return "Recording is too short. Please record at least 30 seconds of audio."
        case .recordingTooLong:
            return "Recording is too long. Please keep it under 5 minutes."
        case .poorAudioQuality:
            return "Audio quality is too low. Please record in a quieter environment."
        case .invalidAudioFormat:
            return "Invalid audio format. Please try recording again."
        case .processingFailed:
            return "Failed to process your voice. Please try again."
        case .testFailed:
            return "Voice test failed. Please try again."
        case .microphonePermission:
            return "Microphone permission required. Please enable microphone access in Settings."
        case .audioSessionSetup:
            return "Audio setup failed. Please try again."
        }
    }
}

// MARK: - Voice Cloning Setup View
struct VoiceCloningSetupView: View {
    @StateObject private var viewModel = VoiceCloningViewModel()
    @EnvironmentObject private var elevenLabsService: ElevenLabsService
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    // Navigation state for AffirmationsView
    @State private var showingAffirmations = false
    
    var body: some View {
        FeatureGateView(feature: .voiceCloning) {
            NavigationStack {
                ZStack {
                    ThemeColors.backgroundGradient
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // MARK: - Header
                            VoiceCloningHeaderView()
                            
                            // MARK: - Setup Steps
                            VoiceCloningStepsView(currentStep: viewModel.currentStep)
                            
                            // MARK: - Main Content
                            switch viewModel.currentStep {
                            case .introduction:
                                IntroductionStepView(viewModel: viewModel)
                            case .preparation:
                                PreparationStepView(viewModel: viewModel)
                            case .recording:
                                RecordingStepView(viewModel: viewModel)
                            case .processing:
                                ProcessingStepView(viewModel: viewModel)
                            case .completion:
                                CompletionStepView(
                                    viewModel: viewModel,
                                    onNavigateToAffirmations: {
                                        showingAffirmations = true
                                    }
                                )
                            }
                            
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal)
                    }
                }
                .navigationTitle("Voice Setup")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(viewModel.currentStep == .processing)
                //            .toolbar {
                //                ToolbarItem(placement: .navigationBarLeading) {
                //                    if viewModel.currentStep != .processing {
                //                        Button("Cancel") {
                //                            HapticManager.shared.impact(.light)
                //                            dismiss()
                //                        }
                //                        .foregroundColor(ThemeColors.accent)
                //                    }
                //                }
                //            }
            }
            .onAppear {
                viewModel.setupAudioSession()
            }
            .onDisappear {
                viewModel.cleanupAudioSession()
            }
            .alert("Voice Cloning Error", isPresented: $viewModel.showingError) {
                Button("OK") {
                    viewModel.showingError = false
                }
            } message: {
                Text(viewModel.errorMessage)
            }
            .navigationDestination(isPresented: $showingAffirmations) {
                AffirmationsView()
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Coaching") {
                                showingAffirmations = false
                            }
                        }
                    }
            }
        }
    }
    
    
    // MARK: - Header View
    struct VoiceCloningHeaderView: View {
        var body: some View {
            VStack(spacing: 16) {
                // Voice icon with animation
                ZStack {
                    Circle()
                        .fill(ThemeColors.accent.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(ThemeColors.accent)
                }
                
                VStack(spacing: 8) {
                    Text("Create Your Voice")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Record a short sample to create personalized emotional coaching in your own voice")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Steps Indicator
    struct VoiceCloningStepsView: View {
        let currentStep: VoiceCloningStep
        
        var body: some View {
            HStack {
                ForEach(VoiceCloningStep.allCases, id: \.self) { step in
                    HStack {
                        // Step circle
                        ZStack {
                            Circle()
                                .fill(stepColor(for: step))
                                .frame(width: 24, height: 24)
                            
                            if step.rawValue < currentStep.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            } else {
                                Text("\(step.rawValue + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(step == currentStep ? .white : ThemeColors.secondaryText)
                            }
                        }
                        
                        // Connector line
                        if step != VoiceCloningStep.allCases.last {
                            Rectangle()
                                .fill(step.rawValue < currentStep.rawValue ? ThemeColors.success : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        
        private func stepColor(for step: VoiceCloningStep) -> Color {
            if step.rawValue < currentStep.rawValue {
                return ThemeColors.success
            } else if step == currentStep {
                return ThemeColors.accent
            } else {
                return Color.gray.opacity(0.3)
            }
        }
    }
    
    // MARK: - Introduction Step
    struct IntroductionStepView: View {
        @ObservedObject var viewModel: VoiceCloningViewModel
        
        var body: some View {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Why Clone Your Voice?")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    VStack(spacing: 12) {
                        BenefitRow(
                            icon: "heart.fill",
                            title: "Personal Connection",
                            description: "Hear emotional guidance in your own voice for deeper impact"
                        )
                        
                        BenefitRow(
                            icon: "brain.head.profile",
                            title: "Better Retention",
                            description: "Self-spoken affirmations are proven more effective"
                        )
                        
                        BenefitRow(
                            icon: "lock.shield.fill",
                            title: "Privacy First",
                            description: "Your voice data is encrypted and never shared"
                        )
                    }
                }
                
                VStack(spacing: 12) {
                    Text("Requirements")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    VStack(spacing: 8) {
                        RequirementRow(
                            icon: "clock.fill",
                            text: "60 seconds of clear speech",
                            isMet: true
                        )
                        
                        RequirementRow(
                            icon: "mic.fill",
                            text: "Microphone permission",
                            isMet: viewModel.hasMicrophonePermission
                        )
                        
                        RequirementRow(
                            icon: "speaker.wave.3.fill",
                            text: "Quiet environment",
                            isMet: viewModel.environmentIsQuiet
                        )
                    }
                }
                
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    viewModel.nextStep()
                }) {
                    HStack {
                        Text("Get Started")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ThemeColors.accent)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.canProceed)
            }
            .padding()
            .themedCard()
        }
    }
    
    // MARK: - Preparation Step
    struct PreparationStepView: View {
        @ObservedObject var viewModel: VoiceCloningViewModel
        
        var body: some View {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Preparation")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Follow these tips for the best voice cloning results:")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                
                // Voice Profile Name Input
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundColor(ThemeColors.accent)
                            .font(.title3)
                        
                        Text("Name Your Voice Profile")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ThemeColors.primaryText)
                        
                        Spacer()
                    }
                    
                    TextField("Enter a unique name for your voice", text: $viewModel.customVoiceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.subheadline)
                    
                    if viewModel.isVoiceNameValid {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ThemeColors.success)
                                .font(.caption)
                            
                            Text("Your voice will be saved as: \"\(viewModel.customVoiceName.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                                .font(.caption)
                                .foregroundColor(ThemeColors.success)
                            
                            Spacer()
                        }
                    } else {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(ThemeColors.secondaryText)
                                .font(.caption)
                            
                            Text("Give your voice profile a meaningful name")
                                .font(.caption)
                                .foregroundColor(ThemeColors.secondaryText)
                            
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ThemeColors.accent.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ThemeColors.accent.opacity(0.2), lineWidth: 1)
                        )
                )
                
                VStack(spacing: 16) {
                    PreparationTipCard(
                        icon: "location.fill",
                        title: "Find a Quiet Space",
                        description: "Choose a room with minimal background noise and echo"
                    )
                    
                    PreparationTipCard(
                        icon: "speaker.wave.2.fill",
                        title: "Speak Naturally",
                        description: "Use your normal speaking voice and pace"
                    )
                    
                    PreparationTipCard(
                        icon: "textformat",
                        title: "Read Clearly",
                        description: "Pronounce words clearly and avoid mumbling"
                    )
                    
                    PreparationTipCard(
                        icon: "heart.text.square.fill",
                        title: "Express Emotion",
                        description: "Include some emotional variety in your speech"
                    )
                }
                
                // Environment check
                HStack {
                    Image(systemName: viewModel.environmentIsQuiet ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(viewModel.environmentIsQuiet ? ThemeColors.success : ThemeColors.warning)
                    
                    Text(viewModel.environmentIsQuiet ? "Environment is quiet" : "Environment is noisy")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.environmentIsQuiet ? ThemeColors.success.opacity(0.1) : ThemeColors.warning.opacity(0.1))
                )
                
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    viewModel.nextStep()
                }) {
                    HStack {
                        Text("Start Recording")
                        Image(systemName: "mic.fill")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ThemeColors.accent)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.environmentIsQuiet || !viewModel.isVoiceNameValid)
            }
            .padding()
            .themedCard()
        }
    }
    
    // MARK: - Recording Step
    struct RecordingStepView: View {
        @ObservedObject var viewModel: VoiceCloningViewModel
        
        var body: some View {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Voice Recording")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Read the text below in your natural speaking voice")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                
                // Recording script
                ScrollView {
                    Text(viewModel.recordingScript)
                        .font(.body)
                        .foregroundColor(ThemeColors.primaryText)
                        .lineSpacing(4)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ThemeColors.secondaryBackground)
                        )
                }
                .frame(maxHeight: 200)
                
                // Recording controls
                VStack(spacing: 16) {
                    // Waveform visualization
                    AudioWaveformView(
                        audioLevels: viewModel.audioLevels,
                        isRecording: viewModel.isRecording
                    )
                    .frame(height: 60)
                    
                    // Timer and progress
                    HStack {
                        Text(viewModel.recordingTimeText)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(ThemeColors.primaryText)
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.recordingProgress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                    
                    ProgressView(value: viewModel.recordingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: ThemeColors.accent))
                    
                    // Recording button
                    Button(action: {
                        HapticManager.shared.impact(.heavy)
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(viewModel.isRecording ? ThemeColors.error : ThemeColors.accent)
                                .frame(width: 80, height: 80)
                                .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: viewModel.isRecording)
                            
                            Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(viewModel.recordingProgress >= 1.0 && !viewModel.isRecording)
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        if viewModel.hasRecording {
                            Button("Re-record") {
                                HapticManager.shared.impact(.light)
                                viewModel.resetRecording()
                            }
                            .foregroundColor(ThemeColors.accent)
                        }
                        
                        Spacer()
                        
                        if viewModel.recordingProgress >= 1.0 {
                            Button(action: {
                                HapticManager.shared.impact(.medium)
                                viewModel.nextStep()
                            }) {
                                HStack {
                                    Text(viewModel.needsReRecording ? "Re-record Required" : "Process Voice")
                                    Image(systemName: viewModel.needsReRecording ? "arrow.clockwise" : "arrow.right")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(viewModel.needsReRecording ? Color.gray : ThemeColors.success)
                                .cornerRadius(8)
                            }
                            .disabled(viewModel.needsReRecording)
                        }
                    }
                }
            }
            .padding()
            .themedCard()
        }
    }
    
    // MARK: - Processing Step
    struct ProcessingStepView: View {
        @ObservedObject var viewModel: VoiceCloningViewModel
        @EnvironmentObject private var elevenLabsService: ElevenLabsService
        
        var body: some View {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    // Animated processing icon or error icon
                    ZStack {
                        Circle()
                            .stroke(viewModel.processingError != nil ? Color.red.opacity(0.3) : ThemeColors.accent.opacity(0.3), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        if viewModel.processingError == nil {
                            Circle()
                                .trim(from: 0, to: viewModel.processingProgress)
                                .stroke(ThemeColors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: viewModel.processingProgress)
                        }
                        
                        Image(systemName: viewModel.processingError != nil ? "exclamationmark.triangle.fill" : "brain.head.profile")
                            .font(.title)
                            .foregroundColor(viewModel.processingError != nil ? .red : ThemeColors.accent)
                    }
                    
                    Text(viewModel.processingError != nil ? "Processing Failed" : "Processing Your Voice")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text(viewModel.processingMessage)
                        .font(.subheadline)
                        .foregroundColor(viewModel.processingError != nil ? .red : ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                
                if viewModel.processingError == nil {
                    // Progress steps (only show when not in error state)
                    VStack(spacing: 16) {
                        ProcessingStepRow(
                            title: "Preparing your voice sample",
                            isComplete: viewModel.processingProgress > 0.1,
                            isActive: viewModel.processingProgress <= 0.15
                        )
                        
                        ProcessingStepRow(
                            title: "Uploading to voice service",
                            isComplete: viewModel.processingProgress > 0.3,
                            isActive: viewModel.processingProgress > 0.15 && viewModel.processingProgress <= 0.45
                        )
                        
                        ProcessingStepRow(
                            title: "Creating voice profile",
                            isComplete: viewModel.processingProgress > 0.6,
                            isActive: viewModel.processingProgress > 0.45 && viewModel.processingProgress <= 0.75
                        )
                        
                        ProcessingStepRow(
                            title: "Finalizing setup",
                            isComplete: viewModel.processingProgress >= 0.9,
                            isActive: viewModel.processingProgress > 0.75 && viewModel.processingProgress < 0.9
                        )
                    }
                    
                    // Progress percentage
                    Text("\(Int(viewModel.processingProgress * 100))% Complete")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.accent)
                } else {
                    // Error state with retry button
                    VStack(spacing: 20) {
                        Text("Something went wrong during voice processing")
                            .font(.subheadline)
                            .foregroundColor(ThemeColors.secondaryText)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            viewModel.retryRecording()
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back to Recording")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ThemeColors.accent)
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
            .themedCard()
            .onAppear {
                if !viewModel.isProcessing && viewModel.processingError == nil {
                    viewModel.processVoiceCloning()
                }
            }
        }
    }
    
    // MARK: - Completion Step
    struct CompletionStepView: View {
        @ObservedObject var viewModel: VoiceCloningViewModel
        @Environment(\.dismiss) private var dismiss
        let onNavigateToAffirmations: () -> Void
        
        var body: some View {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    // Success animation
                    ZStack {
                        Circle()
                            .fill(ThemeColors.success.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(ThemeColors.success)
                            .scaleEffect(viewModel.showSuccessAnimation ? 1.2 : 1.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: viewModel.showSuccessAnimation)
                    }
                    
                    Text("Voice Cloning Complete!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Your personalized voice is ready for emotional coaching and affirmations")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Test voice button
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    if viewModel.isPlayingAudio {
                        // Stop playing if currently playing
                        viewModel.stopAudio()
                    } else {
                        viewModel.testVoice()
                    }
                }) {
                    HStack {
                        if viewModel.isTestingVoice {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(ThemeColors.accent)
                        } else if viewModel.isPlayingAudio {
                            Image(systemName: "stop.circle.fill")
                        } else {
                            Image(systemName: "play.circle.fill")
                        }
                        Text(viewModel.isTestingVoice ? "Generating..." : (viewModel.isPlayingAudio ? "Stop Audio" : "Test Your Voice"))
                    }
                    .font(.headline)
                    .foregroundColor(ThemeColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ThemeColors.accent, lineWidth: 2)
                    )
                }
                .disabled(viewModel.isTestingVoice)
                
                if viewModel.isPlayingAudio {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(ThemeColors.accent)
                        Text("Playing your voice...")
                            .font(.subheadline)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                } else if viewModel.voiceTestCompleted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ThemeColors.success)
                        Text("Voice setup successfully")
                            .font(.subheadline)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                }
                
                // Continue button
                Button(action: {
                    HapticManager.shared.notification(.success)
                    // Navigate to AffirmationsView to immediately try voice-powered affirmations
                    onNavigateToAffirmations()
                }) {
                    HStack {
                        Text("Start Using EmotiQ")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ThemeColors.accent)
                    .cornerRadius(12)
                }
            }
            .padding()
            .themedCard()
            .onAppear {
                viewModel.showSuccessAnimation = true
                HapticManager.shared.notification(.success)
            }
        }
    }
    
    // MARK: - Supporting Views
    
    struct BenefitRow: View {
        let icon: String
        let title: String
        let description: String
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(ThemeColors.accent)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
        }
    }
    
    struct RequirementRow: View {
        let icon: String
        let text: String
        let isMet: Bool
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(isMet ? ThemeColors.success : ThemeColors.secondaryText)
                    .frame(width: 20)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isMet ? ThemeColors.success : ThemeColors.secondaryText)
            }
        }
    }
    
    struct PreparationTipCard: View {
        let icon: String
        let title: String
        let description: String
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(ThemeColors.accent)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ThemeColors.secondaryBackground)
            )
        }
    }
    
    struct ProcessingStepRow: View {
        let title: String
        let isComplete: Bool
        let isActive: Bool
        
        var body: some View {
            HStack {
                Image(systemName: isComplete ? "checkmark.circle.fill" : (isActive ? "circle.dotted" : "circle"))
                    .foregroundColor(isComplete ? ThemeColors.success : (isActive ? ThemeColors.accent : ThemeColors.secondaryText))
                    .font(.title3)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(isComplete ? ThemeColors.success : (isActive ? ThemeColors.primaryText : ThemeColors.secondaryText))
                
                Spacer()
                
                if isActive && !isComplete {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
    }
    
    struct AudioWaveformView: View {
        let audioLevels: [Float]
        let isRecording: Bool
        
        var body: some View {
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<audioLevels.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isRecording ? ThemeColors.accent : ThemeColors.secondaryText)
                        .frame(width: 3, height: CGFloat(audioLevels[index] * 50 + 4))
                        .animation(.easeInOut(duration: 0.1), value: audioLevels[index])
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Data Models
    
    enum VoiceCloningStep: Int, CaseIterable {
        case introduction = 0
        case preparation = 1
        case recording = 2
        case processing = 3
        case completion = 4
    }
    
    // MARK: - View Model
    
    // MARK: - Environment Quality Assessment
    enum EnvironmentQuality: CaseIterable {
        case unknown
        case analyzing
        case excellent    // < 15dB noise floor, minimal interference
        case good         // 15-25dB noise floor, slight background noise
        case acceptable   // 25-35dB noise floor, moderate background noise
        case noisy        // 35-45dB noise floor, significant interference
        case poor         // > 45dB noise floor, unsuitable for recording
        
        var title: String {
            switch self {
            case .unknown: return "Unknown"
            case .analyzing: return "Analyzing..."
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .acceptable: return "Acceptable"
            case .noisy: return "Noisy"
            case .poor: return "Poor"
            }
        }
        
        var description: String {
            switch self {
            case .unknown: return "Environment not assessed"
            case .analyzing: return "Analyzing ambient noise levels"
            case .excellent: return "Perfect recording conditions"
            case .good: return "Very good recording conditions"
            case .acceptable: return "Acceptable with some background noise"
            case .noisy: return "High background noise detected"
            case .poor: return "Too noisy for quality recording"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .analyzing: return .blue
            case .excellent: return .green
            case .good: return Color(hex: "34C759") // Light green
            case .acceptable: return .orange
            case .noisy: return Color(hex: "FF9500") // Dark orange
            case .poor: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .unknown: return "questionmark.circle"
            case .analyzing: return "waveform.badge.magnifyingglass"
            case .excellent: return "checkmark.circle.fill"
            case .good: return "checkmark.circle"
            case .acceptable: return "exclamationmark.triangle"
            case .noisy: return "speaker.wave.2.fill"
            case .poor: return "speaker.wave.3.fill"
            }
        }
    }
    
    @MainActor
    class VoiceCloningViewModel: ObservableObject {
        @Published var currentStep: VoiceCloningStep = .introduction
        @Published var hasMicrophonePermission = false
        @Published var environmentIsQuiet = false
        @Published var isRecording = false
        @Published var hasRecording = false
        @Published var recordingProgress: Double = 0.0
        @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 50)
        @Published var showingError = false
        @Published var errorMessage = ""
        @Published var showSuccessAnimation = false
        @Published var isTestingVoice = false
        @Published var isPlayingAudio = false
        @Published var voiceTestCompleted = false
        @Published var customVoiceName: String = ""
        @Published var isProcessing = false
        @Published var processingProgress: Double = 0.0
        @Published var processingMessage = ""
        @Published var processingError: VoiceCloningError?
        @Published var needsReRecording = false
        
        // Noise Analysis properties
        @Published var currentNoiseLevel: Float = 0.0
        @Published var noiseAnalysisProgress: Double = 0.0
        @Published var environmentQuality: EnvironmentQuality = .unknown
        
        private var audioRecorder: AVAudioRecorder?
        private var audioSession = AVAudioSession.sharedInstance()
        private var recordingTimer: Timer?
        private var levelTimer: Timer?
        private var recordingURL: URL?
        private var currentAudioPlayer: AVAudioPlayer?
        
        // Advanced noise detection properties
        private var environmentMonitor: AVAudioRecorder?
        private var noiseAnalysisTimer: Timer?
        private var noiseSamples: [Float] = []
        private var analysisStartTime: Date?
        private let analysisWindow: TimeInterval = 3.0 // 3 seconds of analysis
        private let sampleRate: Double = 44100.0
        private var fftSetup: FFTSetup?
        private var environmentCheckRetryCount = 0
        private let maxEnvironmentCheckRetries = 2
        
        // MARK: - Public Methods
        
        let recordingScript = """
    Hello, this is my voice for EmotiQ. I'm creating this sample to help with my emotional wellness journey. I want to hear encouraging words in my own voice when I need support. This technology will help me practice self-compassion and build emotional resilience. I'm excited to use this personalized coaching feature to improve my emotional state and wellbeing.
    """
        
        var canProceed: Bool {
            hasMicrophonePermission && environmentIsQuiet
        }
        
        var isVoiceNameValid: Bool {
            !customVoiceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        var recordingTimeText: String {
            let minutes = Int(recordingProgress * 60) / 60
            let seconds = Int(recordingProgress * 60) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        init() {
            checkMicrophonePermission()
        }
        
        deinit {
            // Clean up resources
            noiseAnalysisTimer?.invalidate()
            environmentMonitor?.stop()
            audioRecorder?.stop()
            
            // Properly deactivate audio session to prevent conflicts
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
            
            if let fft = fftSetup {
                vDSP_destroy_fftsetup(fft)
            }
        }
        
        func setupAudioSession() {
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default)
                try audioSession.setActive(true)
            } catch {
                showUserFriendlyError(.audioSessionSetup)
            }
        }
        
        func nextStep() {
            if let nextStep = VoiceCloningStep(rawValue: currentStep.rawValue + 1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = nextStep
                }
            }
        }
        
        func startRecording() {
            guard !isRecording else { return }
            
            // Reset the re-recording flag when starting a new recording
            needsReRecording = false
            
            // Setup audio session for recording
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true)
            } catch {
                showUserFriendlyError(.audioSessionSetup)
                return
            }
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            recordingURL = documentsPath.appendingPathComponent("voice_sample.m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            do {
                audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
                audioRecorder?.isMeteringEnabled = true
                audioRecorder?.record()
                
                isRecording = true
                hasRecording = true
                
                startTimers()
                HapticManager.shared.impact(.medium)
                
            } catch {
                showUserFriendlyError(.audioSessionSetup)
            }
        }
        
        func stopRecording() {
            guard isRecording else { return }
            
            audioRecorder?.stop()
            isRecording = false
            
            stopTimers()
            HapticManager.shared.impact(.light)
            
            // Clean up audio session after recording
            cleanupAudioSession()
        }
        
        func resetRecording() {
            stopRecording()
            recordingProgress = 0.0
            hasRecording = false
            audioLevels = Array(repeating: 0.0, count: 50)
        }
        
        func processVoiceCloning() {
            guard let recordingURL = recordingURL else {
                showUserFriendlyError(.noRecordingFound)
                return
            }
            
            isProcessing = true
            processingProgress = 0.0
            processingMessage = "Preparing your voice sample..."
            processingError = nil
            
            Task {
                do {
                    // Use custom name or fallback to default
                    let voiceName = customVoiceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "EmotiQ User Voice" : customVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Step 1: Preparing (0% to 15%)
                    await MainActor.run {
                        processingProgress = 0.15
                        processingMessage = "Preparing your voice sample..."
                    }
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    // Step 2: Uploading (15% to 45%)
                    await MainActor.run {
                        processingProgress = 0.45
                        processingMessage = "Uploading your voice sample..."
                    }
                    
                    let _ = try await ElevenLabsService.shared.cloneVoice(from: recordingURL, name: voiceName)
                    
                    // Step 3: Processing (45% to 75%)
                    await MainActor.run {
                        processingProgress = 0.75
                        processingMessage = "Creating your voice profile..."
                    }
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    // Step 4: Finalizing (75% to 100%)
                    await MainActor.run {
                        processingProgress = 0.9
                        processingMessage = "Finalizing your voice profile..."
                    }
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    await MainActor.run {
                        processingProgress = 1.0
                        processingMessage = "Voice profile created successfully!"
                        isProcessing = false
                        processingError = nil
                        nextStep()
                    }
                    
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        let userFriendlyError = mapErrorToUserFriendly(error)
                        processingError = userFriendlyError
                        processingMessage = userFriendlyError.localizedDescription
                        
                        // Log technical error for debugging
                        if Config.isDebugMode {
                            print("❌ Voice cloning technical error: \(error)")
                        }
                    }
                }
            }
        }
        
        func stopAudio() {
            currentAudioPlayer?.stop()
            currentAudioPlayer = nil
            isPlayingAudio = false
            voiceTestCompleted = false
            HapticManager.shared.impact(.light)
        }
        
        func testVoice() {
            isTestingVoice = true
            isPlayingAudio = false
            voiceTestCompleted = false
            
            Task {
                do {
                    // Get the voice ID from the successful cloning
                    guard let voiceProfile = ElevenLabsService.shared.userVoiceProfile else {
                        await MainActor.run {
                            isTestingVoice = false
                            isPlayingAudio = false
                            showUserFriendlyError(.noVoiceProfileFound)
                        }
                        return
                    }
                    
                    let testText = "Hello! This is your personalized voice speaking. You're doing great on your emotional wellness journey."
                    
                    if Config.isDebugMode {
                        print("🎤 Testing voice with ID: \(voiceProfile.id)")
                        print("📝 Test text: \(testText)")
                    }
                    
                    // Generate speech using the cloned voice ID
                    let audioURL = try await ElevenLabsService.shared.generateSpeech(
                        text: testText,
                        emotion: .joy,
                        speed: 0.9,
                        stability: 0.8
                    )
                    
                    await MainActor.run {
                        isTestingVoice = false
                        isPlayingAudio = true
                    }
                    
                    // Play the generated audio with proper lifecycle management
                    let player = try AVAudioPlayer(contentsOf: audioURL)
                    currentAudioPlayer = player
                    player.delegate = AudioPlayerDelegate { [weak self] success in
                        DispatchQueue.main.async {
                            self?.isPlayingAudio = false
                            self?.currentAudioPlayer = nil
                            if success {
                                self?.voiceTestCompleted = true
                                HapticManager.shared.notification(.success)
                            }
                        }
                    }
                    
                    player.prepareToPlay()
                    player.play()
                    
                    if Config.isDebugMode {
                        print("✅ Voice test audio playing successfully")
                    }
                    
                } catch {
                    await MainActor.run {
                        isTestingVoice = false
                        isPlayingAudio = false
                        if Config.isDebugMode {
                            print("❌ Voice test failed: \(error)")
                        }
                        handleVoiceTestError(error)
                    }
                }
            }
        }
        
        func retryRecording() {
            // Reset processing state
            isProcessing = false
            processingProgress = 0.0
            processingMessage = ""
            processingError = nil
            
            // Set flag to indicate user needs to re-record
            needsReRecording = true
            
            // Go back to recording step (step 3) where there's already a re-record button
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = .recording
            }
        }
        
        private func handleVoiceTestError(_ error: Error) {
            // Log the technical error for debugging
            if Config.isDebugMode {
                print("❌ Voice test technical error: \(error)")
            }
            
            // Map technical errors to user-friendly messages
            let userFriendlyError: VoiceCloningError
            
            if let elevenLabsError = error as? ElevenLabsError {
                switch elevenLabsError {
                case .networkError:
                    userFriendlyError = .networkConnection
                case .quotaExceeded:
                    userFriendlyError = .serviceUnavailable
                default:
                    userFriendlyError = .testFailed
                }
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    userFriendlyError = .networkConnection
                case .timedOut:
                    userFriendlyError = .timeout
                default:
                    userFriendlyError = .testFailed
                }
            } else {
                userFriendlyError = .testFailed
            }
            
            showUserFriendlyError(userFriendlyError)
        }
        
        private func startTimers() {
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    self.recordingProgress = min(self.recordingProgress + 0.1/60.0, 1.0)
                    
                    if self.recordingProgress >= 1.0 {
                        self.stopRecording()
                    }
                }
            }
            
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task { @MainActor in
                    self.updateAudioLevels()
                }
            }
        }
        
        private func stopTimers() {
            recordingTimer?.invalidate()
            levelTimer?.invalidate()
            recordingTimer = nil
            levelTimer = nil
        }
        
        private func updateAudioLevels() {
            guard let recorder = audioRecorder, isRecording else { return }
            
            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)
            let normalizedLevel = max(0.0, (level + 60.0) / 60.0) // Normalize -60dB to 0dB to 0.0 to 1.0
            
            // Shift array and add new level
            audioLevels.removeFirst()
            audioLevels.append(normalizedLevel)
        }
        
        private func checkMicrophonePermission() {
            switch audioSession.recordPermission {
            case .granted:
                let wasPermissionGranted = hasMicrophonePermission
                hasMicrophonePermission = true
                // Only check environment if permission status just changed to granted
                if !wasPermissionGranted {
                    checkEnvironment()
                }
            case .denied:
                hasMicrophonePermission = false
                showUserFriendlyError(.microphonePermission)
            case .undetermined:
                audioSession.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        self.hasMicrophonePermission = granted
                        if granted {
                            self.checkEnvironment() // Only check environment after permission is granted
                        } else {
                            self.showUserFriendlyError(.microphonePermission)
                        }
                    }
                }
            @unknown default:
                hasMicrophonePermission = false
                showUserFriendlyError(.microphonePermission)
            }
        }
        
        private func checkEnvironment() {
            // Start advanced noise analysis
            beginAdvancedNoiseAnalysis()
        }
        
        // MARK: - Advanced Environment Noise Detection Algorithm
        
        private func beginAdvancedNoiseAnalysis() {
            guard hasMicrophonePermission else {
                checkMicrophonePermission()
                return
            }
            
            // Clean up any existing audio session before starting new analysis
            cleanupAudioSession()
            
            do {
                // Setup audio session for monitoring
                try audioSession.setCategory(.record, mode: .measurement, options: [])
                try audioSession.setActive(true)
                
                // Setup environment monitoring recorder
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let tempURL = documentsPath.appendingPathComponent("environment_monitor.caf")
                
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVSampleRateKey: sampleRate,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
                ]
                
                environmentMonitor = try AVAudioRecorder(url: tempURL, settings: settings)
                environmentMonitor?.isMeteringEnabled = true
                environmentMonitor?.prepareToRecord()
                environmentMonitor?.record()
                
                // Initialize FFT setup for frequency analysis
                fftSetup = vDSP_create_fftsetup(12, FFTRadix(kFFTRadix2)) // 2^12 = 4096 samples
                
                // Reset analysis variables
                noiseSamples.removeAll()
                analysisStartTime = Date()
                noiseAnalysisProgress = 0.0
                environmentQuality = .analyzing
                
                // Start analysis timer
                startNoiseAnalysisTimer()
                
            } catch {
                // Log the specific error for debugging
                if Config.isDebugMode {
                    print("❌ Audio session setup failed: \(error)")
                }
                
                // Try to retry if we haven't exceeded max retries
                if environmentCheckRetryCount < maxEnvironmentCheckRetries {
                    environmentCheckRetryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.retryEnvironmentCheck()
                    }
                } else {
                    // Max retries exceeded, show error to user
                    showUserFriendlyError(.audioSessionSetup)
                }
            }
        }
        
        private func startNoiseAnalysisTimer() {
            noiseAnalysisTimer?.invalidate()
            noiseAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.performNoiseAnalysis()
                }
            }
        }
        
        private func performNoiseAnalysis() {
            guard let monitor = environmentMonitor,
                  let startTime = analysisStartTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            noiseAnalysisProgress = min(elapsed / analysisWindow, 1.0)
            
            // Update metering
            monitor.updateMeters()
            let currentLevel = monitor.averagePower(forChannel: 0)
            let normalizedLevel = pow(10.0, currentLevel / 20.0) // Convert dB to linear scale
            
            currentNoiseLevel = normalizedLevel
            noiseSamples.append(normalizedLevel)
            
            // Complete analysis after window period
            if elapsed >= analysisWindow {
                completeNoiseAnalysis()
            }
        }
        
        private func completeNoiseAnalysis() {
            noiseAnalysisTimer?.invalidate()
            environmentMonitor?.stop()
            
            // Perform advanced statistical analysis
            let analysisResult = analyzeEnvironmentQuality()
            
            Task { @MainActor in
                environmentQuality = analysisResult
                environmentIsQuiet = (analysisResult == .excellent || analysisResult == .good)
                
                // Cleanup
                try? FileManager.default.removeItem(at: environmentMonitor?.url ?? URL(fileURLWithPath: ""))
                
                // Deactivate audio session after environment analysis is complete
                cleanupAudioSession()
            }
        }
        
        private func analyzeEnvironmentQuality() -> EnvironmentQuality {
            guard !noiseSamples.isEmpty else { return .poor }
            
            // 1. Calculate RMS (Root Mean Square) for overall noise level
            let rmsLevel = calculateRMS(samples: noiseSamples)
            
            // 2. Calculate statistical measures
            let mean = noiseSamples.reduce(0, +) / Float(noiseSamples.count)
            let variance = noiseSamples.map { pow($0 - mean, 2) }.reduce(0, +) / Float(noiseSamples.count)
            let standardDeviation = sqrt(variance)
            
            // 3. Detect sudden noise spikes
            let spikeThreshold = mean + (2.0 * standardDeviation)
            let spikes = noiseSamples.filter { $0 > spikeThreshold }
            let spikeRatio = Float(spikes.count) / Float(noiseSamples.count)
            
            // 4. Calculate noise floor consistency
            let consistencyScore = 1.0 - (standardDeviation / max(mean, 0.001))
            
            // 5. Frequency domain analysis (simplified)
            let frequencyScore = analyzeFrequencySpectrum()
            
            // 6. Advanced scoring algorithm
            let noiseScore = calculateAdvancedNoiseScore(
                rmsLevel: rmsLevel,
                spikeRatio: spikeRatio,
                consistencyScore: consistencyScore,
                frequencyScore: frequencyScore
            )
            
            // 7. Determine environment quality based on composite score
            return determineEnvironmentQuality(score: noiseScore)
        }
        
        private func calculateRMS(samples: [Float]) -> Float {
            let sumOfSquares = samples.map { $0 * $0 }.reduce(0, +)
            return sqrt(sumOfSquares / Float(samples.count))
        }
        
        private func analyzeFrequencySpectrum() -> Float {
            guard noiseSamples.count >= 1024, let fft = fftSetup else { return 0.5 }
            
            // Take a representative sample for FFT analysis
            let sampleSize = 1024
            let samples = Array(noiseSamples.suffix(sampleSize))
            
            // Prepare data for FFT
            var realParts = samples
            var imaginaryParts = Array(repeating: Float(0.0), count: sampleSize)
            
            // Use withUnsafeMutableBufferPointer and capture the result
            return realParts.withUnsafeMutableBufferPointer { realBuffer in
                imaginaryParts.withUnsafeMutableBufferPointer { imagBuffer in
                    var splitComplex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                    
                    // Perform FFT
                    let log2n = vDSP_Length(log2(Float(sampleSize)))
                    vDSP_fft_zip(fft, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    // Calculate magnitude spectrum
                    var magnitudes = Array(repeating: Float(0.0), count: sampleSize/2)
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(sampleSize/2))
                    
                    // Analyze frequency distribution
                    let lowFreqEnd = sampleSize / 8     // ~5.5kHz
                    let midFreqEnd = sampleSize / 4     // ~11kHz
                    
                    let lowFreqEnergy = magnitudes[0..<lowFreqEnd].reduce(0, +)
                    let midFreqEnergy = magnitudes[lowFreqEnd..<midFreqEnd].reduce(0, +)
                    let highFreqEnergy = magnitudes[midFreqEnd..<(sampleSize/2)].reduce(0, +)
                    
                    let totalEnergy = lowFreqEnergy + midFreqEnergy + highFreqEnergy
                    
                    // Good recording environment has balanced frequency response
                    // Penalize excessive low-frequency noise (HVAC, traffic) and high-frequency noise (electronics)
                    if totalEnergy > 0 {
                        let lowRatio = lowFreqEnergy / totalEnergy
                        let highRatio = highFreqEnergy / totalEnergy
                        
                        // Ideal: low ratio < 0.4, high ratio < 0.3
                        let frequencyPenalty = max(0, lowRatio - 0.4) + max(0, highRatio - 0.3)
                        return max(0, 1.0 - frequencyPenalty * 2.0)
                    }
                    
                    return 0.5
                }
            }
        }
        
        private func calculateAdvancedNoiseScore(
            rmsLevel: Float,
            spikeRatio: Float,
            consistencyScore: Float,
            frequencyScore: Float
        ) -> Float {
            // Optimal thresholds based on audio engineering best practices
            let optimalRMS: Float = 0.001    // Very quiet background
            let maxAcceptableRMS: Float = 0.01   // Still acceptable
            
            // RMS scoring (0-1, where 1 is best)
            let rmsScore: Float
            if rmsLevel <= optimalRMS {
                rmsScore = 1.0
            } else if rmsLevel <= maxAcceptableRMS {
                rmsScore = 1.0 - ((rmsLevel - optimalRMS) / (maxAcceptableRMS - optimalRMS)) * 0.3
            } else {
                rmsScore = max(0, 0.7 - (rmsLevel - maxAcceptableRMS) * 10)
            }
            
            // Spike penalty (sudden loud noises are bad)
            let spikeScore = max(0, 1.0 - spikeRatio * 3.0)
            
            // Consistency bonus (steady background is better than fluctuating)
            let consistencyBonus = max(0, min(1.0, consistencyScore))
            
            // Weighted composite score
            let weights: (rms: Float, spike: Float, consistency: Float, frequency: Float) = (0.4, 0.3, 0.2, 0.1)
            
            let compositeScore = (rmsScore * weights.rms) +
            (spikeScore * weights.spike) +
            (consistencyBonus * weights.consistency) +
            (frequencyScore * weights.frequency)
            
            return max(0, min(1.0, compositeScore))
        }
        
        private func determineEnvironmentQuality(score: Float) -> EnvironmentQuality {
            switch score {
            case 0.85...1.0:
                return .excellent
            case 0.7..<0.85:
                return .good
            case 0.5..<0.7:
                return .acceptable
            case 0.3..<0.5:
                return .noisy
            default:
                return .poor
            }
        }
        
        func retryEnvironmentCheck() {
            environmentQuality = .unknown
            environmentIsQuiet = false
            noiseAnalysisProgress = 0.0
            environmentCheckRetryCount = 0 // Reset retry count
            
            // Clean up any existing audio session before retrying
            cleanupAudioSession()
            
            checkEnvironment()
        }
        
        private func showError(_ message: String) {
            errorMessage = message
            showingError = true
        }
        
        private func showUserFriendlyError(_ error: VoiceCloningError) {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        func cleanupAudioSession() {
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
        }
        
        private func mapErrorToUserFriendly(_ error: Error) -> VoiceCloningError {
            if let elevenLabsError = error as? ElevenLabsError {
                switch elevenLabsError {
                case .networkError:
                    return .networkConnection
                case .quotaExceeded:
                    return .serviceUnavailable
                case .audioTooShort:
                    return .recordingTooShort
                case .audioTooLong:
                    return .recordingTooLong
                case .lowAudioQuality:
                    return .poorAudioQuality
                case .invalidAudioFormat:
                    return .invalidAudioFormat
                default:
                    return .processingFailed
                }
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    return .networkConnection
                case .timedOut:
                    return .timeout
                default:
                    return .processingFailed
                }
            } else {
                return .processingFailed
            }
        }
    }
}

#Preview {
    VoiceCloningSetupView()
        .environmentObject(ThemeManager())
}

