# Nudge

A native SwiftUI personal assistant for iPhone — capture tasks by voice, get reminded, and stay accountable.

## Features

- Voice task capture via Apple Speech (on-device STT)
- **Log tab** — record in-person conversations; Gemini transcribes Hinglish (with Apple Speech live preview)
- Gemini AI parses natural language into tasks, due dates, and reminders
- Today / Log / Inbox / Stats views with streak tracking
- Local notifications for reminders, overdue nudges, and daily check-ins
- Dark aesthetic UI with amber accent

## Requirements

- macOS with **Xcode 16+**
- iPhone running **iOS 17+** (real device recommended for microphone)
- Free [Gemini API key](https://aistudio.google.com/apikey)
- Apple ID (free Personal Team works — re-sign every ~7 days)

## Run on your iPhone

1. Open `Nudge.xcodeproj` in Xcode
2. **Xcode → Settings → Accounts** → add your Apple ID
3. Select the **Nudge** target → **Signing & Capabilities** → set **Team** to your Personal Team
4. Connect your iPhone via USB
5. Select your iPhone as the run destination
6. Press **Run** (⌘R)
7. On iPhone: **Settings → General → VPN & Device Management** → Trust your developer cert

## First launch

1. Paste your Gemini API key on the onboarding screen
2. Allow notifications when prompted
3. Tap the mic on the Today tab and say something like: *"Remind me to call the dentist Tuesday at 2pm"*

## Project structure

```
Nudge/
├── NudgeApp.swift          App entry + SwiftData container
├── Models/                 TaskItem, CheckIn, UserStats, ConversationRecord, PAIntent
├── Services/               Gemini, Speech, Audio recording, Notifications, Keychain
├── Views/                  Today, Log, Inbox, Stats, Settings, Voice sheet
└── Theme/                  Colors and styling
```

## Cost

- Apple Speech: free
- Gemini API: free tier / low personal usage cost
- Apple Developer Program ($99/yr): optional — only needed to avoid weekly re-signing or App Store release
