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

Configure application settings at build/run time using `--dart-define` flags:

| Variable | Default Value | Description |
|---|---|---|
| `API_BASE_URL` | Android: `http://10.0.2.2:3000`<br>Web/Desktop: `http://localhost:3000` | Backend API base URL |
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

## Getting Started

### 1. Prerequisites
- Flutter SDK `^3.13.0` (Dart SDK `^3.1.0`)
- Node.js `^18` (for the backend server in `backend_repo/`)

### 2. Start the Backend
```bash
cd backend_repo
npm install
npx prisma generate
npm run dev
```

### 3. Run the Flutter App
#### Physical Android Device (USB Debugging)
```bash
flutter run -d <device-id>
```

#### Chrome Web
```bash
flutter run -d chrome
```

#### Windows / macOS / Linux Desktop
```bash
flutter run -d windows
```

### 4. Code Quality & Testing
```bash
# Run static analysis (0 errors, 0 warnings enforced)
flutter analyze

# Run unit and widget test suite
flutter test
```

---

## Acceptance & Parity

Refer to [`FINAL_ACCEPTANCE.md`](./FINAL_ACCEPTANCE.md) for the complete screen-by-screen parity matrix and verified test results.
