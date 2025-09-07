//
//  EmotionAnalysisError.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation

// MARK: - Comprehensive Emotion Analysis Error Types
/// Centralized error types for all emotion analysis related operations
enum EmotionAnalysisError: LocalizedError {
    // MARK: - Model Related Errors
    case modelNotLoaded
    case invalidModelOutput
    case invalidModelStructure
    
    // MARK: - Audio Processing Errors
    case audioTooShort
    case audioTooLong
    case invalidAudioFormat
    case audioProcessingFailed
    case invalidAudioData
    case insufficientAudioQuality
    
    // MARK: - Recording Errors
    case recordingFailed
    case permissionDenied
    case microphoneUnavailable
    
    // MARK: - Analysis Errors
    case analysisFailure(String)
    case analysisTimeout
    case serviceUnavailable
    
    // MARK: - File System Errors
    case fileNotFound
    
    // MARK: - Feature Processing Errors
    case invalidFeatureVector(expected: Int, actual: Int)
    case invalidFeatureValues
    
    // MARK: - Network Errors
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Emotion analysis model is not loaded"
        case .invalidModelOutput:
            return "Invalid output from emotion analysis model"
        case .invalidModelStructure:
            return "CoreML model has invalid structure"
        case .audioTooShort:
            return "Audio recording is too short for analysis (minimum 1 second)"
        case .audioTooLong:
            return "Audio recording is too long for analysis (maximum 2 minutes)"
        case .invalidAudioFormat:
            return "Invalid audio format for emotion analysis"
        case .audioProcessingFailed:
            return "Failed to process audio data"
        case .invalidAudioData:
            return "Invalid audio data received"
        case .insufficientAudioQuality:
            return "Audio quality is too low for accurate analysis. Please try recording in a quieter environment"
        case .recordingFailed:
            return "Failed to record audio. Please check microphone permissions"
        case .permissionDenied:
            return "Microphone permission is required for voice analysis"
        case .microphoneUnavailable:
            return "Microphone is unavailable. Please check if another app is using it"
        case .analysisFailure(let message):
            return "Emotion analysis failed: \(message)"
        case .analysisTimeout:
            return "Emotion analysis timed out. Please try again"
        case .serviceUnavailable:
            return "Emotion analysis service is currently unavailable"
        case .fileNotFound:
            return "Audio file not found at the specified URL"
        case .invalidFeatureVector(let expected, let actual):
            return "Invalid feature vector dimensions: expected \(expected), got \(actual)"
        case .invalidFeatureValues:
            return "Feature vector contains invalid values (NaN or infinite)"
        case .networkError:
            return "Network error occurred. Please check your connection and try again"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .modelNotLoaded:
            return "Please restart the app and try again"
        case .invalidModelOutput, .invalidModelStructure:
            return "Please try recording again"
        case .audioTooShort:
            return "Please record for at least 1 second"
        case .audioTooLong:
            return "Please record for no more than 2 minutes"
        case .invalidAudioFormat:
            return "Please use the app's built-in recording feature"
        case .audioProcessingFailed, .invalidAudioData:
            return "Please try recording again in a quieter environment"
        case .insufficientAudioQuality:
            return "Please record in a quieter environment and speak clearly"
        case .recordingFailed:
            return "Please check microphone permissions in Settings"
        case .permissionDenied:
            return "Please enable microphone access in Settings > Privacy & Security > Microphone"
        case .microphoneUnavailable:
            return "Please close other apps that might be using the microphone"
        case .analysisFailure:
            return "Please try again. If the problem persists, contact support"
        case .analysisTimeout:
            return "Please try again with a shorter recording"
        case .serviceUnavailable:
            return "Please try again later"
        case .fileNotFound:
            return "Please try recording again"
        case .invalidFeatureVector, .invalidFeatureValues:
            return "Please try recording again with clearer speech"
        case .networkError:
            return "Please check your internet connection and try again"
        }
    }
    
}
