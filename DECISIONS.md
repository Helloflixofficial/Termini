# Architectural Decisions (DECISIONS.md)

### 1. Multiplatform Video Player: `video_player` + `chewie`
- **Decision**: Use `video_player` (and `chewie` for UI controls).
- **Rationale**: `video_player` has official first-party Flutter team support across Android, iOS, and Web. Desktop platforms are supported either natively or via standard plugins. It handles HLS `.m3u8` streams directly from Mux without requiring complex native binary linking.

### 2. State Management: Riverpod
- **Decision**: Use `flutter_riverpod` with clean feature-first architecture (presentation, domain, data).
- **Rationale**: Provides compile-safe dependency injection, lifecycle management, and seamless `AsyncValue` handling for loading, error, and cached data across all screens.

### 3. Authentication: Clerk SDK + Secure Fallback
- **Decision**: Integrate Clerk session management using `clerk_flutter` / `clerk_auth` with deep token interception in Dio, and fallback to Clerk custom auth endpoint for robust multiplatform compatibility.
- **Rationale**: Allows 100% auth token parity with the Next.js `authMiddleware` which accepts `Authorization: Bearer <session_token>`.

### 4. Live Meetings: `livekit_client`
- **Decision**: Use official `livekit_client` Flutter plugin.
- **Rationale**: Compatible across mobile, web, and desktop. Communicates directly with the same LiveKit room server URL and token endpoint used by the Next.js application.

### 5. Backend Adjustments
- **Decision**: Minimal additions in Next.js repo under `app/api/`:
  - `GET /api/dashboard` (exposing `getDashboardCourses`)
  - `GET /api/categories` (fetching categories)
  - `GET /api/teacher/courses` (fetching teacher course list)
  - `GET /api/teacher/analytics` (exposing `getAnalytics`)
  - `GET /api/courses/[courseId]` (fetching full course details for editing)
  - CORS handler on all `/api/**` endpoints.
- **Rationale**: Allows the Flutter app to consume existing Prisma queries without any business logic duplication.
