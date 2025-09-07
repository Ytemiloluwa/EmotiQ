//
//  ThemeManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import SwiftUI
import Combine

// MARK: - Theme Manager
@MainActor
class ThemeManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentTheme: AppTheme = .system
    @Published var isDarkMode: Bool = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let themeKey = "EmotiQ_AppTheme"
    
    // MARK: - Initialization
    init() {
        loadSavedTheme()
        updateDarkModeStatus()
    }
    
    // MARK: - Public Methods
    
    /// Sets the app theme and persists the choice
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveTheme()
        updateDarkModeStatus()
        applyThemeToSystem()
    }
    
    /// Gets the current color scheme based on theme setting
    func getColorScheme() -> ColorScheme? {
        switch currentTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // Let system decide
        }
    }
    
    /// Updates dark mode status based on current environment
    func updateDarkModeStatus() {
        switch currentTheme {
        case .light:
            isDarkMode = false
        case .dark:
            isDarkMode = true
        case .system:
            // Check system appearance
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                isDarkMode = windowScene.traitCollection.userInterfaceStyle == .dark
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSavedTheme() {
        if let savedThemeRawValue = userDefaults.object(forKey: themeKey) as? String,
           let savedTheme = AppTheme(rawValue: savedThemeRawValue) {
            currentTheme = savedTheme
        } else {
            currentTheme = .system // Default to system
        }
    }
    
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
    }
    
    private func applyThemeToSystem() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        for window in windowScene.windows {
            switch currentTheme {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}

// MARK: - App Theme Enum
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "gear"
        }
    }
    
    var description: String {
        switch self {
        case .light:
            return "Always use light mode"
        case .dark:
            return "Always use dark mode"
        case .system:
            return "Follow system setting"
        }
    }
}

// MARK: - Theme Colors
struct ThemeColors {
    
    // MARK: - Primary Colors
    static let primaryPurple = Color(red: 0.6, green: 0.4, blue: 1.0)
    static let primaryCyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    
    // MARK: - Background Colors
    static var primaryBackground: Color {
        Color(.systemBackground)
    }
    
    static var secondaryBackground: Color {
        Color(.secondarySystemBackground)
    }
    
    static var tertiaryBackground: Color {
        Color(.tertiarySystemBackground)
    }
    
    // MARK: - Text Colors
    static var primaryText: Color {
        Color(.label)
    }
    
    static var secondaryText: Color {
        Color(.secondaryLabel)
    }
    
    static var tertiaryText: Color {
        Color(.tertiaryLabel)
    }
    
    // MARK: - Accent Colors
    static var accent: Color {
        primaryPurple
    }
    
    static var success: Color {
        Color(.systemGreen)
    }
    
    static var warning: Color {
        Color(.systemOrange)
    }
    
    static var error: Color {
        Color(.systemRed)
    }
    
    // MARK: - Gradient Colors
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryPurple, primaryCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                primaryPurple.opacity(0.1),
                primaryCyan.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                primaryPurple.opacity(0.05),
                primaryCyan.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Emotion Colors (Dark Mode Compatible)
    static func emotionColor(for emotion: EmotionType, isDarkMode: Bool) -> Color {
        switch emotion {
        case .joy:
            return isDarkMode ? Color.yellow.opacity(0.8) : Color.yellow
        case .sadness:
            return isDarkMode ? Color.blue.opacity(0.8) : Color.blue
        case .anger:
            return isDarkMode ? Color.red.opacity(0.8) : Color.red
        case .fear:
            return isDarkMode ? Color.purple.opacity(0.8) : Color.purple
        case .surprise:
            return isDarkMode ? Color.orange.opacity(0.8) : Color.orange
        case .disgust:
            return isDarkMode ? Color.green.opacity(0.8) : Color.green
        case .neutral:
            return isDarkMode ? Color.gray.opacity(0.8) : Color.gray
        }
    }
}

// MARK: - Theme Modifiers
struct ThemedBackground: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    let style: BackgroundStyle
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return ThemeColors.primaryBackground
        case .secondary:
            return ThemeColors.secondaryBackground
        case .tertiary:
            return ThemeColors.tertiaryBackground
        case .gradient:
            return Color.clear
        }
    }
}

struct ThemedCard: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    let cornerRadius: CGFloat
    let shadow: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(cardBackground)
                    .shadow(
                        color: shadowColor,
                        radius: shadow ? 8 : 0,
                        x: 0,
                        y: shadow ? 4 : 0
                    )
            )
    }
    
    private var cardBackground: Color {
        themeManager.isDarkMode ?
            ThemeColors.secondaryBackground :
            ThemeColors.primaryBackground
    }
    
    private var shadowColor: Color {
        themeManager.isDarkMode ?
            Color.black.opacity(0.3) :
            Color.black.opacity(0.1)
    }
}

enum BackgroundStyle {
    case primary
    case secondary
    case tertiary
    case gradient
}

// MARK: - View Extensions
extension View {
    
    /// Applies themed background
    func themedBackground(_ style: BackgroundStyle = .primary) -> some View {
        self.modifier(ThemedBackground(style: style))
    }
    
    /// Applies themed card styling
    func themedCard(cornerRadius: CGFloat = 16, shadow: Bool = true) -> some View {
        self.modifier(ThemedCard(cornerRadius: cornerRadius, shadow: shadow))
    }
    
    /// Applies the current color scheme from theme manager
    func themedColorScheme() -> some View {
        self.environmentObject(ThemeManager())
    }
}

// MARK: - Theme Preview Helper
struct ThemePreview: View {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Theme Preview")
                .font(.title)
                .foregroundColor(ThemeColors.primaryText)
            
            HStack {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button(theme.displayName) {
                        themeManager.setTheme(theme)
                    }
                    .padding()
                    .background(ThemeColors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            VStack {
                Text("Primary Text")
                    .foregroundColor(ThemeColors.primaryText)
                Text("Secondary Text")
                    .foregroundColor(ThemeColors.secondaryText)
                Text("Tertiary Text")
                    .foregroundColor(ThemeColors.tertiaryText)
            }
            .padding()
            .themedCard()
        }
        .padding()
        .themedBackground()
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.getColorScheme())
    }
}

