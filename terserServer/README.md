# Termini API (`terserServer`)

This is a separate, Vercel-native API deployment for the Termini Flutter app. It uses Next.js App Router route handlers with TypeScript, Prisma, Neon PostgreSQL, and Clerk JWT verification. It does not start a long-running custom HTTP server: Vercel creates request-driven Node.js functions, scales them, and can scale them back to zero between requests. A continuously running process is not part of the Vercel serverless model.

The existing `backend_repo` is left intact. This folder carries its application API routes and Prisma data model, adds mobile endpoints that were missing, and deliberately has no demo identity fallback. The app’s existing API paths stay under `/api/**`.

## Start locally

Requirements: Node.js 20.9 or newer, npm, and a Neon/PostgreSQL database with the Termini schema.

1. Open a terminal in `terserServer/`.
2. Install dependencies with `npm ci`.
3. Copy `.env.example` to `.env.local` and fill in the development values. Keep this file private.
4. Generate the Prisma client: `npm run db:generate`.
5. Start the API: `npm run dev`.
6. Open `http://localhost:3000/healthz`. A ready response is `{"status":"ok","database":"connected"}`.

For a local database that does not yet have the Termini schema, inspect the checked-in migrations and apply them against a disposable database first. Do not use `prisma db push` against production; it can alter or remove existing database structures.

## Deploy to Vercel

1. Import `Helloflixofficial/Termini` into Vercel.
2. Set **Root Directory** to `terserServer`. This API folder is self-contained and does not need files from the repository root.
3. Select the Next.js framework preset. Use `npm ci` for install and `npm run build` for build. Leave the output directory at its default.
4. Add the required Vercel environment values below for Preview and Production separately.
5. Apply the verified Prisma migrations using the controlled database migration step below.
6. Deploy a Preview first. Check `/healthz`, then exercise authentication, course reads, progress, community, and any configured payment/upload/meeting providers.
7. Set the Flutter app’s `API_BASE_URL` to the verified Vercel origin only after the preview checks pass. Build and install the app with that public API origin.
8. Promote/deploy to Production only after the production Clerk, Stripe, Mux, UploadThing, and LiveKit environments are configured and smoke-checked.

GitHub Actions runs `Termini API CI` on pull requests and pushes that touch `terserServer/`. It type-checks and builds without production secrets. Vercel remains responsible for Preview and Production deployments after you connect the repository.

Vercel is request driven, so there is no server process to keep alive. Health checks do not prevent serverless scale-to-zero. Availability still depends on Vercel, Neon, Clerk, and the configured media/payment providers; no code can promise a perfect service with zero errors.

## Environment variables

### Required for core API operation

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Neon pooled PostgreSQL URL for runtime queries. Add a low `connection_limit` suitable for the plan, for example `connection_limit=1`. |
| `DIRECT_URL` | Direct PostgreSQL URL used by Prisma migrations; never use it for normal function traffic. |
| `CLERK_SECRET_KEY` | Server-side Clerk key used to verify session JWTs and read/update profiles. |
| `CLERK_JWT_ISSUER` | Exact issuer URL of the Clerk instance that signs the app’s session JWTs, with no trailing slash. |
| `TEACHER_IDS` | Comma-separated Clerk IDs authorized for teacher/admin operations. This is server-only; do not name it `NEXT_PUBLIC_*`. |
| `APP_BASE_URL` | HTTPS public application/API origin used for Stripe return URLs. |
| `CORS_ORIGINS` | Exact browser origins, comma-separated. Example: `https://app.example.com,https://www.example.com`. No wildcard, path, or trailing slash. Native Flutter requests without an Origin header are allowed. |

### Required only when using each provider feature

| Variables | Feature |
| --- | --- |
| `STRIPE_API_KEY`, `STRIPE_WEBHOOK_SECRET` | Course checkout and the signed `/api/webhook` payment confirmation. |
| `MUX_TOKEN_ID`, `MUX_TOKEN_SECRET`, `MUX_SIGNING_KEY_ID`, `MUX_PRIVATE_KEY` | Mux asset management and signed video playback. `MUX_PRIVATE_KEY` is the base64-encoded PEM private key from a Mux signing key. |
| `UPLOADTHING_APP_ID`, `UPLOADTHING_SECRET` | Protected course/chapter file uploads. |
| `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL` | Live meeting tokens, sessions, and moderation. `LIVEKIT_URL` is the public `wss://` endpoint. |

Never put server keys, database URLs, or signing keys in Flutter `--dart-define`, `NEXT_PUBLIC_*` variables, source code, or GitHub Actions artifacts. Use separate provider accounts/keys for Preview and Production. Rotate every key that was ever committed to Git history.

## Database rollout

1. Back up the production database and review the migration SQL.
2. Set `DATABASE_URL` (pooled) and `DIRECT_URL` (direct) in a protected local shell or migration job.
3. From this directory run `npm ci`, then `npm run db:deploy`.
4. Deploy application code after the migration succeeds. Do not run migrations on function cold starts or from a public API route.

The copied Prisma schema keeps the existing Termini model names and table mappings so the new server can use the current database. Validate the migration history against the actual Neon database before the first production migration; do not reset or seed production data.

## API coverage

The route handlers implement the paths declared in `lib/core/config/api_constants.dart` in the Flutter project:

- Clerk-backed profile read/update; `/api/auth/sign-in` and `/api/auth/sign-up` explicitly return `410` because identity belongs to Clerk and demo credentials are disabled.
- Dashboard, categories, course search/details/checkout, course/chapters/attachments management, progress, and teacher analytics.
- Community spaces, posts (including media fields), comments, likes, settings, and new-post notifications.
- LiveKit sessions/tokens/admin, UploadThing callbacks, Stripe webhook, readiness at `/healthz`, and authorized video redirects at `/api/videos/:id`.

Every protected API route verifies the incoming Clerk JWT. The legacy `clerk_session_` prefix used by this app is stripped before verification. Caller-provided `X-User-Id`, demo tokens, and fake session IDs do not authenticate. The app must send the real Clerk session JWT in the Bearer header. Profile name and bio changes are written to Clerk; profile photos stay managed by Clerk and must use Clerk’s profile image upload flow.

Video bytes are served by Mux/UploadThing, not from Vercel’s temporary function disk. The video compatibility route checks course enrollment before redirecting to the provider. This is required because serverless local files do not provide durable media storage or a persistent byte-range streaming server.

### Secure existing Mux playback before production

The old server created **public** Mux playback IDs. New uploads in this server use signed IDs, and the API only gives enrolled users short-lived Mux playback tokens. Before switching production to this server:

1. Create a Mux signing key in the Mux dashboard. Put its ID in `MUX_SIGNING_KEY_ID` and its base64-encoded private PEM in `MUX_PRIVATE_KEY` in a protected shell and in Vercel Production.
2. Back up the database and confirm you can roll back the app deployment.
3. From `terserServer/`, run `npm run secure:mux` once with production `DATABASE_URL`, `MUX_TOKEN_ID`, and `MUX_TOKEN_SECRET`. It creates signed playback IDs, updates each `MuxData` row, and deletes the old public IDs. This revokes public playback URLs; schedule the migration with that impact in mind.
4. Deploy this server and matching Flutter build. The app player now reads the short-lived token returned with the enrolled chapter.
5. Confirm enrolled users play videos and non-enrolled users cannot retrieve playback IDs or source URLs.

Do not deploy the new video routes before the signing key is configured and existing playback IDs have been migrated. Direct UploadThing videos without a Mux asset still use their provider URL and should be ingested into Mux before treating the library as paywalled content.

## Production checklist

- Keep deploys on Vercel’s standard Next.js runtime; do not add `server.js`/`listen()`.
- Restrict teacher operations with `TEACHER_IDS`; verify this value before enabling teacher accounts.
- Keep Stripe webhooks signature-verified; point Stripe only at `/api/webhook`.
- Keep Clerk production allowed origins/domains synchronized with the app.
- Configure Vercel Firewall rate limits for `/api/**` write routes and monitor function logs. For stricter per-user distributed limits, add a shared rate-limit service before public launch; serverless in-memory counters are intentionally not used.
- Enable Vercel deployment protection for Preview deployments and branch protections in GitHub.
- Test rollback and database restore procedures before a real paid launch.
- Check `/healthz` and Vercel logs after every deployment. `/healthz` confirms the database connection only; it does not prove each provider is configured.

## Important limits / setup still needed

- This folder is prepared to deploy; it does not create your Vercel project or supply provider credentials.
- Checkout requires a live/test Stripe key and webhook secret. Mux, UploadThing, and LiveKit routes return provider configuration errors until their own credentials are set.
- Mobile notification data is served by `/api/community/notifications`; push notifications are not sent by this API. Android background delivery requires an installed push provider/service.
- The app’s Clerk session must include a real JWT. The UI’s old demo/offline sign-in fallback is intentionally not accepted by this production API.
- Current versions remain aligned to the dependencies already used by this repository. Upgrade dependencies through reviewed, locked changes rather than auto-moving production packages on each deploy.
