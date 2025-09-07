//
//  EmotionalPrompt.swift
//  EmotiQ
//
//  Created by Temiloluwa on 22-08-2025.
//
import SwiftUI
import Foundation

// MARK: - Enhanced Emotional Prompts Section
struct EmotionalPromptsSection: View {
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticManager
    @State private var showingAllPrompts = false
    
    var body: some View {
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Emotional Prompts")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Spacer()
                    
                    Button("View All") {
                        hapticManager.impact(.light)
                        showingAllPrompts = true
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.accent)
                }
                
                VStack(spacing: 12) {
                    ForEach(viewModel.emotionalPrompts.prefix(3), id: \.id) { prompt in
                        EnhancedEmotionalPromptCard(prompt: EnhancedEmotionalPrompt(from: prompt), viewModel: viewModel)
                    }
                }
            }
            .navigationDestination(isPresented: $showingAllPrompts) {
                AllEmotionalPromptsView(viewModel: viewModel)
            }
        }
    }

// MARK: - Enhanced Emotional Prompt Card (Whole Card as Button)
struct EnhancedEmotionalPromptCard: View {
    let prompt: EnhancedEmotionalPrompt
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Card Button (Whole card is clickable)
            Button(action: {
                hapticManager.impact(.light)
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: prompt.icon)
                            .font(.title3)
                            .foregroundColor(prompt.category.color)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(ThemeColors.primaryText)
                            
                            Text(prompt.category.displayName)
                                .font(.caption)
                                .foregroundColor(ThemeColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(ThemeColors.accent)
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    }
                    
                    Text(prompt.question)
                        .font(.body)
                        .foregroundColor(ThemeColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(ThemeColors.secondaryText.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reflection Guide:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ThemeColors.secondaryText)
                        
                        ForEach(prompt.reflectionGuide, id: \.self) { guide in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(prompt.category.color)
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 6)
                                
                                Text(guide)
                                    .font(.caption)
                                    .foregroundColor(ThemeColors.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    
//                    HStack {
//                        Spacer()
//
//                        Button("Start Reflection") {
//                            hapticManager.impact(.medium)
//                            viewModel.startPromptReflection(prompt.toOriginal())
//                        }
//                        .font(.caption)
//                        .fontWeight(.medium)
//                        .foregroundColor(.white)
//                        .padding(.horizontal, 20)
//                        .padding(.vertical, 10)
//                        .background(
//                            LinearGradient(
//                                colors: [prompt.category.color, prompt.category.color.opacity(0.8)],
//                                startPoint: .leading,
//                                endPoint: .trailing
//                            )
//                        )
//                        .clipShape(Capsule())
//                        .shadow(color: prompt.category.color.opacity(0.3), radius: 4, x: 0, y: 2)
//                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.isDarkMode ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isExpanded ? prompt.category.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isExpanded ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - All Emotional Prompts View
struct AllEmotionalPromptsView: View {
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticManager
    @State private var selectedCategory: EnhancedEmotionalPromptCategory = .all
    
    var filteredPrompts: [EnhancedEmotionalPrompt] {
        if selectedCategory == .all {
            return viewModel.allEmotionalPrompts
        }
        return viewModel.allEmotionalPrompts.filter { $0.category == selectedCategory }
    }
    
    var body: some View {
        ZStack {
            ThemeColors.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emotional Prompts")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(ThemeColors.primaryText)
                        
                        Text("Guided self-reflection for emotional growth")
                            .font(.subheadline)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Category Filter
                    CategoryFilterSection(selectedCategory: $selectedCategory)
                    
                    // Prompts List
                    LazyVStack(spacing: 16) {
                        ForEach(filteredPrompts, id: \.id) { prompt in
                            EnhancedEmotionalPromptCard(prompt: prompt, viewModel: viewModel)
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .navigationTitle("Emotional Prompts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Category Filter Section
struct CategoryFilterSection: View {
    @Binding var selectedCategory: EnhancedEmotionalPromptCategory
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(EnhancedEmotionalPromptCategory.allCases, id: \.self) { category in
                    CategoryFilterChip(
                        category: category,
                        isSelected: selectedCategory == category,
                        onTap: {
                            hapticManager.impact(.light)
                            selectedCategory = category
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    let category: EnhancedEmotionalPromptCategory
    let isSelected: Bool
    let onTap: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            Text(category.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : ThemeColors.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? category.color : ThemeColors.secondaryText.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(category.color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Enhanced Emotional Prompt Category
enum EnhancedEmotionalPromptCategory: String, CaseIterable, Codable {
    // MARK: - Conversion Methods
    init(from original: EmotionalPromptCategory) {
        switch original {
        case .gratitude: self = .gratitude
        case .selfCompassion: self = .selfCompassion
        case .mindfulness: self = .mindfulness
        case .growth: self = .growth
        case .relationships: self = .relationships
        case .stress: self = .stress
        case .confidence: self = .confidence
        case .purpose: self = .purpose
        case .all:
            fallthrough
        @unknown default: self = .all
        }
    }
    
    func toOriginal() -> EmotionalPromptCategory {
        switch self {
        case .all: return .gratitude // Default fallback
        case .gratitude: return .gratitude
        case .selfCompassion: return .selfCompassion
        case .mindfulness: return .mindfulness
        case .growth: return .growth
        case .relationships: return .relationships
        case .stress: return .stress
        case .confidence: return .confidence
        case .purpose: return .purpose
        }
    }
    case all = "all"
    case gratitude = "gratitude"
    case selfCompassion = "self_compassion"
    case mindfulness = "mindfulness"
    case growth = "growth"
    case relationships = "relationships"
    case stress = "stress"
    case confidence = "confidence"
    case purpose = "purpose"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .gratitude: return "Gratitude"
        case .selfCompassion: return "Self-Compassion"
        case .mindfulness: return "Mindfulness"
        case .growth: return "Growth"
        case .relationships: return "Relationships"
        case .stress: return "Stress Relief"
        case .confidence: return "Confidence"
        case .purpose: return "Purpose"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return ThemeColors.accent
        case .gratitude: return .green
        case .selfCompassion: return .pink
        case .mindfulness: return .purple
        case .growth: return .blue
        case .relationships: return .orange
        case .stress: return .red
        case .confidence: return .yellow
        case .purpose: return .indigo
        }
    }
}

// MARK: - Enhanced Emotional Prompt Model
struct EnhancedEmotionalPrompt: Identifiable, Codable {
    // MARK: - Conversion Methods
    init(from original: EmotionalPrompt) {
        self.id = original.id
        self.title = original.title
        self.question = original.question
        self.category = EnhancedEmotionalPromptCategory(from: original.category)
        self.reflectionGuide = original.reflectionGuide
        self.icon = original.icon
        self.estimatedDuration = original.estimatedDuration
    }
    
    func toOriginal() -> EmotionalPrompt {
        return EmotionalPrompt(
            title: self.title,
            question: self.question,
            category: self.category.toOriginal(),
            reflectionGuide: self.reflectionGuide,
            icon: self.icon,
            estimatedDuration: self.estimatedDuration
        )
    }
    var id = UUID()
    let title: String
    let question: String
    let category: EnhancedEmotionalPromptCategory
    let reflectionGuide: [String]
    let icon: String
    let estimatedDuration: String
    
    // Custom coding keys to handle UUID
    enum CodingKeys: String, CodingKey {
        case title, question, category, reflectionGuide, icon, estimatedDuration
    }
    
    init(title: String, question: String, category: EnhancedEmotionalPromptCategory, reflectionGuide: [String], icon: String, estimatedDuration: String) {
        self.id = UUID()
        self.title = title
        self.question = question
        self.category = category
        self.reflectionGuide = reflectionGuide
        self.icon = icon
        self.estimatedDuration = estimatedDuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.question = try container.decode(String.self, forKey: .question)
        self.category = try container.decode(EnhancedEmotionalPromptCategory.self, forKey: .category)
        self.reflectionGuide = try container.decode([String].self, forKey: .reflectionGuide)
        self.icon = try container.decode(String.self, forKey: .icon)
        self.estimatedDuration = try container.decode(String.self, forKey: .estimatedDuration)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(question, forKey: .question)
        try container.encode(category, forKey: .category)
        try container.encode(reflectionGuide, forKey: .reflectionGuide)
        try container.encode(icon, forKey: .icon)
        try container.encode(estimatedDuration, forKey: .estimatedDuration)
    }
}

// MARK: - 20 Powerful Emotional Prompts Extension
extension MicroInterventionsViewModel {
    var allEmotionalPrompts: [EnhancedEmotionalPrompt] {
        return [
            // Gratitude Prompts
            EnhancedEmotionalPrompt(
                title: "Three Good Things",
                question: "What are three things that went well today, and why do you think they happened?",
                category: .gratitude,
                reflectionGuide: [
                    "Think about specific moments, not general statements",
                    "Consider your role in making these things happen",
                    "Notice how reflecting on positive events makes you feel"
                ],
                icon: "heart.fill",
                estimatedDuration: "3-5 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Gratitude for Challenges",
                question: "What difficult experience taught you something valuable about yourself?",
                category: .gratitude,
                reflectionGuide: [
                    "Focus on the growth that came from the challenge",
                    "Identify specific skills or insights you gained",
                    "Consider how this experience helps you now"
                ],
                icon: "mountain.2.fill",
                estimatedDuration: "5-7 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Appreciation Circle",
                question: "Who in your life deserves appreciation, and what specific impact have they had on you?",
                category: .gratitude,
                reflectionGuide: [
                    "Think of someone who supported you recently",
                    "Recall a specific moment when they helped you",
                    "Consider reaching out to express your gratitude"
                ],
                icon: "person.2.fill",
                estimatedDuration: "4-6 minutes"
            ),
            
            // Self-Compassion Prompts
            EnhancedEmotionalPrompt(
                title: "Inner Friend",
                question: "How would you comfort a dear friend experiencing what you're going through right now?",
                category: .selfCompassion,
                reflectionGuide: [
                    "Use the same kind, understanding tone you'd use with a friend",
                    "Offer yourself the same patience and encouragement",
                    "Remember that struggling is part of the human experience"
                ],
                icon: "heart.circle.fill",
                estimatedDuration: "4-6 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Self-Forgiveness",
                question: "What mistake are you holding onto, and how can you learn from it while being kind to yourself?",
                category: .selfCompassion,
                reflectionGuide: [
                    "Acknowledge the mistake without harsh self-judgment",
                    "Identify what you learned from this experience",
                    "Practice speaking to yourself with compassion"
                ],
                icon: "leaf.fill",
                estimatedDuration: "5-8 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Strength Recognition",
                question: "What personal strength helped you overcome a recent challenge?",
                category: .selfCompassion,
                reflectionGuide: [
                    "Think of a specific recent challenge you faced",
                    "Identify the inner resources you used to cope",
                    "Appreciate your resilience and capability"
                ],
                icon: "shield.fill",
                estimatedDuration: "3-5 minutes"
            ),
            
            // Mindfulness Prompts
            EnhancedEmotionalPrompt(
                title: "Present Moment Awareness",
                question: "What are you noticing in your body, mind, and environment right now?",
                category: .mindfulness,
                reflectionGuide: [
                    "Scan your body for any sensations or tension",
                    "Notice your current thoughts without judgment",
                    "Observe your surroundings with fresh eyes"
                ],
                icon: "eye.fill",
                estimatedDuration: "3-5 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Emotion Observer",
                question: "What emotion are you experiencing right now, and where do you feel it in your body?",
                category: .mindfulness,
                reflectionGuide: [
                    "Name the emotion without trying to change it",
                    "Notice physical sensations associated with this feeling",
                    "Observe how emotions naturally shift and change"
                ],
                icon: "brain.head.profile",
                estimatedDuration: "4-6 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Mindful Breathing",
                question: "How does focusing on your breath for one minute change your mental state?",
                category: .mindfulness,
                reflectionGuide: [
                    "Take slow, deep breaths and notice the sensation",
                    "When your mind wanders, gently return to your breath",
                    "Compare how you feel before and after this practice"
                ],
                icon: "wind",
                estimatedDuration: "2-4 minutes"
            ),
            
            // Growth Prompts
            EnhancedEmotionalPrompt(
                title: "Learning Edge",
                question: "What's one area where you're growing, and what's the next small step you can take?",
                category: .growth,
                reflectionGuide: [
                    "Identify a skill or quality you're developing",
                    "Acknowledge the progress you've already made",
                    "Choose one specific action for continued growth"
                ],
                icon: "arrow.up.circle.fill",
                estimatedDuration: "5-7 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Comfort Zone Expansion",
                question: "What would you attempt if you knew you couldn't fail?",
                category: .growth,
                reflectionGuide: [
                    "Dream without limitations or fear of judgment",
                    "Consider what this reveals about your true desires",
                    "Identify one small step toward this vision"
                ],
                icon: "star.fill",
                estimatedDuration: "6-8 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Past Self Wisdom",
                question: "What advice would your current self give to who you were one year ago?",
                category: .growth,
                reflectionGuide: [
                    "Reflect on how much you've grown and learned",
                    "Consider the wisdom you've gained from experiences",
                    "Appreciate your journey of personal development"
                ],
                icon: "clock.arrow.circlepath",
                estimatedDuration: "5-7 minutes"
            ),
            
            // Relationship Prompts
            EnhancedEmotionalPrompt(
                title: "Connection Appreciation",
                question: "How did someone make you feel valued or understood recently?",
                category: .relationships,
                reflectionGuide: [
                    "Recall a specific interaction that felt meaningful",
                    "Notice what made this connection special",
                    "Consider how you can create similar moments for others"
                ],
                icon: "heart.text.square.fill",
                estimatedDuration: "4-6 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Relationship Growth",
                question: "What's one way you can show up more authentically in your relationships?",
                category: .relationships,
                reflectionGuide: [
                    "Think about when you feel most genuine with others",
                    "Identify any masks or barriers you sometimes use",
                    "Choose one way to be more open and honest"
                ],
                icon: "person.crop.circle.fill",
                estimatedDuration: "5-8 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Empathy Practice",
                question: "How might someone who disagrees with you be feeling, and what might they need?",
                category: .relationships,
                reflectionGuide: [
                    "Try to understand their perspective without judgment",
                    "Consider their underlying emotions and needs",
                    "Practice holding space for different viewpoints"
                ],
                icon: "hands.and.sparkles.fill",
                estimatedDuration: "6-8 minutes"
            ),
            
            // Stress Relief Prompts
            EnhancedEmotionalPrompt(
                title: "Stress Release",
                question: "What's one thing causing you stress that you can either address or let go of today?",
                category: .stress,
                reflectionGuide: [
                    "Identify your biggest current stressor",
                    "Determine if it's within your control to change",
                    "Choose either an action step or a letting-go practice"
                ],
                icon: "leaf.arrow.circlepath",
                estimatedDuration: "4-6 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Calm Anchor",
                question: "What activity or place makes you feel most peaceful, and how can you access that feeling now?",
                category: .stress,
                reflectionGuide: [
                    "Visualize your most calming environment or activity",
                    "Notice how thinking about it affects your body",
                    "Find ways to bring elements of this peace into your current moment"
                ],
                icon: "water.waves",
                estimatedDuration: "3-5 minutes"
            ),
            
            // Confidence Prompts
            EnhancedEmotionalPrompt(
                title: "Success Reflection",
                question: "What's something you accomplished that you're proud of, no matter how small?",
                category: .confidence,
                reflectionGuide: [
                    "Choose something recent that gave you satisfaction",
                    "Identify the qualities that helped you succeed",
                    "Let yourself fully feel the pride of this accomplishment"
                ],
                icon: "trophy.fill",
                estimatedDuration: "4-6 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Inner Strength",
                question: "When have you been braver than you thought possible?",
                category: .confidence,
                reflectionGuide: [
                    "Recall a time when you acted despite fear or uncertainty",
                    "Recognize the courage it took to move forward",
                    "Connect with that same brave part of yourself now"
                ],
                icon: "flame.fill",
                estimatedDuration: "5-7 minutes"
            ),
            
            // Purpose Prompts
            EnhancedEmotionalPrompt(
                title: "Values Alignment",
                question: "What activities make you feel most alive and aligned with your values?",
                category: .purpose,
                reflectionGuide: [
                    "Think about when you feel energized and fulfilled",
                    "Identify the values being expressed in these moments",
                    "Consider how to incorporate more of these activities"
                ],
                icon: "compass.drawing",
                estimatedDuration: "6-8 minutes"
            ),
            
            EnhancedEmotionalPrompt(
                title: "Legacy Reflection",
                question: "How do you want to be remembered, and what small action today moves you toward that?",
                category: .purpose,
                reflectionGuide: [
                    "Envision the impact you want to have on others",
                    "Consider what qualities you want to be known for",
                    "Choose one action that embodies these aspirations"
                ],
                icon: "infinity.circle.fill",
                estimatedDuration: "7-10 minutes"
            )
        ]
    }
}

// MARK: - SwiftUI Preview
#Preview {
    NavigationStack {
        EmotionalPromptsSection(
            viewModel: MicroInterventionsViewModel()
        )
        .environmentObject(ThemeManager())
        .environmentObject(HapticManager.shared)
    }
}

