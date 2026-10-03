# Termini deployment plan

This repository contains a Flutter client at the repository root and a Next.js application plus a separate custom Node API server under `backend_repo/`. The mobile app currently calls the custom API server in `backend_repo/server.js`.

## Current deployment status

- The Flutter Android CI workflow builds a debug APK on pushes and pull requests to `main` and saves it as a short-lived GitHub Actions artifact.
- A protected Android release workflow is prepared to build a signed APK and Play Store app bundle from a version tag such as `v1.0.0` or a manual run on `main`.
- Vercel is **not ready for the Flutter app's complete API** yet. `server.js` creates a long-lived `http.Server`, calls `listen()`, and owns routes the Flutter app uses. Vercel's Next.js deployment handles the Next.js app and its route handlers; it does not run this custom listening server as the application's server. Some Next.js route handlers already exist, but endpoint behavior must be reconciled with the mobile API before switching the app over.
- Nothing in this setup deploys to Vercel or publishes to Google Play automatically.

## Recommended deployment sequence

### 1. Rotate the exposed database credential

The tracked diagnostics `backend_repo/test_db.js` and `backend_repo/test_videos.js` previously contained database connection URLs, and those values are present in repository history. The current files have been changed to read `DATABASE_URL` from the local environment and no longer print row contents. Treat the old database password as compromised:

1. Rotate the Neon database password or create a new restricted database role.
2. Update only the ignored local `backend_repo/.env` and the deployment environment after creating the Vercel project.
3. Do not paste the URL into chat, source files, issues, workflow logs, or GitHub Actions variables.
4. If those commits are on a public remote, removing the old value from a new commit does not erase it from history. History cleanup is a separate, coordinated operation and does not replace rotating the password.

### 2. Make the API compatible with Vercel

Before pointing the Flutter app at Vercel:

1. Inventory the route and response behavior in `backend_repo/server.js` against every path in `lib/core/config/api_constants.dart` and the Flutter repositories.
2. Move the mobile API routes into Next.js App Router handlers under `backend_repo/app/api/**/route.ts`, keeping request/response formats compatible.
3. Apply Clerk token verification and teacher authorization in each protected route. Production must reject demo identities and caller-supplied user IDs.
4. Preserve Stripe webhook signature verification, Mux playback authorization, upload authorization, and LiveKit token authorization during the migration.
5. Remove process-lifetime assumptions from API behavior: the in-memory access cache is per server process and cannot be treated as shared state. Keep durable state in PostgreSQL or another shared service.
6. Use Neon pooled connections for function traffic, keep migrations on the direct URL, and set conservative connection limits so function scaling cannot exhaust the database.
7. Set exact allowed browser origins. Do not use wildcard CORS with credentials.
8. Add route-level health and readiness checks, rate limits for authentication and write routes, and request validation before production cutover.
9. Verify mobile endpoint parity against a Vercel preview before changing the production app URL.

Until those steps are complete, keep the current `server.js` on a host that supports a persistent Node.js server, or complete the route migration before making Vercel the mobile API host.

#### Route parity found in this repository

I compared the Flutter repositories with the Next.js `app/api` route handlers. The Next.js app already has handlers for the dashboard, categories, most course/chapter/attachment operations, teacher data, community feeds/posts/settings, and LiveKit sessions/tokens. Similar route names alone do not prove that response shapes or authorization match the Flutter client.

These current Flutter/API-server paths still need explicit migration or a deliberate client change before Vercel can replace `server.js`:

| Path and method | Current gap |
| --- | --- |
| `GET`, `PUT /api/user/profile` | Used by Flutter; no corresponding Next.js route handler found. |
| `GET /api/community/notifications` | Used by Flutter; no corresponding Next.js route handler found. |
| `GET /api/community/posts/:postId/comments` | Flutter fetches comments; the Next.js handler currently exports `POST` only. |
| `POST /api/community/posts/:postId/likes` | Used by Flutter; no corresponding Next.js route handler found. |
| `GET /api/videos/:id` (`GET`/`HEAD`) | Custom server has a streaming route; no corresponding Next.js route handler found. Confirm whether the app still depends on it before retiring it. |
| `GET /healthz` | Custom-server health endpoint; add a function-compatible readiness endpoint for Vercel monitoring. |
| `POST /api/auth/sign-in`, `POST /api/auth/sign-up` | Flutter still declares these paths. The custom server rejects them in production; keep Clerk as the production identity provider and remove or replace any demo-auth dependency rather than exposing demo auth on Vercel. |

The route list comes from `lib/features/**/data/*_repository.dart`, `lib/core/config/api_constants.dart`, `backend_repo/server.js`, and `backend_repo/app/api/**/route.ts`. Close these gaps and verify request/response parity in a Vercel preview before changing the production mobile API URL.

### 3. Configure the Vercel project

Create/import the GitHub project in Vercel with `backend_repo` as its **Root Directory** and the Next.js framework preset. Let Vercel use the detected Next.js build settings. Connect Git through Vercel so pull requests receive preview deployments and production deploys follow the selected production branch. Keep the Vercel project private until the production environment and Clerk application domains are configured.

Set backend values in Vercel's environment settings, separately for Preview and Production:

| Vercel environment variable | Storage |
| --- | --- |
| `DATABASE_URL` | Neon pooled connection URL |
| `DIRECT_URL` | Neon direct connection URL for Prisma operations |
| `CLERK_SECRET_KEY` | Secret |
| `MUX_TOKEN_ID`, `MUX_TOKEN_SECRET` | Server-side Mux credentials |
| `UPLOADTHING_APP_ID`, `UPLOADTHING_SECRET` | UploadThing settings; keep the secret private |
| `STRIPE_API_KEY`, `STRIPE_WEBHOOK_SECRET` | Secret; use matching live/test mode per environment |
| `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` | Secret |
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | Public browser key; use the matching Clerk instance |
| `NEXT_PUBLIC_LIVEKIT_URL` | Public LiveKit endpoint |
| `NEXT_PUBLIC_APP_URL` | Public HTTPS Vercel/custom domain |
| `NEXT_PUBLIC_TEACHER_ID` | Public Clerk user ID list used by current code; not a credential |
| `CORS_ORIGINS` | Exact browser origins, comma-separated; no paths or trailing slash |

Never use a `NEXT_PUBLIC_` variable for a password or API secret: Next.js exposes those values to browser code. Apply Prisma migrations deliberately from a controlled release step using the direct database URL; do not run schema-changing commands on every function cold start.

### 4. Configure GitHub Actions

The Android CI workflow needs no secrets. Set the repository **variable** `API_BASE_URL` after the mobile API is deployed and verified; it must be the public HTTPS API origin. If it is unset, the debug APK keeps the local Android emulator default and is not suitable for a physical phone.

For production Android releases, create a GitHub environment named `android-production`, require an approver if available, and set these **environment variables**:

- `API_BASE_URL` — production HTTPS API base URL
- `CLERK_PUBLISHABLE_KEY` — production `pk_live_...` publishable key
- `STRIPE_PUBLISHABLE_KEY` — production `pk_live_...` publishable key
- `LIVEKIT_URL` — production `wss://...` server URL
- `NEXT_PUBLIC_TEACHER_ID` — comma-separated Clerk IDs that should see the teacher UI

Set these **environment secrets** for the same protected environment:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The signing keystore and passwords must never be committed or placed in Flutter `--dart-define` values. Keep an encrypted offline backup of the upload keystore; losing it can block app updates under the same Android signing identity. A GitHub variable or `--dart-define` is compiled into the mobile binary and is not a safe place for server credentials.

The release workflow produces an `.aab` for Play Console and a signed `.apk` for direct installation. It does not upload either artifact to Google Play.
Before each release, increment the build number in `pubspec.yaml` (and update the user-facing version when appropriate); a Git tag does not set Android's version code.

## Key and repository safety

- Keep `.env`, `.env.production`, local Vercel links, Android signing files, and generated build outputs out of Git. The ignore rules cover these patterns; `.env.example` files are safe templates only.
- Store backend secrets in Vercel's server environment. Store only Android signing material in the protected GitHub environment.
- Flutter values passed with `--dart-define` are public after the app is built. Only API origins and provider publishable keys belong there.
- Enable GitHub secret scanning and push protection if the repository plan supports them. Review alerts and rotate affected credentials instead of relying on log masking.
- Keep workflow token permissions read-only. Production signing is isolated behind the `android-production` environment; never expose release secrets to pull-request builds.
- Review Dependabot update pull requests for GitHub Actions, npm, and pub dependencies before merging.

## Files added for deployment work

- `.github/workflows/android-ci.yml` — debug APK build artifact for CI.
- `.github/workflows/android-release.yml` — gated, signed Android artifacts.
- `.github/dependabot.yml` — dependency update proposals.
- `android/app/build.gradle.kts` — reads release signing credentials from the environment; local developer builds retain the debug-signing fallback.
