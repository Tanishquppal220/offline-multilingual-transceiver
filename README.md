# iTantra – Offline Multilingual Voice Communication

iTantra is an Android application developed for the Smart India Hackathon (SIH). It is designed for low-latency voice communication over a local network using on-device speech recognition and speech synthesis.

## Current Working Flow

```
Voice input
   ↓
Offline STT
   ↓
Text message
   ↓
TCP over local Wi-Fi / hotspot
   ↓
Receiving device
   ↓
TTS
   ↓
Voice output
```

Typed messages can also be sent and converted to speech.

## Technology Stack

- **Flutter / Dart** — tactical transceiver UI
- **Kotlin** — native Android integration
- **Sherpa-ONNX** — offline speech processing
- **ONNX** — local speech models
- **TCP sockets** — local-network communication
- **Android** — target platform

## UI & User Flow Documentation

For the complete interactive component map, visual information architecture, and end-to-end user journeys (with Mermaid diagrams), see:
👉 **[UI Map, Architecture & User Flow Guide](docs/UI_MAP_AND_USER_FLOWS.md)**

## Project Structure

```
offline-multilingual-transceiver/
├── android/
│   └── app/src/main/kotlin/com/sih/voicebridge/
├── assets/
│   └── models/stt/ (10 Indian regional language models)
├── docs/
│   └── UI_MAP_AND_USER_FLOWS.md (Complete UI Map & Flow Guide)
├── lib/
│   ├── main.dart
│   └── app/
│       ├── app.dart
│       ├── models/        # Data models (benchmark, speech message, etc.)
│       ├── services/      # TCP mesh, native bridge, benchmark tracker
│       ├── state/         # AppController (reactive ChangeNotifier)
│       ├── theme/         # Tactical dark theme, colors, typography
│       └── ui/
│           ├── app_shell.dart          # 2-tab navigation (Talk & Messages)
│           ├── screens/
│           │   ├── talk_screen.dart    # PTT walkie-talkie & mesh controls
│           │   └── messages_screen.dart # Chat stream, presets & compose
│           └── widgets/
│               ├── tactical_header.dart       # Global header & lang chip
│               ├── language_picker_sheet.dart # 10-language bottom sheet
│               └── radio_settings_sheet.dart  # Volume & telemetry sheet
├── test/                  # Unit and accessibility test suites
├── pubspec.yaml
└── README.md
```

## Requirements

Install the following before running the project:

- Git
- Flutter SDK
- Android Studio
- Android SDK
- Android SDK Platform Tools
- Android emulator or a physical Android phone

> A physical Android phone is recommended for testing the microphone, speaker, STT, TTS, and local-network communication.

## Install Flutter

Install Flutter from the official Flutter documentation:

https://docs.flutter.dev/get-started/install

Verify the installation:

```bash
flutter --version
```

Then run:

```bash
flutter doctor
```

Fix any Android/Flutter setup issues reported by `flutter doctor`.

Check connected devices:

```bash
flutter devices
```

## Clone the Repository

```bash
git clone https://github.com/ShreeyanshJanu/SIH-21673.git
cd SIH-21673
```

Install Flutter dependencies:

```bash
flutter pub get
```

## Run the Application

Connect an Android phone with USB debugging enabled, or start an emulator.

Check devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

To select a specific device:

```bash
flutter run -d DEVICE_ID
```

Example:

```bash
flutter run -d ZA222MVV6T
```

## Testing Communication

The application uses a local TCP network. The current application port is:

```
7070
```

A typical setup is:

```
Phone B ──┐
Phone C ──┼──> Phone A (Server / Relay)
Phone D ──┘
```

One device runs as the server/relay and other devices connect to it.

Messages are transmitted as text rather than raw voice audio. The receiving device performs TTS locally.

## Working on the UI

Most UI development happens inside:

```
lib/app/ui/
```

Start by exploring:

```
lib/app/ui/screens/
lib/app/ui/widgets/
```

Before contributing or modifying UI components, please read **[docs/UI_MAP_AND_USER_FLOWS.md](docs/UI_MAP_AND_USER_FLOWS.md)** for detailed design patterns, state bindings, and touch target standards.

UI contributors can work on:

- Screens
- Widgets
- Layouts
- Colors
- Typography
- Spacing
- Icons
- Animations
- Themes
- User experience

### Important

If you are working only on the UI, avoid changing the underlying:

- `android/`
- `assets/models/`
- native MethodChannels
- STT pipeline
- TTS pipeline
- TCP/networking

...unless your task specifically requires it.

The native speech pipeline is sensitive, so UI changes should preferably remain within the Flutter layer.

## Flutter Hot Reload

Run:

```bash
flutter run
```

After changing Dart UI code, save the file and Flutter will normally hot-reload the application.

If needed, press `r` in the Flutter terminal for hot reload. For a full restart, press `R`.

## Build an APK

Debug APK:

```bash
flutter build apk --debug
```

Normally generated at:

```
build/app/outputs/flutter-apk/app-debug.apk
```

Release APK:

```bash
flutter build apk --release
```

Normally generated at:

```
build/app/outputs/flutter-apk/app-release.apk
```

## Native Android Code

Native code is located under:

```
android/app/src/main/kotlin/
```

Speech recognition code is located under:

```
android/app/src/main/kotlin/com/sih/voicebridge/pipeline/
```

`SttEngine.kt` handles the native STT pipeline and Sherpa-ONNX integration.

> Do not modify native speech-processing code for a UI-only task.

## Offline Models

Speech models are stored under:

```
assets/models/
```

The application is designed to process speech locally without depending on cloud speech APIs.

The repository currently contains the English STT model used by the working implementation. Additional Indian-language models can be added as development continues.

> Model files can be large. Do not add or replace large model files without checking their size and licensing first.

## Git Workflow

Do not work directly on `main` for new features.

Create a feature branch:

```bash
git checkout -b ui-improvement
```

Make and test your changes.

Check:

```bash
git status
git diff
```

Commit:

```bash
git add .
git commit -m "Improve application UI"
```

Push:

```bash
git push -u origin ui-improvement
```

Then create a Pull Request on GitHub.

Example branches:

```
main
├── ui-improvement
├── improve-stt-accuracy
└── emergency-ui
```

## Before Creating a Pull Request

Run:

```bash
flutter analyze
```

and:

```bash
flutter build apk --debug
```

Also verify:

- [ ] UI works on Android
- [ ] Voice communication still works
- [ ] Typed messages still work
- [ ] TCP communication still works
- [ ] No API keys or passwords were committed
- [ ] No generated build directories were committed
- [ ] Changes are on a feature branch

## Troubleshooting

**Flutter is not recognized**

Make sure Flutter's bin directory is in PATH, then restart the terminal:

```bash
flutter --version
```

**Android device is not detected**

Run:

```bash
flutter devices
```

For a physical phone, enable Developer Options and USB debugging and accept the computer authorization prompt.

You can also check:

```bash
adb devices
```

**Multiple Android devices are connected**

List devices:

```bash
flutter devices
```

Then select one:

```bash
flutter run -d DEVICE_ID
```

**Build problems after dependency changes**

Try:

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

## Development Roadmap

Current development priorities include:

- Improve STT accuracy
- Improve microphone/audio processing
- Add more Indian languages
- Improve offline TTS
- Improve Flutter UI/UX
- Improve emergency communication
- Test on low- and mid-range Android devices
- Measure latency, CPU, RAM, and APK size

## Contributing

For UI contributors:

1. Clone the repository
2. Install Flutter and Android tooling
3. Create a feature branch
4. Make UI changes in `lib/`
5. Test on Android
6. Run `flutter analyze`
7. Build a debug APK
8. Commit your changes
9. Push your branch
10. Create a Pull Request

## License

Add the project's final license information here before public release.

Third-party libraries and speech models may have separate licenses. Check their licenses before redistribution.
