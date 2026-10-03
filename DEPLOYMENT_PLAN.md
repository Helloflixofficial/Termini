# Termini deployment plan

This repository contains a Flutter client at the repository root and a Next.js application plus a separate custom Node API server under `backend_repo/`. The mobile app currently calls the custom API server in `backend_repo/server.js`.

## Current deployment status

- The Flutter Android CI workflow builds a debug APK on pushes and pull requests to `main` and saves it as a short-lived GitHub Actions artifact.
- A protected Android release workflow is prepared to build a signed APK and Play Store app bundle from a version tag such as `v1.0.0` or a manual run on `main`.
- A separate Vercel-native TypeScript API has been created at `terserServer/`. It uses Next.js App Router function routes, Prisma, Clerk JWT verification, and matches the Flutter API paths. Its production build and TypeScript checks pass locally. Follow [`terserServer/README.md`](./terserServer/README.md) for setup, environment variables, and deployment.
- The Vercel project is **not deployed or production-ready yet**. Provider credentials still need to be configured, production migrations reviewed/applied, and the existing public Mux playback IDs migrated to signed playback before cutover. The old `backend_repo/server.js` is unchanged.
- Nothing in this setup deploys to Vercel or publishes to Google Play automatically.

## Recommended deployment sequence

### 1. Rotate the exposed database credential

The tracked diagnostics `backend_repo/test_db.js` and `backend_repo/test_videos.js` previously contained database connection URLs, and those values are present in repository history. The current files have been changed to read `DATABASE_URL` from the local environment and no longer print row contents. Treat the old database password as compromised:

1. Rotate the Neon database password or create a new restricted database role.
2. Update only the ignored local `backend_repo/.env` and the deployment environment after creating the Vercel project.
3. Do not paste the URL into chat, source files, issues, workflow logs, or GitHub Actions variables.
4. If those commits are on a public remote, removing the old value from a new commit does not erase it from history. History cleanup is a separate, coordinated operation and does not replace rotating the password.

### 2. Prepare and secure the new API

The Vercel-compatible API is in `terserServer/`; use its [deployment guide](./terserServer/README.md) as the operational checklist. Before production cutover, rotate the exposed database password, apply reviewed Prisma migrations, configure Clerk/provider secrets, migrate old public Mux playback IDs to signed IDs, and verify Flutter requests against a Vercel Preview. Keep the original `backend_repo/server.js` available for rollback until that Preview passes.

#### Route parity in the new server

The `terserServer/app/api` route handlers include the Flutter-facing profile, dashboard, course, teacher, community, LiveKit, video, and health paths. Sign-in/up API calls explicitly return `410`: production identity is handled by Clerk, and demo sign-in is disabled.

Before switching Flutter from the old server to Vercel, complete the operational rollout steps in `terserServer/README.md`:

- Configure Vercel and provider environments, apply the reviewed database migrations, and run the Mux signed-playback migration before deploying paid video.
- The user’s Flutter app must send a real Clerk session JWT. Demo/offline identities are not accepted by `terserServer`.
- Deploy a Preview and verify app endpoint behavior before changing the production API URL.

### 3. Configure the Vercel project

Create/import the GitHub project in Vercel with `terserServer` as its **Root Directory** and the Next.js framework preset. Let Vercel use the detected Next.js build settings. Connect Git through Vercel so pull requests receive preview deployments and production deploys follow the selected production branch. Keep the Vercel project private until the production environment and Clerk application domains are configured.

Set backend values in Vercel's environment settings, separately for Preview and Production:

| Vercel environment variable | Storage |
| --- | --- |
| `DATABASE_URL` | Neon pooled connection URL |
| `DIRECT_URL` | Neon direct connection URL for Prisma operations |
| `CLERK_SECRET_KEY`, `CLERK_JWT_ISSUER` | Secret and exact issuer for JWT verification |
| `TEACHER_IDS` | Server-only Clerk teacher/admin IDs |
| `MUX_TOKEN_ID`, `MUX_TOKEN_SECRET`, `MUX_SIGNING_KEY_ID`, `MUX_PRIVATE_KEY` | Server-side Mux API/signing credentials |
| `UPLOADTHING_APP_ID`, `UPLOADTHING_SECRET` | UploadThing settings; keep the secret private |
| `STRIPE_API_KEY`, `STRIPE_WEBHOOK_SECRET` | Secret; use matching live/test mode per environment |
| `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL` | Server-side LiveKit credentials and public websocket endpoint |
| `APP_BASE_URL` | HTTPS API origin used for Stripe return pages |
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
