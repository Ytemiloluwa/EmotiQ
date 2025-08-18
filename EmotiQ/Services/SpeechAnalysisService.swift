//
//  SpeechAnalysisService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import Speech
import NaturalLanguage
import AVFoundation
import Combine

/// Production service for speech-to-text transcription and sentiment-based emotion analysis
@MainActor
class SpeechAnalysisService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAnalyzing = false
    @Published var speechRecognitionError: SpeechAnalysisError?
    @Published var lastTranscription: String = ""
    @Published var lastSentiment: String = ""
    
    // MARK: - Private Properties
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])
    private let emotionAnalyzer = NLTagger(tagSchemes: [.lexicalClass, .nameType])
    
    // MARK: - Configuration
    private struct Config {
        static let maxTranscriptionTime: TimeInterval = 30.0
        static let confidenceThreshold: Float = 0.6
        static let minWordCount: Int = 3
        static let speechTimeout: TimeInterval = 2.0
    }
    
    // MARK: - Initialization
    init() {
        // Initialize speech recognizer with user's preferred language
        guard let recognizer = SFSpeechRecognizer() else {
            fatalError("Speech recognizer not available for current locale")
        }
        
        self.speechRecognizer = recognizer
        self.speechRecognizer.defaultTaskHint = .dictation
        
        // Configure sentiment analyzer (no range needed for initialization)
        sentimentAnalyzer.setLanguage(.english, range: Range<String.Index>(uncheckedBounds: (lower: "".startIndex, upper: "".startIndex)))
        emotionAnalyzer.setLanguage(.english, range: Range<String.Index>(uncheckedBounds: (lower: "".startIndex, upper: "".startIndex)))
        
        print("✅ SpeechAnalysisService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Analyzes emotion from audio file using speech-to-text and natural language processing
    func analyzeEmotionFromSpeech(audioURL: URL) async throws -> SpeechEmotionResult {
        print("🎤 Starting speech-based emotion analysis for: \(audioURL.lastPathComponent)")
        
        // Request speech recognition permission
        try await requestSpeechRecognitionPermission()
        
        // Transcribe audio to text
        let transcription = try await transcribeAudio(from: audioURL)
        
        // Analyze sentiment and emotion from text
        let emotionResult = try await analyzeTextEmotion(text: transcription.formattedString)
        
        print("✅ Speech analysis completed. Emotion: \(emotionResult.primaryEmotion), Confidence: \(emotionResult.confidence)")
        
        return emotionResult
    }
    
    /// Analyzes emotion from live audio stream during recording
    /// NOTE: Temporarily disabled due to local speech recognition issues
    func startLiveSpeechAnalysis() async throws -> AsyncStream<SpeechEmotionResult> {
        print("🎤 Live speech analysis temporarily disabled...")
        
        // TEMPORARY: Return empty stream to prevent local speech errors
        // This will be re-enabled once we resolve the local speech recognition issues
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    /// Stops live speech analysis
    func stopLiveSpeechAnalysis() {
        print("⏹️ Stopping live speech analysis...")
        
        // TEMPORARY: Safe cleanup since live recognition is disabled
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        isAnalyzing = false
    }
    
    // MARK: - Private Methods
    
    /// Requests speech recognition permission from user
    func requestSpeechRecognitionPermission() async throws {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch authStatus {
        case .authorized:
            return
        case .denied, .restricted:
            throw SpeechAnalysisError.permissionDenied
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            
            if !granted {
                throw SpeechAnalysisError.permissionDenied
            }
        @unknown default:
            throw SpeechAnalysisError.recognitionUnavailable
        }
    }
    
    /// Transcribes audio file to text using Speech framework
    private func transcribeAudio(from url: URL) async throws -> SFTranscription {
        guard speechRecognizer.isAvailable else {
            throw SpeechAnalysisError.recognitionUnavailable
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false // Use server for better accuracy
        
        return try await withCheckedThrowingContinuation { continuation in
            recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: SpeechAnalysisError.recognitionFailed(error.localizedDescription))
                    return
                }
                
                guard let result = result, result.isFinal else { return }
                
                self.lastTranscription = result.bestTranscription.formattedString
                continuation.resume(returning: result.bestTranscription)
            }
        }
    }
    
    /// Starts live speech recognition with callback for partial results
    /// NOTE: Temporarily disabled due to local speech recognition issues
    private func startLiveRecognition(onTranscription: @escaping (String) -> Void) async throws {
        // TEMPORARY: Disable live recognition to prevent local speech errors
        // This will be re-enabled once we resolve the local speech recognition issues
        throw SpeechAnalysisError.recognitionUnavailable
    }
    
    /// Analyzes emotion from transcribed text using Natural Language framework
    private func analyzeTextEmotion(text: String) async throws -> SpeechEmotionResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpeechAnalysisError.noSpeechDetected
        }
        
        // Ensure minimum word count for reliable analysis
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        guard wordCount >= Config.minWordCount else {
            throw SpeechAnalysisError.insufficientSpeech
        }
        
        // Analyze sentiment using NLTagger
        let sentiment = analyzeSentiment(text: text)
        
        // Analyze emotional keywords and context
        let emotionalKeywords = analyzeEmotionalKeywords(text: text)
        
        // Combine sentiment and keyword analysis for final emotion
        let emotionResult = combineEmotionAnalysis(
            sentiment: sentiment,
            keywords: emotionalKeywords,
            originalText: text
        )
        
        lastSentiment = sentiment.description
        
        return emotionResult
    }
    
    /// Analyzes sentiment polarity using Natural Language framework
    private func analyzeSentiment(text: String) -> SentimentResult {
        sentimentAnalyzer.string = text
        
        let (sentiment, _) = sentimentAnalyzer.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        guard let sentiment = sentiment,
              let sentimentScore = Double(sentiment.rawValue) else {
            return SentimentResult(polarity: .neutral, confidence: 0.0)
        }
        
        let polarity: SentimentPolarity
        let confidence = abs(sentimentScore)
        
        if sentimentScore > 0.1 {
            polarity = .positive
        } else if sentimentScore < -0.1 {
            polarity = .negative
        } else {
            polarity = .neutral
        }
        
        return SentimentResult(polarity: polarity, confidence: confidence)
    }
    
    /// Analyzes emotional keywords and context in the text
    private func analyzeEmotionalKeywords(text: String) -> [EmotionalKeyword] {
        let lowercaseText = text.lowercased()
        var keywords: [EmotionalKeyword] = []
        
        // Define comprehensive emotion-specific keywords with weights
        let emotionKeywords: [EmotionCategory: [(word: String, weight: Double)]] = [
            .joy: [
                // Core happiness words
                ("happy", 0.9), ("excited", 0.8), ("great", 0.7), ("amazing", 0.9),
                ("wonderful", 0.8), ("fantastic", 0.9), ("awesome", 0.8), ("love", 0.8),
                ("thrilled", 0.9), ("delighted", 0.8), ("pleased", 0.7), ("cheerful", 0.8),
                // Extended joy words
                ("joyful", 0.9), ("ecstatic", 0.9), ("elated", 0.9), ("euphoric", 0.8),
                ("blissful", 0.8), ("content", 0.7), ("glad", 0.7), ("overjoyed", 0.9),
                ("radiant", 0.8), ("beaming", 0.8), ("gleeful", 0.8), ("jubilant", 0.8),
                ("merry", 0.7), ("upbeat", 0.7), ("optimistic", 0.7), ("bright", 0.6),
                ("sunny", 0.6), ("positive", 0.7), ("energetic", 0.7), ("vibrant", 0.7),
                ("lively", 0.7), ("spirited", 0.7), ("buoyant", 0.7), ("exuberant", 0.8),
                ("celebrate", 0.8), ("celebration", 0.8), ("party", 0.6), ("fun", 0.7),
                ("enjoy", 0.7), ("smile", 0.7), ("laugh", 0.7), ("laughing", 0.8),
                ("grin", 0.7), ("beam", 0.7), ("shine", 0.6), ("sparkle", 0.6)
            ],
            .sadness: [
                // Core sadness words
                ("sad", 0.9), ("depressed", 0.9), ("unhappy", 0.8), ("miserable", 0.9),
                ("down", 0.7), ("upset", 0.8), ("disappointed", 0.8), ("hurt", 0.8),
                ("broken", 0.8), ("crying", 0.9), ("tears", 0.8), ("lonely", 0.8),
                // Extended sadness words
                ("melancholy", 0.8), ("sorrowful", 0.9), ("mournful", 0.8), ("dejected", 0.8),
                ("despondent", 0.9), ("heartbroken", 0.9), ("devastated", 0.9), ("grief", 0.9),
                ("gloomy", 0.7), ("blue", 0.6), ("weeping", 0.9), ("sobbing", 0.9),
                ("mourning", 0.8), ("anguish", 0.9), ("despair", 0.9), ("hopeless", 0.8),
                ("discouraged", 0.7), ("dismayed", 0.7), ("disheartened", 0.8), ("forlorn", 0.8),
                ("woeful", 0.8), ("doleful", 0.8), ("cheerless", 0.7), ("downcast", 0.7),
                ("crestfallen", 0.8), ("low", 0.6), ("dark", 0.6), ("heavy", 0.6),
                ("empty", 0.7), ("hollow", 0.7), ("lost", 0.7), ("abandoned", 0.8),
                ("isolated", 0.7), ("withdrawn", 0.7), ("sullen", 0.7), ("morose", 0.8)
            ],
            .anger: [
                // Core anger words
                ("angry", 0.9), ("mad", 0.8), ("furious", 0.9), ("rage", 0.9),
                ("irritated", 0.7), ("annoyed", 0.7), ("frustrated", 0.8), ("hate", 0.9),
                ("pissed", 0.8), ("livid", 0.9), ("outraged", 0.9), ("bitter", 0.8),
                // Extended anger words
                ("enraged", 0.9), ("irate", 0.9), ("incensed", 0.9), ("seething", 0.9),
                ("wrathful", 0.9), ("indignant", 0.8), ("resentful", 0.8), ("hostile", 0.8),
                ("aggravated", 0.8), ("agitated", 0.7), ("infuriated", 0.9), ("steaming", 0.8),
                ("boiling", 0.8), ("burning", 0.7), ("explosive", 0.8), ("volcanic", 0.8),
                ("violent", 0.8), ("fierce", 0.7), ("savage", 0.8), ("brutal", 0.8),
                ("vicious", 0.8), ("cruel", 0.8), ("mean", 0.7), ("nasty", 0.7),
                ("spiteful", 0.8), ("malicious", 0.8), ("vindictive", 0.8), ("vengeful", 0.8),
                ("loathe", 0.9), ("detest", 0.9), ("despise", 0.9), ("abhor", 0.9),
                ("contempt", 0.8), ("scorn", 0.8), ("disdain", 0.7), ("disgusted", 0.8)
            ],
            .fear: [
                // Core fear words
                ("scared", 0.9), ("afraid", 0.9), ("terrified", 0.9), ("anxious", 0.8),
                ("worried", 0.7), ("nervous", 0.7), ("panic", 0.9), ("frightened", 0.9),
                ("concerned", 0.6), ("stressed", 0.8), ("overwhelmed", 0.8), ("tense", 0.7),
                // Extended fear words
                ("fearful", 0.9), ("petrified", 0.9), ("horrified", 0.9), ("alarmed", 0.8),
                ("apprehensive", 0.7), ("uneasy", 0.6), ("jittery", 0.7), ("jumpy", 0.7),
                ("skittish", 0.7), ("startled", 0.7), ("spooked", 0.8), ("shaken", 0.8),
                ("trembling", 0.8), ("quaking", 0.8), ("cowering", 0.8), ("cringing", 0.7),
                ("dreading", 0.8), ("paranoid", 0.8), ("phobic", 0.8), ("timid", 0.6),
                ("intimidated", 0.7), ("threatened", 0.8), ("vulnerable", 0.7), ("insecure", 0.6),
                ("uncertain", 0.6), ("doubtful", 0.6), ("hesitant", 0.6), ("wary", 0.6),
                ("suspicious", 0.6), ("cautious", 0.5), ("defensive", 0.6), ("guarded", 0.6),
                ("terror", 0.9), ("horror", 0.9), ("fright", 0.8), ("dread", 0.8)
            ],
            .surprise: [
                // Core surprise words
                ("surprised", 0.9), ("shocked", 0.9), ("amazed", 0.8), ("astonished", 0.9),
                ("stunned", 0.9), ("unexpected", 0.7), ("sudden", 0.6), ("wow", 0.7),
                ("incredible", 0.8), ("unbelievable", 0.8), ("remarkable", 0.8),
                // Extended surprise words
                ("astounded", 0.9), ("flabbergasted", 0.9), ("bewildered", 0.8), ("perplexed", 0.7),
                ("confounded", 0.8), ("baffled", 0.7), ("puzzled", 0.6), ("mystified", 0.7),
                ("startling", 0.8), ("striking", 0.7), ("extraordinary", 0.8), ("phenomenal", 0.8),
                ("marvelous", 0.8), ("miraculous", 0.8), ("spectacular", 0.8), ("breathtaking", 0.8),
                ("mind-blowing", 0.9), ("jaw-dropping", 0.9), ("eye-opening", 0.7), ("revealing", 0.6),
                ("curious", 0.6), ("intriguing", 0.6), ("fascinating", 0.7), ("captivating", 0.7),
                ("mesmerizing", 0.7), ("spellbinding", 0.7), ("enchanting", 0.7), ("magical", 0.7),
                ("wonder", 0.8), ("wonderment", 0.8), ("awe", 0.8), ("awestruck", 0.8),
                ("impressed", 0.7), ("overwhelmed", 0.7), ("blown away", 0.8), ("taken aback", 0.7)
            ],
            .disgust: [
                // Core disgust words
                ("disgusted", 0.9), ("sick", 0.8), ("gross", 0.8), ("awful", 0.8),
                ("terrible", 0.8), ("horrible", 0.8), ("nasty", 0.8), ("revolting", 0.9),
                ("repulsive", 0.9), ("disgusting", 0.9), ("vile", 0.9),
                // Extended disgust words
                ("repugnant", 0.9), ("abhorrent", 0.9), ("loathsome", 0.9), ("detestable", 0.9),
                ("abominable", 0.9), ("despicable", 0.9), ("contemptible", 0.8), ("odious", 0.8),
                ("heinous", 0.9), ("atrocious", 0.9), ("appalling", 0.9), ("shocking", 0.8),
                ("outrageous", 0.8), ("scandalous", 0.7), ("shameful", 0.7), ("disgraceful", 0.8),
                ("deplorable", 0.8), ("reprehensible", 0.8), ("inexcusable", 0.7), ("unforgivable", 0.8),
                ("sickening", 0.9), ("nauseating", 0.9), ("stomach-turning", 0.9), ("queasy", 0.7),
                ("putrid", 0.8), ("rotten", 0.8), ("foul", 0.8), ("stench", 0.7),
                ("repulsed", 0.9), ("turned off", 0.7), ("put off", 0.6), ("offended", 0.7),
                ("disturbed", 0.7), ("unsettled", 0.6), ("troubled", 0.6), ("bothered", 0.6)
            ]
        ]
        
        // Scan text for emotional keywords
        for (emotion, wordList) in emotionKeywords {
            for (word, weight) in wordList {
                if lowercaseText.contains(word) {
                    keywords.append(EmotionalKeyword(
                        word: word,
                        emotion: emotion,
                        weight: weight,
                        context: extractContext(for: word, in: text)
                    ))
                }
            }
        }
        
        return keywords
    }
    
    /// Extracts surrounding context for an emotional keyword
    private func extractContext(for keyword: String, in text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        guard let keywordIndex = words.firstIndex(where: { $0.lowercased().contains(keyword.lowercased()) }) else {
            return keyword
        }
        
        let startIndex = max(0, keywordIndex - 2)
        let endIndex = min(words.count - 1, keywordIndex + 2)
        
        return words[startIndex...endIndex].joined(separator: " ")
    }
    
    /// Combines sentiment and keyword analysis for final emotion determination
    private func combineEmotionAnalysis(
        sentiment: SentimentResult,
        keywords: [EmotionalKeyword],
        originalText: String
    ) -> SpeechEmotionResult {
        
        var emotionScores: [EmotionCategory: Double] = [
            .joy: 0.0, .sadness: 0.0, .anger: 0.0,
            .fear: 0.0, .surprise: 0.0, .disgust: 0.0, .neutral: 0.0
        ]
        
        // Base emotion from sentiment
        switch sentiment.polarity {
        case .positive:
            emotionScores[.joy] = sentiment.confidence * 0.6
        case .negative:
            emotionScores[.sadness] = sentiment.confidence * 0.4
            emotionScores[.anger] = sentiment.confidence * 0.3
        case .neutral:
            emotionScores[.neutral] = 0.5
        }
        
        // Add keyword-based emotion scores
        for keyword in keywords {
            emotionScores[keyword.emotion, default: 0.0] += keyword.weight * 0.4
        }
        
        // Determine primary emotion
        let primaryEmotion = emotionScores.max(by: { $0.value < $1.value })?.key ?? .neutral
        let primaryScore = emotionScores[primaryEmotion] ?? 0.0
        
        // Calculate overall confidence
        let keywordConfidence = keywords.isEmpty ? 0.0 : keywords.map { $0.weight }.reduce(0, +) / Double(keywords.count)
        let overallConfidence = min(1.0, (sentiment.confidence + keywordConfidence) / 2.0)
        
        return SpeechEmotionResult(
            transcribedText: originalText,
            primaryEmotion: primaryEmotion,
            emotionScores: emotionScores,
            confidence: overallConfidence,
            sentimentPolarity: sentiment.polarity,
            emotionalKeywords: keywords
        )
    }
}

// MARK: - Supporting Types

struct SpeechEmotionResult {
    let transcribedText: String
    let primaryEmotion: EmotionCategory
    let emotionScores: [EmotionCategory: Double]
    let confidence: Double
    let sentimentPolarity: SentimentPolarity
    let emotionalKeywords: [EmotionalKeyword]
}

struct SentimentResult {
    let polarity: SentimentPolarity
    let confidence: Double
    
    var description: String {
        "\(polarity.rawValue) (\(String(format: "%.1f", confidence * 100))%)"
    }
}

enum SentimentPolarity: String, CaseIterable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
}

struct EmotionalKeyword {
    let word: String
    let emotion: EmotionCategory
    let weight: Double
    let context: String
}

enum SpeechAnalysisError: Error, LocalizedError {
    case permissionDenied
    case recognitionUnavailable
    case recognitionFailed(String)
    case noSpeechDetected
    case insufficientSpeech
    case analysisTimeout
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission is required for advanced emotion analysis."
        case .recognitionUnavailable:
            return "Speech recognition is not available on this device."
        case .recognitionFailed(let message):
            return "Speech recognition failed: \(message)"
        case .noSpeechDetected:
            return "No speech was detected in the audio."
        case .insufficientSpeech:
            return "Insufficient speech detected for reliable emotion analysis."
        case .analysisTimeout:
            return "Speech analysis timed out."
        }
    }
}
