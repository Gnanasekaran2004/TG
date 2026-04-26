# ✈️ Trip-GUY

> **Version 3.1.0** · Flutter · Firebase · MapLibre GL · Gemini Pro  
> A world-class travel super-app — plan, share, navigate, diary, chat, and get AI help for every journey.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20FCM-FFCA28?logo=firebase)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green)
![License](https://img.shields.io/badge/License-All%20Rights%20Reserved-red)

---

## The Problem

The modern travel experience is broken by fragmentation. Travelers juggle Google Maps, Notion, Instagram, WhatsApp, and ChatGPT with no way for these tools to talk to each other. The result is duplicated data, lost context, and a frustrating experience every time a trip is planned.

## The Solution — Trip-GUY

A single unified platform that collapses planning, navigation, social, AI intelligence, and journaling into one seamless mobile experience — with no proprietary API lock-in and no expensive map licenses.

---

## ✨ Feature Highlights

| Feature | Technology |
|---|---|
| Cross-platform UI | Flutter (Dart) |
| State management | `flutter_bloc` |
| Navigation | `go_router` |
| Authentication | Firebase Auth + OTP email verification |
| Real-time database | Cloud Firestore (offline-persistent, 100 MB) |
| Push notifications | Firebase Messaging + `flutter_local_notifications` |
| AI assistant | Google Gemini Pro (`google_generative_ai`) |
| Map rendering | MapLibre GL (native OpenGL ES 3.0) |
| Map tiles | OpenFreeMap Liberty (vector, free, no API key) |
| POI discovery | Overpass API (12 categories, 1.5 km radius) |
| Routing | OSRM open-source routing engine |
| Geocoding | Nominatim / OpenStreetMap |
| Dependency injection | GetIt (lazy singletons) |
| Micro-animations | `flutter_animate` |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│           PRESENTATION LAYER                │
│   Flutter Widgets · BLoC · GoRouter         │
├─────────────────────────────────────────────┤
│             DOMAIN LAYER                    │
│   Entities · Use Cases · Repositories      │
├─────────────────────────────────────────────┤
│              DATA LAYER                     │
│   Firebase Datasources · HTTP Clients       │
├─────────────────────────────────────────────┤
│            SERVICES LAYER                   │
│   MapLibre GL · Overpass · OSRM             │
│   Nominatim · OpenFreeMap Tiles             │
└─────────────────────────────────────────────┘
```

Clean Architecture + BLoC + GetIt — every feature is independently testable, extensible, and fully decoupled from the UI.

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | 3.x | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart | ≥ 3.0 | Bundled with Flutter |
| Firebase CLI | Latest | `npm install -g firebase-tools` |
| Android Studio | Latest | For Android emulator / SDK |
| Xcode | ≥ 15 | For iOS builds (macOS only) |

---

### Step 1 — Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/trip-guy.git
cd trip-guy
```

---

### Step 2 — Install Flutter Dependencies

```bash
flutter pub get
```

---

### Step 3 — Create Your `.env` File

The app requires a `.env` file at the project root. This file is **gitignored** and must be created manually.

```bash
# Copy the template
cp .env.example .env
```

Then open `.env` and fill in **your own keys**:

```env
# ── Google Gemini AI ─────────────────────────────────
# Get your free key at: https://aistudio.google.com/app/apikey
GEMINI_API_KEY=your_gemini_api_key_here

# ── EmailJS (for OTP email delivery) ─────────────────
# Sign up free at: https://www.emailjs.com/
# Create a service, two email templates (OTP + goodbye), and get your public key.
EMAILJS_SERVICE_ID=your_emailjs_service_id
EMAILJS_TEMPLATE_ID=your_otp_template_id
EMAILJS_PUBLIC_KEY=your_emailjs_public_key
EMAILJS_GOODBYE_TEMPLATE_ID=your_goodbye_template_id
```

> ⚠️ **Never commit `.env`** — it is already listed in `.gitignore`.

#### EmailJS Template Variables

Your OTP email template must include these variables:

| Variable | Usage |
|----------|-------|
| `{{to_name}}` | Recipient's name |
| `{{to_email}}` | Recipient's email address |
| `{{otp_code}}` | The 6-digit OTP |
| `{{expiry_minutes}}` | OTP expiry time (5 minutes) |

---

### Step 4 — Firebase Setup

The `firebase_options.dart` and `android/app/google-services.json` files are **already included** in this repository and point to the Trip-GUY Firebase project.

**If you want to connect your own Firebase project instead:**

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure for your own project
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

Then deploy the Firestore Security Rules to your project:

```bash
firebase login
firebase use YOUR_FIREBASE_PROJECT_ID
firebase deploy --only firestore:rules
```

> ⚠️ **Skipping the rules deployment will cause all Firestore reads/writes to fail.**

---

### Step 5 — Run the App

```bash
# Android (real device or API 21+ emulator with OpenGL ES 3.0)
flutter run

# Specific device
flutter devices
flutter run -d DEVICE_ID
```

> ⚠️ **MapLibre GL requires `minSdk = 21` and OpenGL ES 3.0.**  
> The app does **NOT** run on `flutter run -d chrome` (web). Use an Android or iOS device.

---

## 📦 Build for Release

```bash
# Android App Bundle (Play Store)
flutter build appbundle --release

# Android APK (sideload / testing)
flutter build apk --release

# iOS (requires macOS + Xcode)
flutter build ios --release
open ios/Runner.xcworkspace
# Then: Product → Archive → Distribute App → App Store Connect
```

---

## 📁 Project Structure

```
lib/
├── main.dart                    ← Firebase init, FCM setup, auth state listener
├── firebase_options.dart        ← Auto-generated Firebase configuration
├── injection_container.dart     ← GetIt DI registrations + Firestore persistence
│
├── core/
│   ├── theme/                   ← AppTheme (cached), AppColors, ThemeProvider
│   ├── utils/
│   │   ├── router.dart          ← GoRouter with auth guard
│   │   └── base64_cache.dart    ← LRU image decode cache (100 entries)
│   ├── services/
│   │   └── firebase_messaging_service.dart
│   └── widgets/
│       └── profile_avatar.dart  ← Reusable cached base64 avatar
│
└── features/
    ├── auth/                    ← Login, Register (OTP-gated), Forgot Password,
    │                               OTP Verification, Setup Profile
    ├── social/                  ← Feed, Trip publishing, Likes, Comments, Share
    ├── chat/                    ← Real-time 1:1 messaging with read receipts
    ├── diary/                   ← Per-trip timeline with mood, weather, photos
    ├── notifications/           ← FCM + in-app notification center
    ├── ai_assistant/            ← TripBot (Gemini Pro streaming)
    ├── profile/                 ← User profiles, avatars, follow system
    └── navigation/
        └── live_map_page.dart   ← MapLibre GL map (~1,700 lines)
```

---

## 🔐 Security Notes

- **Firebase API keys** in `firebase_options.dart` and `google-services.json` are **project identifiers, not secrets** — Firebase's security model uses Firestore Security Rules and Firebase Auth, not key secrecy. This is standard practice.
- **Gemini and EmailJS keys** are loaded from `.env` (gitignored). You must supply your own.
- **Firestore rules** enforce authentication on all data. No unauthenticated read/write is permitted except for the OTP flow.
- See [`TRIP_GUY_PROJECT_REPORT.md`](./TRIP_GUY_PROJECT_REPORT.md) → Section 8 for the full security architecture.

---

## 🗃️ Database Collections

| Collection | Purpose |
|------------|---------|
| `users/{uid}` | User profiles, online status, FCM tokens |
| `trips/{id}` | Trip posts with likes/comments subcollections |
| `trips/{id}/entries` | Per-trip travel diary entries with photos |
| `follows/{uid}` | Social graph (followers/following) |
| `chats/{roomId}/messages` | Real-time chat messages |
| `notifications/{id}` | In-app notifications |
| `otp_verifications/{email}` | Temporary 5-minute OTP codes |
| `registered_emails/{email}` | Email existence index (duplicate guard) |

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|---------|
| `flutter pub get` errors | Run `flutter clean` then `flutter pub get` |
| MapLibre black screen | Use a real device or emulator with OpenGL ES 3.0 support |
| Firestore permission-denied | Deploy `firestore.rules` via `firebase deploy --only firestore:rules` |
| OTP emails not sending | Verify all 4 `EMAILJS_*` values in `.env` are correct |
| Gemini AI not responding | Check `GEMINI_API_KEY` in `.env` is valid and not expired |
| iOS build fails | Add `GoogleService-Info.plist` to `ios/Runner/` from your Firebase project |

---

## 📄 Documentation

For the full technical specification including architecture diagrams, API references, database schema, Firestore security rules, and deployment pipeline:

👉 **[`TRIP_GUY_PROJECT_REPORT.md`](./TRIP_GUY_PROJECT_REPORT.md)**

---

## 📱 Platform Requirements

| Platform | Min Version | Notes |
|----------|------------|-------|
| Android | API 21 (Android 5.0) | Required by MapLibre GL (OpenGL ES 3.0) |
| iOS | iOS 12.0+ | `GoogleService-Info.plist` required |
| Web | ❌ Not supported | MapLibre GL is native-only |

---

## 📄 License & Copyright

```
Copyright (c) 2026 Gnanasekaran D. All Rights Reserved.
```

This project is **proprietary software**. No part of this codebase — including
source code, assets, design, documentation, or database schemas — may be copied,
modified, distributed, or used in any form without the **explicit written
permission** of the author.

> ⚠️ Unauthorized use constitutes copyright infringement under the **Copyright
> Act, 1957 (India)** and applicable international treaties.

See the [`LICENSE`](./LICENSE) file for the full legal terms and the
[`NOTICE`](./NOTICE) file for third-party attributions.

### Contact

| | |
|---|---|
| **Author** | Gnanasekaran D |
| **Email** | sgnana238@gmail.com |
| **Phone** | +91 8248094569 |
| **Country** | India |

---

*© 2026 Gnanasekaran D · Trip-GUY · All Rights Reserved*
