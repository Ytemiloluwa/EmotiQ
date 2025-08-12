//
//  EmotionType.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation

import Foundation

enum EmotionType: String, CaseIterable, Codable {
    case joy = "joy"
    case sadness = "sadness"
    case anger = "anger"
    case fear = "fear"
    case surprise = "surprise"
    case disgust = "disgust"
    case neutral = "neutral"
    
    var displayName: String {
        switch self {
        case .joy:
            return "Joy"
        case .sadness:
            return "Sadness"
        case .anger:
            return "Anger"
        case .fear:
            return "Fear"
        case .surprise:
            return "Surprise"
        case .disgust:
            return "Disgust"
        case .neutral:
            return "Neutral"
        }
    }
    
    var emoji: String {
        switch self {
        case .joy:
            return "😊"
        case .sadness:
            return "😢"
        case .anger:
            return "😠"
        case .fear:
            return "😨"
        case .surprise:
            return "😲"
        case .disgust:
            return "🤢"
        case .neutral:
            return "😐"
        }
    }
    
    var hexcolor: String {
        switch self {
        case .joy:
            return "#FFD700"  // Gold
        case .sadness:
            return "#4169E1"  // Royal Blue
        case .anger:
            return "#DC143C"  // Crimson
        case .fear:
            return "#9370DB"  // Medium Purple
        case .surprise:
            return "#FF8C00"  // Dark Orange
        case .disgust:
            return "#228B22"  // Forest Green
        case .neutral:
            return "#808080"  // Gray
        }
    }
    
    var description: String {
        switch self {
        case .joy:
            return "Feeling happy, content, and positive"
        case .sadness:
            return "Feeling down, melancholy, or disappointed"
        case .anger:
            return "Feeling frustrated, irritated, or upset"
        case .fear:
            return "Feeling anxious, worried, or concerned"
        case .surprise:
            return "Feeling amazed, astonished, or caught off guard"
        case .disgust:
            return "Feeling repulsed, annoyed, or dissatisfied"
        case .neutral:
            return "Feeling calm, balanced, or emotionally stable"
        }
    }
}

