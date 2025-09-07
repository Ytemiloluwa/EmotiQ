//
//  AudioCacheManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Audio Cache Manager
@MainActor
class AudioCacheManager: ObservableObject {
    static let shared = AudioCacheManager()
    
    @Published var cacheSize: Int64 = 0
    @Published var cachedItemsCount: Int = 0
    @Published var isPreloading = false
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    private var audioCache: [String: CachedAudioItem] = [:]
    private var preloadQueue = DispatchQueue(label: "audio.preload", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // Common affirmations and prompts to preload
    private let commonAffirmations = [
        "I am worthy of love and happiness.",
        "I trust in my ability to handle whatever comes my way.",
        "I am grateful for this moment and all it brings.",
        "I choose peace over worry in every situation.",
        "I am strong, capable, and resilient.",
        "I deserve good things in my life.",
        "I am exactly where I need to be right now.",
        "I release what I cannot control and focus on what I can.",
        "I am growing and learning every day.",
        "I treat myself with kindness and compassion."
    ]
    
    private let commonPrompts = [
        "Take a deep breath in for 4 counts.",
        "Hold your breath for 4 counts.",
        "Exhale slowly for 6 counts.",
        "Let's begin with a moment of mindfulness.",
        "Notice how you're feeling right now.",
        "What are you grateful for in this moment?",
        "How can you show yourself compassion today?",
        "What would you tell a good friend in this situation?",
        "Let's focus on the present moment.",
        "You are safe and supported right now."
    ]
    
    private init() {
        // Create cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("AudioCache")
        
        createCacheDirectoryIfNeeded()
        loadCacheIndex()
        cleanupExpiredCache()
        calculateCacheSize()
        
        // Start preloading common content
        // Task {
        //     await preloadCommonContent()
        // }
    }
    
    // MARK: - Cache Management
    
    /// Get cached audio URL for given text and voice parameters
    func getCachedAudio(for text: String, emotion: EmotionType, voiceId: String?) -> URL? {
        let cacheKey = generateCacheKey(text: text, emotion: emotion, voiceId: voiceId)
        
        guard let cachedItem = audioCache[cacheKey] else {
            return nil
        }
        
        // Check if file still exists
        guard fileManager.fileExists(atPath: cachedItem.fileURL.path) else {
            // Remove from cache if file is missing
            audioCache.removeValue(forKey: cacheKey)
            saveCacheIndex()
            return nil
        }
        
        // Update last accessed time
        audioCache[cacheKey]?.lastAccessed = Date()
        saveCacheIndex()
        
        return cachedItem.fileURL
    }
    
    /// Cache audio data for given parameters
    func cacheAudio(data: Data, text: String, emotion: EmotionType, voiceId: String?) async throws -> URL {
        let cacheKey = generateCacheKey(text: text, emotion: emotion, voiceId: voiceId)
        let fileName = "\(cacheKey).mp3"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        // Write audio data to file
        try data.write(to: fileURL)
        
        // Create cache item
        let cacheItem = CachedAudioItem(
            key: cacheKey,
            fileURL: fileURL,
            text: text,
            emotion: emotion,
            voiceId: voiceId,
            fileSize: Int64(data.count),
            createdAt: Date(),
            lastAccessed: Date()
        )
        
        // Add to cache
        audioCache[cacheKey] = cacheItem
        
        // Update cache metrics
        await updateCacheMetrics()
        
        // Clean up if cache is too large
        await cleanupCacheIfNeeded()
        
        // Save cache index
        saveCacheIndex()
        
        return fileURL
    }
    
    /// Preload common affirmations and prompts
    func preloadCommonContent() async {
        guard !isPreloading else { return }
        
        isPreloading = true
        defer { isPreloading = false }
        
        let elevenLabsService = ElevenLabsService.shared
        
        // Preload common affirmations
        for affirmation in commonAffirmations {
            // Skip if already cached
            if getCachedAudio(for: affirmation, emotion: .joy, voiceId: nil) != nil {
                continue
            }
            
            do {
                _ = try await elevenLabsService.generateSpeech(
                    text: affirmation,
                    emotion: .joy,
                    speed: 0.9,
                    stability: 0.8
                )
            } catch {
                print("Failed to preload affirmation: \(error)")
            }
            
            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Preload common prompts
        for prompt in commonPrompts {
            if getCachedAudio(for: prompt, emotion: .neutral, voiceId: nil) != nil {
                continue
            }
            
            do {
                _ = try await elevenLabsService.generateSpeech(
                    text: prompt,
                    emotion: .neutral,
                    speed: 0.8,
                    stability: 0.9
                )
            } catch {
                print("Failed to preload prompt: \(error)")
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        await updateCacheMetrics()
    }
    
    /// Clear all cached audio
    func clearCache() async {
        // Remove all files
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("Failed to clear cache: \(error)")
        }
        
        // Clear in-memory cache
        audioCache.removeAll()
        
        // Update metrics
        await updateCacheMetrics()
        
        // Save empty index
        saveCacheIndex()
    }
    
    /// Get cache statistics
    func getCacheStatistics() -> CacheStatistics {
        let totalItems = audioCache.count
        let totalSize = audioCache.values.reduce(0) { $0 + $1.fileSize }
        let oldestItem = audioCache.values.min(by: { $0.createdAt < $1.createdAt })
        let newestItem = audioCache.values.max(by: { $0.createdAt < $1.createdAt })
        
        return CacheStatistics(
            totalItems: totalItems,
            totalSize: totalSize,
            maxSize: maxCacheSize,
            oldestItemDate: oldestItem?.createdAt,
            newestItemDate: newestItem?.createdAt,
            hitRate: calculateHitRate()
        )
    }
    
    // MARK: - Private Methods
    
    private func generateCacheKey(text: String, emotion: EmotionType, voiceId: String?) -> String {
        let baseString = "\(text)_\(emotion.rawValue)_\(voiceId ?? "default")"
        return baseString.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
    }
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create cache directory: \(error)")
            }
        }
    }
    
    private func loadCacheIndex() {
        let indexURL = cacheDirectory.appendingPathComponent("cache_index.json")
        
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let cacheItems = try decoder.decode([CachedAudioItem].self, from: data)
            
            // Rebuild cache dictionary
            for item in cacheItems {
                // Verify file still exists
                if fileManager.fileExists(atPath: item.fileURL.path) {
                    audioCache[item.key] = item
                }
            }
            
        } catch {
            print("Failed to load cache index: \(error)")
        }
    }
    
    private func saveCacheIndex() {
        let indexURL = cacheDirectory.appendingPathComponent("cache_index.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let cacheItems = Array(audioCache.values)
            let data = try encoder.encode(cacheItems)
            
            try data.write(to: indexURL)
        } catch {
            print("Failed to save cache index: \(error)")
        }
    }
    
    private func cleanupExpiredCache() {
        let cutoffDate = Date().addingTimeInterval(-maxCacheAge)
        var itemsToRemove: [String] = []
        
        for (key, item) in audioCache {
            if item.lastAccessed < cutoffDate {
                itemsToRemove.append(key)
                
                // Remove file
                do {
                    try fileManager.removeItem(at: item.fileURL)
                } catch {
                    print("Failed to remove expired cache file: \(error)")
                }
            }
        }
        
        // Remove from cache
        for key in itemsToRemove {
            audioCache.removeValue(forKey: key)
        }
        
        if !itemsToRemove.isEmpty {
            saveCacheIndex()
        }
    }
    
    private func cleanupCacheIfNeeded() async {
        let currentSize = audioCache.values.reduce(0) { $0 + $1.fileSize }
        
        guard currentSize > maxCacheSize else { return }
        
        // Sort by last accessed date (oldest first)
        let sortedItems = audioCache.values.sorted { $0.lastAccessed < $1.lastAccessed }
        
        var sizeToRemove = currentSize - (maxCacheSize * 8 / 10) // Remove until 80% of max size
        var itemsToRemove: [String] = []
        
        for item in sortedItems {
            guard sizeToRemove > 0 else { break }
            
            itemsToRemove.append(item.key)
            sizeToRemove -= item.fileSize
            
            // Remove file
            do {
                try fileManager.removeItem(at: item.fileURL)
            } catch {
                print("Failed to remove cache file during cleanup: \(error)")
            }
        }
        
        // Remove from cache
        for key in itemsToRemove {
            audioCache.removeValue(forKey: key)
        }
        
        if !itemsToRemove.isEmpty {
            saveCacheIndex()
            await updateCacheMetrics()
        }
    }
    
    private func calculateCacheSize() {
        let totalSize = audioCache.values.reduce(0) { $0 + $1.fileSize }
        cacheSize = totalSize
        cachedItemsCount = audioCache.count
    }
    
    private func updateCacheMetrics() async {
        calculateCacheSize()
    }
    
    private func calculateHitRate() -> Double {
        // This would be implemented with actual hit/miss tracking
        // For now, return a placeholder
        return 0.75
    }
}

// MARK: - Data Models

struct CachedAudioItem: Codable {
    let key: String
    let fileURL: URL
    let text: String
    let emotion: EmotionType
    let voiceId: String?
    let fileSize: Int64
    let createdAt: Date
    var lastAccessed: Date
}

struct CacheStatistics {
    let totalItems: Int
    let totalSize: Int64
    let maxSize: Int64
    let oldestItemDate: Date?
    let newestItemDate: Date?
    let hitRate: Double
    
    var usagePercentage: Double {
        return Double(totalSize) / Double(maxSize)
    }
    
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var formattedMaxSize: String {
        return ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file)
    }
}

// MARK: - Audio Player with Caching

// Removed duplicate CachedAudioPlayer class - use the one in CacheAudioPlayer.swift instead
// The CacheAudioPlayer.swift implementation is more complete with:
// - Full AVAudioPlayerDelegate implementation
// - Audio session management
// - Interruption and route change handling
// - Comprehensive haptic feedback
// - Better error handling and memory management

// MARK: - Audio Player Errors

enum AudioPlayerError: LocalizedError {
    case playbackFailed(Error)
    case fileNotFound
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .playbackFailed(let error):
            return "Playback failed: \(error.localizedDescription)"
        case .fileNotFound:
            return "Audio file not found"
        case .invalidFormat:
            return "Invalid audio format"
        }
    }
}


