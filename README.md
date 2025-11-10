### EmotiQ
AI for Emotional Intelligence in your pocket.

EmotiQ is a production-grade iOS app that analyzes voice to infer emotion, delivers micro‑interventions and custom voice affirmations, and helps users build healthy emotional habits with insights, goals, and smart notifications.

---

### Highlights
- **Voice Emotion Analysis**: On‑device DSP + Core ML pipeline for robust emotion inference from recorded speech.
- **Insights Dashboard**: Trends, distributions, weekly patterns, and voice characteristics with PDF export.
- **Personalized Coaching**: Micro‑interventions, goals, and custom voice affirmations (via ElevenLabs).
- **Smart Notifications**: OneSignal-powered reminders, streak nudges, and predictive prompts.
- **Subscriptions**: RevenueCat-backed Premium/Pro tiers with secure purchase validation.
- **Privacy & Security**: On-device processing, biometric lock (Face ID), CloudKit-backed Core Data.

---

### App Store
- Get EmotiQ on the App Store: [EmotiQ – Emotional Coach](https://apps.apple.com/app/emotiq/id6749479428)

---

### Technologies Used
- **Language & UI**: Swift 5.10, SwiftUI, UIKit (interop), Combine
- **Audio & ML**: AVFoundation, CoreML, Accelerate/vDSP, Speech, NaturalLanguage
- **Charts & Rendering**: Swift Charts, `UIGraphicsPDFRenderer`, GPU offloading with `.drawingGroup()`
- **Persistence**: Core Data with CloudKit, Persistent History Tracking
- **Networking & Services**: URLSession, ElevenLabs API (voice synthesis)
- **Notifications**: OneSignal SDK, Notification Service Extension
- **Purchases & Subscriptions**: StoreKit, RevenueCat
- **Security & Auth**: LocalAuthentication (Face ID), Keychain-backed storage
- **Tooling/Other**: Swift Concurrency, Background tasks/queues, Deep Linking

---

### Screenshots

Place the images below at `docs/images/` using these filenames (or update the paths):

![MicroIntervention and Custom Affirmations](docs/images/microintervention_custom_affirmations.jpg)
![Emotions Unlocked](docs/images/emotions_unlocked.jpg)
![Completed Emotional Goals](docs/images/completed_emotional_goals.jpg)
![Voice Setup](docs/images/voice_setup.jpg)
![Emotional Prompts](docs/images/emotional_prompts.jpg)
![Insights](docs/images/insights.jpg)
![Personalized Coaching](docs/images/personalized_coaching.jpg)
![Speak & Discover](docs/images/speak_and_discover.jpg)
![Microintervention Streaks](docs/images/microintervention_streaks.jpg)
![Voice Affirmations](docs/images/voice_affirmations.jpg)

> If you prefer different names, keep them under `docs/images/` and update the links above.

---

### Architecture
- **UI**: SwiftUI with MVVM
  - Views in `EmotiQ/Views/**`
  - View models in `EmotiQ/ViewModels/**`
- **Domain & Services**
  - Emotion analysis: `CoreMLEmotionService`, `EmotionAnalysisService`, `SpeechAnalysisService`, `AudioProcessingService`, `VoiceRecordingService`
  - Coaching & interventions: `Services/CoachingService`, views under `Views/Interventions` and `Elevenlabs/Views`
  - Notifications & prediction: `OneSignal/**`
  - Subscriptions: `RevenueCatService`, `SubscriptionService`, `SecurePurchaseManager`
  - Persistence & analytics: `Utilities/PersistenceController`, `Models/**`
- **Rendering/Export**
  - Charts & PDF: `Utilities/ChartToPDFRenderer.swift`, `Utilities/ScreenShotPDFExportManager.swift`
- **Configuration**
  - Central config: `Utilities/Config.swift`
  - StoreKit config: `StoreKitConfig.storekit`

Key design principles:
- Heavy compute and I/O run off the main actor; published state updates occur on the main actor.
- Views receive value props to reduce invalidations; charts avoid implicit animations while scrolling.
- Core Data work (cleanup, dedup, backfills) uses background contexts.
- File I/O (e.g., ElevenLabs audio cache) is performed on dedicated queues/tasks.

---

### Features (by module)
- **Voice Check**
  - Record audio and analyze emotions with dual‑channel approach:
    - Speech/NLP channel (`SpeechAnalysisService`) + DSP features channel (`CoreMLEmotionService`)
  - Produces `EmotionAnalysisResult` and aggregates for insights
- **Insights**
  - Overview metrics: weekly check‑ins, average mood, streak
  - Voice characteristics: pitch, energy, quality, stability
  - Trends: emotion intensity over time; distributions; weekly patterns
  - Export to PDF (section-aware pagination) from `InsightsView`
- **Coaching**
  - Micro‑interventions with streaks and completions
  - Goals with milestones and progress
  - Custom Voice Affirmations (generation and caching via ElevenLabs)
- **Notifications**
  - OneSignal initialization in `AppDelegate` using `Config.oneSignalAppID`
  - `OneSignalService` and `OneSignalNotificationManager` manage permissions, tags, scheduling, and analytics
  - Predictive nudges via `SmartNotificationScheduler` and `EmotionalInterventionPredictor`
- **Subscriptions**
  - RevenueCat configuration in `AppDelegate` via `RevenueCatService.configure()`
  - Paywalls in `Views/Paywalls/**`, product IDs in `Config.Subscription`
  - `SubscriptionService` exposes entitlements and gating for premium features

---

### Requirements
- Xcode 16 or later
- iOS 17.6+ deployment target (see `EmotiQ.xcodeproj` build settings)
- Apple Developer account (Push Notifications, iCloud/CloudKit, In‑App Purchases)
- Physical device recommended for microphone, notifications, and purchases

---

### Getting Started
1. Clone the repo and open `EmotiQ.xcodeproj`.
2. Select the `EmotiQ` scheme and choose a physical device.
3. Configure signing for the app and the `OneSignalNotificationServiceExtension`.
4. Update API keys as needed in `EmotiQ/Utilities/Config.swift`:
   - `revenueCatAPIKey`
   - `oneSignalAppID`
5. Run the app.

> The app includes entitlements for Push Notifications and iCloud/CloudKit (Core Data). Make sure your team profile has these enabled.

---

### Configuration
- `Utilities/Config.swift`
  - `revenueCatAPIKey`: RevenueCat API key
  - `oneSignalAppID`: OneSignal app ID
  - `Subscription` product IDs: `emotiq_premium_monthly`, `emotiq_pro_monthly`
  - Feature flags, analytics toggles, and UI constants
- StoreKit testing:
  - `StoreKitConfig.storekit` contains products for local testing
- Notifications:
  - OneSignal initialized in `EmotiQApp.swift` `AppDelegate`

---

### Building & Running
- Scheme: `EmotiQ` (Debug/Release)
- Run: ⌘R on a physical device
- Tests: Product → Test (unit and UI test targets included)
- Exporting Insights PDF:
  - Open `Insights` tab → tap the Export button (top right)
  - A share sheet should appear once the PDF is created

---

### Privacy
- Voice recordings are analyzed on‑device; no raw audio is sent to third parties for emotion inference.
- Push and analytics are opt‑in and configurable in the app.

---

### Project Structure
- `EmotiQApp.swift`: App lifecycle and third‑party initialization
- `Views/**`: SwiftUI screens (Dashboard, Voice Check, Insights, Coaching, Profile)
- `ViewModels/**`: View models for state and transformations
- `Services/**`: Audio/ML, coaching, subscriptions, storage
- `Elevenlabs/**`: ElevenLabs services and views (voice synthesis, caching, interventions)
- `OneSignal/**`: Notification services, predictors, schedulers
- `Utilities/**`: Config, PDF rendering, persistence, theming
- `Models/**`: Core models and enums
- `OneSignalNotificationServiceExtension/**`: Notification extension target

---

### ElevenLabs Module
- Location: `EmotiQ/Elevenlabs/**`
- Purpose: Voice cloning, TTS generation for affirmations and interventions, caching, playback, and haptic-enhanced UX.

- Services (`Elevenlabs/Service`):
  - `ElevenLabsService.swift`: Core integration via secure proxy (`/api/elevenlabs`). Handles:
    - Voice cloning (multipart upload, validation of duration/format/quality)
    - Emotion-aware TTS generation with per-emotion voice settings
    - Batch generation, usage stats, voice deletion
    - Core Data persistence of `VoiceProfile` and activation state
    - Local caching via `AudioCacheManager` to minimize credits and latency
  - `AudioCacheManager.swift`: File-backed MP3 cache with:
    - Background IO, index serialization, size/age-based cleanup
    - Cache keying by text + emotion + voiceId; prewarming helpers
  - `CachedAudioPlayer.swift`: Lightweight `AVAudioPlayer` wrapper with:
    - Play/pause/seek/loop, progress updates, route/interruption handling
    - Haptic feedback hooks via `HapticManager`
  - `AffirmationEngine.swift`: Personalized affirmation generation:
    - Uses recent `EmotionalData` to build an `EmotionalProfile`
    - Template/prompt selection, TTS via ElevenLabs, Core Data storage
    - Completion tracking and simple feedback learning
  - `VoiceGuidedInterventionService.swift`: TTS-driven micro‑interventions:
    - Breathing, grounding, prompts with segment scripts
    - Cache prewarm, in‑flight deduping, progress tracking, level meter
  - `ElevenLabsViewModel.swift`: UI-facing orchestration:
    - Voice cloning workflow, voice settings, usage quotas
    - Single/batch TTS generation, preview, Core Data binding
  - `HapticManager.swift`: Centralized Core Haptics patterns for audio and interventions.

- Views (`Elevenlabs/Views`):
  - `AffirmationsView.swift`, `AffirmationDetailView.swift`, `CustomAffirmationCreatorView.swift`
  - `VoiceCloningSetUpView.swift` (voice profile onboarding)
  - `VoiceGuidedInterventionView.swift` (guided sessions with prewarm + playback)

Notes:
- No raw ElevenLabs API keys are stored in the client; calls go through a secure proxy.
- Audio generation first checks the local cache; network only when needed, then caches the result.

---

### Contributing
Issues and pull requests are welcome. Please open a discussion for larger changes beforehand.

---

### License
This project is licensed under the terms of the MIT License. See `LICENSE` for details.