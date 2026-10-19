# Pulsar — Your Day, In Orbit

> **Privacy-first, voice-powered task manager for Android & Desktop** built with **Flutter**, **SQLite**, and **On-Device AI** (Cactus Whistle ASR + Cactus Needle 3 Mini-LLM via Native C++ FFI).

---

## 📸 App Screenshots

| 1. Calendar Home | 2. Voice Input | 3. AI Draft Review | 4. Manual Entry | 5. Settings & AI Status |
| :---: | :---: | :---: | :---: | :---: |
| <img src="App_photos/appImg%20(1).jpeg" width="190" alt="Pulsar Calendar Home" /> | <img src="App_photos/appImg%20(2).jpeg" width="190" alt="Voice Input" /> | <img src="App_photos/appImg%20(3).jpeg" width="190" alt="AI Draft Review" /> | <img src="App_photos/appImg%20(5).jpeg" width="190" alt="Manual Entry" /> | <img src="App_photos/appImg%20(4).jpeg" width="190" alt="Settings & Engine Status" /> |
| *Monthly calendar with completion toggles & dot indicators* | *Offline voice capture powered by Whistle + Needle* | *Editable preview card with one-tap confirmation* | *Clean manual entry with custom date & time pickers* | *On-device model verification & theme settings* |

---

## 🌟 Key Features

1. **Voice-Based Task Creation & Schedule Querying**
   - Transcribe speech with **Cactus Whistle** (16.9 MB CPU-efficient ASR running 100% offline).
   - Extract structured tasks and tools with **Cactus Needle 3** (35.3 MB Quantized Tool-Calling Mini-LLM).
   - **Acoustic Enhancement & Domain Biasing**: Built-in `VoiceEnhancementService` uses an Aho-Corasick automaton to bias domain terms (dates, times, task verbs, alarms) and resolve spoken numbers (`ten a.m.` $\to$ `10:00 AM`) for reliable transcription.
   - **Multi-task extraction**: parse multiple tasks from a single natural command (e.g., *"Buy groceries at 5 PM and call Mom at 7 PM"*).
   - **Schedule queries**: ask *"What are all the tasks for today?"* or *"Do I have anything tomorrow?"* for immediate assistant summaries.
2. **Interactive AI Task Draft Review & Customization**
   - **Responsive Review Card**: Review AI suggestions before saving with editable title, date, time, reminder, and alarm controls.
   - **Custom Micro-Switches & Overflow Protection**: Built with responsive `_buildToggleCard` containers and custom 32×18 px animated mini-switches, guaranteeing zero RenderFlex layout overflows even on narrow 320 px screens.
   - **Quick Adjustment Chips**: Instantly change dates (`Today`, `Tomorrow`) or times (`9:00 PM`, `7:00 PM`, `6:00 PM`, `10:00 AM`, `Clear time`) with a single tap.
3. **Interactive Time Slider in Edit Mode**
   - Tap the pencil edit icon in **Task Details** to inline-edit title, notes, and task time.
   - **Custom-Themed Time Slider**: Adjust time smoothly in 15-minute intervals across 95 divisions (12:00 AM to 11:45 PM) with real-time updates and preset chips, keeping the date securely immutable.
4. **Dual Alert System: Reminders & Loud Alarms**
   - **Notification Service**: Standard Android notification channel scheduling exact notification reminders.
   - **Alarm Service & Ring Screen**: Built-in `AlarmService` and full-screen `AlarmRingScreen` for loud, high-priority audio alarms when critical tasks are due.
   - **One-Tap Notification Pause/Resume**: Global bell toggle on the home calendar to pause or resume alerts without losing individual task schedules.
5. **Strict Action Modules Architecture**
   - Needle interacts exclusively through discrete tool-calling modules (`retrieve_tasks`, `create_task`, `update_task`, `delete_task`, `request_clarification`, `task_summary`).
   - The AI never writes directly to SQLite; task actions are staged for human review and confirmed with 1 tap.
   - Ambiguous commands (e.g., a reminder with missing date/time) trigger a clarification prompt with quick suggestions rather than guessing or hallucinating dates.
6. **Streamlined Calendar Home & Task Management**
   - Interactive monthly calendar grid with task indicator dots and day-by-day task lists.
   - Fast one-tap completion toggle radio buttons right on the home calendar view.
   - Centered floating `+` button in the footer for instant voice or manual task addition.
7. **Cosmic Design & Themes**
   - Cosmic Black (`#080B14`), Nebula Navy (`#111827`), Pulsar Cyan (`#67E8F9`), and Nebula Violet (`#A78BFA`).
   - Custom-rendered **Pulsar Neutron Star** animated logo and native Android launcher icon across all screen densities.
   - Seamless toggle between Dark Theme and Light Theme in Settings.
8. **100% Offline-First & Private**
   - Single-user local storage using SQLite (`pulsar_tasks.db`).
   - Zero cloud backend, telemetry, or login required. All voice processing, inference, and task data remain on-device.

---

## 📱 Final Application APK

The final production-ready APK is pre-compiled for Android (ARM64) with native on-device AI models embedded:

- **Location**: [`build/app/outputs/flutter-apk/pulsar.apk`](file:///c:/Users/yeshwanthRaj/Documents/Pulsar/build/app/outputs/flutter-apk/pulsar.apk)
- **App Name**: `Pulsar`
- **Package ID**: `com.pulsar.voicetask.pulsar`
- **Binary Size**: ~142 MB (includes embedded 16.9 MB Whistle ASR and 35.3 MB Needle 3 models)
- **Installation**:
  ```bash
  adb install -r build/app/outputs/flutter-apk/pulsar.apk
  ```

---

## 📖 In-Depth Documentation

For a detailed explanation of every component, module, widget, and the Action Modules architecture, see:
👉 **[ARCHITECTURE_AND_MODULES.md](file:///c:/Users/yeshwanthRaj/Documents/Pulsar/ARCHITECTURE_AND_MODULES.md)**

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Flutter 3.20+ / Dart 3.4+)
- Android SDK / NDK (for native C++ CMake compilation) or Android device running ARM64

### Running the App Locally

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run unit & widget tests
flutter test

# 3. Launch on connected Android device
flutter run --debug

# 4. Build standalone APK
flutter build apk --debug --target-platform android-arm64
```

---

## 📂 Project Structure

```
lib/
├── main.dart                          # App entrypoint, background receivers & service initialization
├── app.dart                           # MaterialApp with theme switcher and routes
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # Cosmic color palette
│   │   └── app_theme.dart             # Dark and Light themes with floating snackBarTheme
│   ├── utils/
│   │   └── date_utils.dart            # Deterministic date parsing & calendar grid calculations
│   └── widgets/
│       └── pulsar_logo.dart           # Animated Pulsar Neutron Star CustomPainter
├── models/
│   └── task_model.dart                # Task data model (SQLite serialization & colors)
├── data/
│   ├── database/
│   │   └── task_database.dart         # SQLite database (sqflite / sqflite_ffi)
│   └── repositories/
│       └── task_repository.dart       # Task CRUD operations & SQLite query layer
├── services/
│   ├── notification_service.dart      # flutter_local_notifications manager & alarm scheduler
│   ├── alarm_service.dart             # System audio alarm coordinator (full-screen ring trigger)
│   ├── voice_capture_service.dart     # 16 kHz PCM microphone capture & silence auto-stop
│   ├── voice_enhancement_service.dart # Domain keyword biasing & Aho-Corasick phonetics
│   └── preferences_service.dart       # Theme and settings persistence (shared_preferences)
├── ai/
│   ├── cactus_config.dart             # Model asset paths & configurations
│   ├── cactus_service.dart            # Whistle ASR + Needle LLM coordination pipeline
│   ├── action_router.dart             # Action Modules security gateway & schema builder
│   ├── needle_intent_parser.dart      # Deterministic fallback parser & conjunction splitter
│   ├── needle_engine.dart             # Cross-platform FFI isolate engine interface
│   ├── needle_engine_native.dart      # Native C++ FFI isolate runner (libpulsar_needle.so)
│   ├── needle_engine_stub.dart        # Non-native platform fallback stub
│   ├── tools/                         # Modular tool implementations
│   │   ├── base_tool.dart             # Base tool interface
│   │   ├── retrieve_tasks_tool.dart   # Task query and search tool
│   │   ├── create_task_tool.dart      # Staged task creation tool
│   │   ├── update_task_tool.dart      # Task modification tool
│   │   ├── delete_task_tool.dart      # Task removal tool
│   │   ├── request_clarification_tool.dart # Clarification prompt tool
│   │   └── task_summary_tool.dart     # Calendar overview summary tool
│   └── action_modules/                # Backwards-compatible action module exports
├── providers/
│   ├── task_provider.dart             # Main state coordinator (tasks, voice, stages)
│   ├── notification_settings_provider.dart # Pause/resume notification toggle state
│   └── theme_provider.dart            # Dark/light theme state coordinator
└── ui/
    ├── home/
    │   └── home_screen.dart           # Home scaffold with calendar body and centered + FAB
    ├── calendar/
    │   ├── calendar_view.dart         # Calendar header, month grid, and daily task list
    │   └── widgets/
    │       ├── calendar_grid.dart     # Interactive monthly grid with task dots
    │       ├── calendar_task_card.dart# Daily task item card with completion radio button
    │       └── notification_bell_button.dart # Bell toggle with floating feedback & hint bubble
    ├── add_task/
    │   ├── add_task_screen.dart       # Modal bottom sheet / dialog with tab switcher
    │   ├── voice_input_tab.dart       # Glowing mic, live pipeline stages & suggestions
    │   ├── manual_entry_tab.dart      # Manual entry form with date/time pickers
    │   └── widgets/
    │       ├── voice_pulse_button.dart# Pulsating ripple mic button
    │       ├── staged_task_review_dialog.dart # Overflow-safe AI review card with mini-switches
    │       └── clarification_dialog.dart # Missing parameter prompt with quick action chips
    ├── alarm/
    │   └── alarm_ring_screen.dart     # Full-screen loud alarm interface with snooze & dismiss
    ├── details/
    │   └── task_details_screen.dart   # Task edit & details screen with interactive time slider
    └── settings/
        └── settings_screen.dart       # Light mode toggle, on-device AI status & data wipe
```

---

## 🔒 Privacy & Security

Pulsar is built from the ground up to be offline-first:
* Audio recordings are captured in 16 kHz PCM, processed entirely within temporary memory, and cleared immediately after inference.
* No voice recordings, transcripts, task metadata, or personal schedules are ever transmitted to any external server.
* You can wipe all local application data and reset the SQLite database at any time from **Settings > Erase All Data**.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
