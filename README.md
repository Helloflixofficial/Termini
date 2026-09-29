# Termini LMS – Multiplatform Flutter Learning Platform

A production-quality, multiplatform Flutter application that is a 100% functional and visual clone of [OEPlatform](https://github.com/Helloflixofficial/OEPlatform.git) — a modern Learning Management System (LMS) built with Next.js, Clerk authentication, Neon Postgres via Prisma, Stripe checkout, Mux video streaming, UploadThing file attachments, and LiveKit WebRTC interactive live classrooms.

**Targets**: Android, iOS, Web, Windows, macOS, Linux from a single unified codebase.

---

## Architecture & Technology Stack

The Flutter application follows strict **Clean Architecture** principles and SOLID design patterns:

- **State Management**: [Flutter Riverpod](https://riverpod.dev) (`StateNotifierProvider`, `FutureProvider.family`, autoDispose).
- **Navigation & Routing**: [GoRouter](https://pub.dev/packages/go_router) with deep linking (`termini://`), declarative routing, nested parameter parsing, and reactive authentication redirection guards.
- **HTTP Networking**: [Dio](https://pub.dev/packages/dio) with custom `AuthInterceptor`, bearer token injection, automated error mapping to a sealed `Failure` hierarchy (`AuthFailure`, `NotFoundFailure`, `ServerFailure`, `NetworkFailure`).
- **Secure Persistence**: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) for JWT session tokens and user credentials; [shared_preferences](https://pub.dev/packages/shared_preferences) for UI theme preference.
- **HLS Video Streaming**: [video_player](https://pub.dev/packages/video_player) & [chewie](https://pub.dev/packages/chewie) with direct Mux playback (`https://stream.mux.com/{playbackId}.m3u8`), auto-play, custom scrubber controls, lock screen overlays, and automatic completion progress tracking.
- **WebRTC Live Classrooms**: [livekit_client](https://pub.dev/packages/livekit_client) supporting real-time video/audio streaming, dynamic room connection, participant tracks, screen sharing, live chat drawer, and hand raise reactions.
- **Styling & Design System**: Exact Tailwind / shadcn HSL palette matching OEPlatform in both Light Mode and Dark Mode. Single reactive theme toggle button with smooth micro-animations.
- **Responsive & Adaptive Layouts**: Custom breakpoint system handling:
  - **Compact** (`< 600dp`): Mobile drawer, bottom sheet navigation, stacked layouts.
  - **Medium** (`600dp – 1024dp`): Collapsed sidebar, adaptive grids.
  - **Expanded** (`> 1024dp`): Full desktop sidebar, dual-pane player, data tables.

```
lib/
├── core/
│   ├── config/          # AppEnv, ApiConstants
│   ├── error/           # Failure hierarchy & error mappers
│   ├── network/         # Dio ApiClient & AuthInterceptor
│   ├── router/          # GoRouter configuration & guards
│   ├── theme/           # AppColors (HSL shadcn tokens), AppTheme, ThemeProvider
│   ├── utils/           # Breakpoints & layout helpers
│   └── widgets/         # AppSidebar, TopNavbar, ResponsiveLayout, SkeletonLoader, EmptyState
├── features/
│   ├── auth/            # Clerk auth bridge, Sign In, Sign Up, Demo Profiles
│   ├── community/       # Community spaces, discussions, comments, moderation & settings
│   ├── courses/         # Course syllabus, category filters, search, course cards
│   ├── dashboard/       # Enrolled courses, in progress & completed tabs
│   ├── live/            # LiveKit WebRTC meetings, room controls, participants & chat
│   ├── player/          # Mux HLS player, chapter progress toggle, attachments list
│   ├── profile/         # User profile, role switcher, active server info, sign out
│   └── teacher/         # Course CRUD, chapter editor, video uploader, analytics charts, meeting scheduler
└── main.dart            # Root entry point with ProviderScope & MaterialApp.router
```

---

## Backend Integration

The existing Next.js backend (`backend_repo/`) acts as the single source of truth. All database secrets (Postgres connection string, Clerk secret keys, Stripe secret keys, Mux API secrets, LiveKit API secrets) remain strictly on the backend.

Minor RESTful adjustments made to the backend are documented in detail in [`BACKEND_CHANGES.md`](./BACKEND_CHANGES.md) and captured in [`backend_patch.diff`](./backend_patch.diff):
- `GET /api/dashboard`: Aggregated student dashboard data (courses in progress & completed).
- `GET /api/categories`: List all course categories with counts.
- `GET /api/courses`: Query published courses with optional `title` and `categoryId` filters.
- `GET /api/courses/:id`: Complete course overview with chapters and attachments.
- `GET /api/courses/:id/chapters/:id`: Chapter playback details (Mux playbackId, lock status, user progress, attachments).
- `POST /api/courses/:id/checkout`: Stripe checkout with optional mobile return deep link (`returnUrl: 'termini://...'`).
- `GET /api/teacher/courses`: Teacher courses list with chapter counts and publication states.
- `GET /api/teacher/analytics`: Total revenue, total sales, active learners, and monthly earnings breakdown.
- CORS preflight and allowed headers added in `next.config.js`.

---

## Configuration & Environment Variables

Configure application settings at build/run time using `--dart-define` flags. The root `.env.example` is a reference template; Flutter does not automatically load it. Never put backend secret keys in Flutter `--dart-define` values.

| Variable | Default Value | Description |
|---|---|---|
| `API_BASE_URL` | Android emulator: `http://10.0.2.2:3000`<br>Web/Desktop: `http://localhost:3000` | Backend API base URL |
| `CLERK_PUBLISHABLE_KEY` | `pk_test_sample` | Clerk publishable key |
| `LIVEKIT_URL` | `wss://livekit.example.com` | LiveKit WebRTC server endpoint |
| `STRIPE_PUBLISHABLE_KEY` | `pk_test_...` | Stripe publishable key |
| `NEXT_PUBLIC_TEACHER_ID` | `""` | Comma-separated list of teacher Clerk user IDs |

To run against a physical device over Wi-Fi / LAN, pass your host machine's IP:
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3000
```

---

## Platform Setup & Permissions

### Android (`android/app/src/main/AndroidManifest.xml`)
- `INTERNET` and `ACCESS_NETWORK_STATE`
- `CAMERA`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `BLUETOOTH` (LiveKit WebRTC)
- `usesCleartextTraffic="true"` enabled for local development (`http://10.0.2.2:3000` or local LAN IP)
- Deep link intent filter:
  - Scheme: `termini://`
  - Host: `course`

### iOS (`ios/Runner/Info.plist`)
- `NSCameraUsageDescription`: Live video classes and screen sharing.
- `NSMicrophoneUsageDescription`: Live class audio and speaking.
- `NSPhotoLibraryUsageDescription`: Uploading course thumbnails and attachments.
- URL Schemes: `termini`

### Web (`web/index.html`)
- Responsive meta tags, UTF-8 charset, PWA web manifest.

---

## 🚀 How to Start This App (Step-by-Step)

This project has **two parts**: the Node.js backend (`backend_repo/`) and the Flutter app. Both must be running for live course and community data. A fresh computer also needs credentials for the same database and third-party services; private credentials are intentionally not stored in GitHub.

---

### Prerequisites

| Tool | Minimum Version | Check |
|------|----------------|-------|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | Stable channel | `flutter --version` |
| [Node.js](https://nodejs.org/) | `18.x` or newer | `node --version` |
| [Android SDK & ADB](https://developer.android.com/studio) | latest | `adb --version` |
| Git | latest | `git --version` |

On a new computer, clone this repository first and open a terminal in its folder:

```bash
git clone https://github.com/Helloflixofficial/Termini.git
cd Termini
flutter doctor
flutter pub get
```

---

### Step 1 — Set Up the Backend

```bash
# From the project root
cd backend_repo

# Install Node.js dependencies
npm install

# Create a private local settings file (PowerShell)
Copy-Item .env.example .env
```

Open `backend_repo/.env` and add credentials for the services this project uses. Keep this file private and do not commit it. The safe template lists all supported variables. For courses, point `DATABASE_URL` and `DIRECT_URL` at the existing PostgreSQL database; sign-in needs Clerk; playback and uploads need Mux and UploadThing. Checkout and live meetings need Stripe and LiveKit credentials.

For a brand-new empty PostgreSQL database, apply the checked-in migrations from `backend_repo` with `npx prisma migrate deploy`. Skip this for an existing database whose schema is already in place.

The Android emulator can reach the backend using the built-in `10.0.2.2` default. On a USB-connected Android phone, run `adb reverse tcp:3000 tcp:3000` while connected so the phone can use `localhost`. For a phone over Wi-Fi, pass the computer's LAN IP as `API_BASE_URL` and allow port 3000 through the computer's firewall.

---

### Step 2 — Start the Backend Server

The backend uses a **custom Node.js server** (`server.js`), NOT `npm run dev`.

```bash
# From inside backend_repo/
node server.js
```

You should see:
```
[Termini LMS Server] Running at http://0.0.0.0:3000
[DB] Connected to Neon PostgreSQL successfully!
```

> ⚠️ **Keep this terminal open.** The server must stay running while you use the app.

---

### Step 3 — Connect Your Android Device

1. Enable **USB Debugging** on your Android phone (Settings → Developer Options).
2. Plug in via USB and verify it's detected:

```bash
adb devices
# Should show: R9WW30565LK   device  (or your device serial)
```

3. Forward port 3000 from the device to your PC so the phone can reach the backend:

```bash
adb reverse tcp:3000 tcp:3000
```

> Run this command **every time** you reconnect the device.

---

### Step 4 — Run the Flutter App

#### Run from source
```bash
# From the project root (termini/)
flutter pub get
flutter run -d <your-device-id>
```

For another backend host, pass its address explicitly:

```bash
flutter run -d <your-device-id> --dart-define=API_BASE_URL=http://192.168.1.100:3000
```

To build and install a debug APK yourself:
```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.helloflix.termini/com.helloflix.termini.MainActivity
```

---

### Step 5 — Verify Everything Works

Open the app on your phone. You should see:
- ✅ Dashboard loads with your courses from the Neon PostgreSQL database
- ✅ Courses display with thumbnails and chapter lists
- ✅ Video playback works inside chapters
- ✅ Authentication (Sign In / Sign Up) works via Clerk

---

### Quick Start Cheatsheet

Every time you want to run the app after the initial setup:

```bash
# Terminal 1 — Start backend
cd backend_repo
node server.js

# Terminal 2 — (USB phone only) forward backend port, then launch app
adb reverse tcp:3000 tcp:3000
flutter run -d <your-device-id>
```

---

### Troubleshooting

| Problem | Fix |
|---------|-----|
| `Lost connection to device` | Reconnect USB + run `adb reverse tcp:3000 tcp:3000` again |
| `No devices found` | Enable USB Debugging, run `adb devices` to verify |
| App shows empty dashboard | Make sure `node server.js` is running and port is forwarded |
| Video won't play | Check that backend is running; videos stream via `http://localhost:3000/api/videos/:id` |
| `flutter: ProcessStarter` error | Run using the full path: `C:\src\flutter\bin\flutter.bat run -d <device>` |

---

## Getting Started (Web / Desktop)

### Chrome Web
```bash
flutter run -d chrome
```

### Windows Desktop
```bash
flutter run -d windows
```

Start `node server.js` from `backend_repo` in another terminal first. For database data to appear, the backend `.env` must point to a reachable database with this project's schema and data. The repository includes the Prisma schema and migrations, but does not include a copy of a private production database.

---

## Code Quality & Testing

```bash
# Run static analysis
flutter analyze

# Run unit and widget test suite
flutter test
```

---

## Acceptance & Parity

Refer to [`FINAL_ACCEPTANCE.md`](./FINAL_ACCEPTANCE.md) for the complete screen-by-screen parity matrix and verified test results.
