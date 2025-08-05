//
//  AudioProcessingService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation
import Combine
import AVFoundation

protocol AudioProcessingServiceProtocol {
    func recordAudio(duration: TimeInterval) -> AnyPublisher<Data, Error>
    func extractFeatures(from audioData: Data) -> AnyPublisher<AudioFeatures, Error>
}

class AudioProcessingService: NSObject, AudioProcessingServiceProtocol {
    private var audioRecorder: AVAudioRecorder?
    private var recordingSubject = PassthroughSubject<Data, Error>()
    
    func recordAudio(duration: TimeInterval) -> AnyPublisher<Data, Error> {
        return Future { [weak self] promise in
            self?.startRecording(duration: duration, completion: promise)
        }
        .eraseToAnyPublisher()
    }
    
    func extractFeatures(from audioData: Data) -> AnyPublisher<AudioFeatures, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let features = try self.processAudioData(audioData)
                    promise(.success(features))
                } catch {
                    promise(.failure(AudioProcessingError.featureExtractionFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func startRecording(duration: TimeInterval, completion: @escaping (Result<Data, Error>) -> Void) {
        // Request microphone permission using the new API
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else {
                    completion(.failure(AudioProcessingError.permissionDenied))
                    return
                }
                
                DispatchQueue.main.async {
                    self.setupAndStartRecording(duration: duration, completion: completion)
                }
            }
        } else {
            // Fallback for iOS 16 and earlier
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted else {
                    completion(.failure(AudioProcessingError.permissionDenied))
                    return
                }
                
                DispatchQueue.main.async {
                    self.setupAndStartRecording(duration: duration, completion: completion)
                }
            }
        }
    }
    
    private func setupAndStartRecording(duration: TimeInterval, completion: @escaping (Result<Data, Error>) -> Void) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording.m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record(forDuration: duration)
            
            // Schedule completion after recording duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.audioRecorder?.stop()
                
                do {
                    let audioData = try Data(contentsOf: audioFilename)
                    completion(.success(audioData))
                } catch {
                    completion(.failure(AudioProcessingError.recordingFailed))
                }
            }
            
        } catch {
            completion(.failure(AudioProcessingError.recordingFailed))
        }
    }
    
    private func processAudioData(_ audioData: Data) throws -> AudioFeatures {
        // Simulate audio feature extraction
        // In production, this would use actual DSP algorithms
        
        let dataLength = audioData.count
        let normalizedLength = Double(dataLength) / 1000.0 // Normalize to reasonable range
        
        // Simulate feature extraction with some randomness based on data
        let pitch = 150.0 + (normalizedLength * 50.0) + Double.random(in: -20...20)
        let energy = min(1.0, normalizedLength / 10.0) + Double.random(in: -0.1...0.1)
        let tempo = 0.8 + (energy * 0.4) + Double.random(in: -0.1...0.1)
        let spectralCentroid = 1000.0 + (pitch * 2.0) + Double.random(in: -100...100)
        
        // Generate MFCC coefficients (simplified)
        let mfccCoefficients = (0..<13).map { i in
            let base = Double(i) * 0.1
            return base + Double.random(in: -0.05...0.05)
        }
        
        return AudioFeatures(
            pitch: pitch,
            energy: max(0.0, min(1.0, energy)),
            tempo: max(0.5, min(2.0, tempo)),
            spectralCentroid: spectralCentroid,
            mfccCoefficients: mfccCoefficients
        )
    }
}

extension AudioProcessingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            recordingSubject.send(completion: .failure(AudioProcessingError.recordingFailed))
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        recordingSubject.send(completion: .failure(error ?? AudioProcessingError.recordingFailed))
    }
}

struct AudioFeatures {
    let pitch: Double
    let energy: Double
    let tempo: Double
    let spectralCentroid: Double
    let mfccCoefficients: [Double]
}

enum AudioProcessingError: Error, LocalizedError {
    case permissionDenied
    case recordingFailed
    case featureExtractionFailed
    case invalidAudioFormat
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required for voice analysis."
        case .recordingFailed:
            return "Failed to record audio. Please try again."
        case .featureExtractionFailed:
            return "Failed to extract features from audio."
        case .invalidAudioFormat:
            return "Invalid audio format provided."
        }
    }
}


