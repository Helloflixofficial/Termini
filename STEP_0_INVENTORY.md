# Step 0: Inspection Inventory & Screen Parity Checklist

## 1. Prisma Schema Inventory (`prisma/schema.prisma`)

### Core LMS Models
- **`Course`** (`title` table):
  - Fields: `id` (UUID), `userId` (String), `title` (String), `description` (String?), `imageUrl` (String?), `price` (Float?), `isPublished` (Boolean, default false), `categoryId` (String?), `createdAt` (DateTime), `updatedAt` (DateTime)
  - Relations: `attachments` (`Attachment[]`), `chapters` (`Chapter[]`), `purchases` (`Purchase[]`), `category` (`Category?`)
- **`Category`**:
  - Fields: `id` (UUID), `name` (String, unique)
  - Relations: `courses` (`Course[]`)
- **`Attachment`**:
  - Fields: `id` (UUID), `name` (String), `url` (String), `courseId` (String), `createdAt` (DateTime), `updatedAt` (DateTime)
  - Relations: `course` (`Course`)
- **`Chapter`**:
  - Fields: `id` (UUID), `title` (String), `description` (String?), `videoUrl` (String?), `position` (Int), `isPublished` (Boolean, default false), `isFree` (Boolean, default false), `courseId` (String), `createdAt` (DateTime), `updatedAt` (DateTime)
  - Relations: `course` (`Course`), `muxData` (`MuxData?`), `userProgress` (`UserProgress[]`)
- **`MuxData`**:
  - Fields: `id` (UUID), `assetId` (String), `playbackId` (String?), `chapterId` (String, unique)
  - Relations: `chapter` (`Chapter`)
- **`UserProgress`**:
  - Fields: `id` (UUID), `userId` (String), `chapterId` (String), `isCompleted` (Boolean, default false), `createdAt` (DateTime), `updatedAt` (DateTime)
  - Unique constraint: `[userId, chapterId]`
  - Relations: `chapter` (`Chapter`)
- **`Purchase`**:
  - Fields: `id` (UUID), `userId` (String), `courseId` (String), `createdAt` (DateTime), `updatedAt` (DateTime)
  - Unique constraint: `[userId, courseId]`
  - Relations: `course` (`Course`)
- **`StripeCustomer`**:
  - Fields: `id` (UUID), `userId` (String, unique), `stripeCustomerId` (String, unique), `createdAt` (DateTime), `updatedAt` (DateTime)
- **`MeetingSession`**:
  - Fields: `id` (UUID), `title` (String), `description` (String?), `roomName` (String, unique), `hostId` (String), `isActive` (Boolean, default true), `createdAt` (DateTime), `updatedAt` (DateTime)
- **`CommunitySpace`**:
  - Fields: `id` (UUID), `name` (String), `slug` (String), `description` (String?), `color` (String), `ownerId` (String), `createdAt` (DateTime), `updatedAt` (DateTime)
  - Unique constraint: `[ownerId, slug]`
  - Relations: `posts` (`CommunityPost[]`)
- **`CommunitySettings`**:
  - Fields: `id` (UUID), `ownerId` (String, unique), `communityName` (String), `tagline` (String), `welcomeMessage` (String?), `allowStudentPosts` (Boolean), `allowStudentComments` (Boolean), `requirePostApproval` (Boolean), `showMemberCount` (Boolean), `createdAt` (DateTime), `updatedAt` (DateTime)
- **`CommunityPost`**:
  - Fields: `id` (UUID), `title` (String), `content` (String), `authorId` (String), `ownerId` (String), `spaceId` (String), `isPinned` (Boolean), `isAnnouncement` (Boolean), `isApproved` (Boolean), `createdAt` (DateTime), `updatedAt` (DateTime)
  - Relations: `space` (`CommunitySpace`), `comments` (`CommunityComment[]`)
- **`CommunityComment`**:
  - Fields: `id` (UUID), `content` (String), `authorId` (String), `ownerId` (String), `postId` (String), `createdAt` (DateTime), `updatedAt` (DateTime)
  - Relations: `post` (`CommunityPost`)

---

## 2. Routes Under `app/`

### Public / Auth
- `(auth)/sign-in/[[...sign-in]]`: Clerk Sign In
- `(auth)/sign-up/[[...sign-up]]`: Clerk Sign Up

### Student Workspace
- `(dashboard)/(root)` (`/`): Dashboard showing Courses in Progress and Completed Courses with progress percentages and metric summary cards.
- `(dashboard)/search` (`/search`): Course Search & Catalog with Category horizontal filter chips, search input, and course grid cards.
- `(dashboard)/community` (`/community`): Community hub with spaces, pinned announcements, and posts.
- `(course)/course/[courseId]` (`/course/:courseId`): Course landing/redirect to first published chapter.
- `(course)/course/[courseId]/chapters/[chapterId]` (`/course/:courseId/chapters/:chapterId`): Chapter player with Mux video streaming, free preview banner, locked state, completion toggle, chapter navigation sidebar, and downloadable attachments.
- `meet/[roomName]` (`/meet/:roomName`): LiveKit live class room with camera, microphone, screen sharing, participants list, live chat, and hand-raising.

### Teacher Studio
- `(dashboard)/teacher/courses` (`/teacher/courses`): Table list of teacher's created courses with title, price, published status, and edit link.
- `(dashboard)/teacher/create` (`/teacher/create`): Create course screen with course title form.
- `(dashboard)/teacher/courses/[courseId]` (`/teacher/courses/:courseId`): Course setup editor:
  - Title form
  - Description form (rich text/markdown)
  - Image upload form (UploadThing)
  - Category selector
  - Price form (USD)
  - Course attachments upload/delete
  - Chapters list with drag-and-drop reordering, creation, and publish status
  - Course actions (Publish, Unpublish, Delete)
- `(dashboard)/teacher/courses/[courseId]/chapters/[chapterId]` (`/teacher/courses/:courseId/chapters/:chapterId`): Chapter setup editor:
  - Chapter title
  - Chapter description
  - Free preview toggle
  - Video upload form (Mux integration)
  - Chapter actions (Publish, Unpublish, Delete)
- `(dashboard)/teacher/analytics` (`/teacher/analytics`): Analytics dashboard with total revenue, total sales, sales by month bar chart, category breakdown, and course performance table.
- `(dashboard)/teacher/meet` (`/teacher/meet`): ShortMeet live class manager with create session modal, active/ended session filters, room copy links, and direct join.
- `(dashboard)/teacher/community` (`/teacher/community`): Community admin and moderation dashboard.
- `(dashboard)/teacher/community/settings` (`/teacher/community/settings`): Community configuration (names, permissions, approvals).

---

## 3. API Handlers (`app/api/**`)

| Method | Path | Auth | Request Body | Response Shape |
|---|---|---|---|---|
| `GET` | `/api/dashboard` *(New read route)* | Bearer Token | None | `{ completedCourses: Course[], coursesInProgress: Course[] }` |
| `GET` | `/api/categories` *(New read route)* | Public / Bearer | None | `Category[]` |
| `GET` | `/api/courses` *(New read route)* | Optional Bearer | Query: `title`, `categoryId` | `CourseWithProgress[]` |
| `POST` | `/api/courses` | Teacher | `{ title: string }` | `Course` |
| `GET` | `/api/courses/[courseId]` *(New read route)* | Bearer | None | `CourseWithDetails` |
| `PATCH` | `/api/courses/[courseId]` | Teacher | Partial Course fields | `Course` |
| `DELETE` | `/api/courses/[courseId]` | Teacher | None | `Course` |
| `PATCH` | `/api/courses/[courseId]/publish` | Teacher | None | `Course` |
| `PATCH` | `/api/courses/[courseId]/unpublish` | Teacher | None | `Course` |
| `POST` | `/api/courses/[courseId]/attachments` | Teacher | `{ url: string, name: string }` | `Attachment` |
| `DELETE` | `/api/courses/[courseId]/attachments/[attachmentId]` | Teacher | None | `Attachment` |
| `POST` | `/api/courses/[courseId]/chapters` | Teacher | `{ title: string }` | `Chapter` |
| `PUT` | `/api/courses/[courseId]/chapters/reorder` | Teacher | `{ list: { id: string, position: number }[] }` | `Success` |
| `GET` | `/api/courses/[courseId]/chapters/[chapterId]` *(New read route)* | Bearer | None | Chapter player payload (course, chapter, muxData, purchase, attachments, nextChapter, userProgress) |
| `PATCH` | `/api/courses/[courseId]/chapters/[chapterId]` | Teacher | Partial chapter fields (`videoUrl`, `title`, etc.) | `Chapter` |
| `DELETE` | `/api/courses/[courseId]/chapters/[chapterId]` | Teacher | None | `Chapter` |
| `PATCH` | `/api/courses/[courseId]/chapters/[chapterId]/publish` | Teacher | None | `Chapter` |
| `PATCH` | `/api/courses/[courseId]/chapters/[chapterId]/unpublish` | Teacher | None | `Chapter` |
| `PUT` | `/api/courses/[courseId]/chapters/[chapterId]/progress` | Bearer | `{ isCompleted: boolean }` | `UserProgress` |
| `POST` | `/api/courses/[courseId]/checkout` | Bearer | None | `{ url: string }` |
| `POST` | `/api/livekit/sessions` | Teacher | `{ title: string, description?: string }` | `MeetingSession` |
| `GET` | `/api/livekit/sessions` | Bearer | None | `MeetingSession[]` |
| `DELETE` | `/api/livekit/sessions/[sessionId]` | Teacher | None | `MeetingSession` |
| `GET` | `/api/livekit/token` | Bearer | Query: `room` | `{ token: string, participantName: string, isHost: boolean }` |
| `POST` | `/api/livekit/admin` | Teacher | `{ action, roomName, participantIdentity }` | Status |
| `GET` | `/api/teacher/courses` *(New read route)* | Teacher | None | `Course[]` |
| `GET` | `/api/teacher/analytics` *(New read route)* | Teacher | None | `AnalyticsSnapshot` |
| `GET/POST` | `/api/community/spaces` | Bearer | `{ name, slug, description, color }` | `CommunitySpace[]` / `CommunitySpace` |
| `GET/POST` | `/api/community/posts` | Bearer | Query / `{ title, content, spaceId }` | `CommunityPost[]` / `CommunityPost` |
| `GET/POST` | `/api/community/posts/[postId]/comments` | Bearer | `{ content: string }` | `CommunityComment[]` / `CommunityComment` |

---

## 4. Flows & Middleware

- **Clerk Authentication**: Bearer token authentication via `Authorization: Bearer <session_token>`.
- **Teacher Authorization**: Checked via `isTeacher(userId)` based on comma-separated `NEXT_PUBLIC_TEACHER_ID`.
- **Stripe Checkout**:
  - Endpoint creates a Stripe Checkout Session with `success_url` and `cancel_url`.
  - App opens the checkout URL in an external browser or custom tab, then returns via deep link (`termini://checkout/success`).
  - Webhook verifies signature and creates `Purchase` record in database.
- **Mux Video Flow**:
  - Teacher uploads video file.
  - Backend creates Mux asset with public playback policy and stores `assetId` and `playbackId` in `MuxData`.
  - Client plays HLS stream from `https://stream.mux.com/{playbackId}.m3u8`.
- **UploadThing / File Upload**:
  - Presigned upload endpoint for course images and attachments.
- **LiveKit Live Classes**:
  - Client requests token from `/api/livekit/token?room={roomName}`.
  - Connects to LiveKit WebSocket server with token.
  - Video/Audio publishing, subscription, camera/mic toggling, participant grid, and live chat.

---

## 5. Visual System (Tailwind / shadcn Palette)

- **Border Radius**: `8px` (`0.5rem`)
- **Light Theme**:
  - Background: `#FFFFFF`
  - Foreground: `#0A0A0A`
  - Card: `#FFFFFF`
  - Primary: `#171717` (foreground `#FAFAFA`)
  - Secondary: `#F5F5F5` (foreground `#171717`)
  - Muted: `#F5F5F5` (foreground `#737373`)
  - Accent / Border: `#E5E5E5`
  - Destructive: `#EF4444`
- **Dark Theme**:
  - Background: `#0A0A0A`
  - Foreground: `#FAFAFA`
  - Card: `#121212`
  - Primary: `#FAFAFA` (foreground `#171717`)
  - Secondary: `#262626`
  - Muted: `#262626` (foreground `#A3A3A3`)
  - Accent / Border: `#262626`
  - Destructive: `#7F1D1D`
- **Chart Palette**:
  - Chart 1: `#E76E50`
  - Chart 2: `#2A9D90`
  - Chart 3: `#274754`
  - Chart 4: `#E8C468`
  - Chart 5: `#F4A462`
- **Navigation Layout**:
  - Desktop/Expanded (>1024px): Persistent Left Sidebar with Logo, Learning/Studio mode switcher, route navigation, and user avatar. Top bar with search and Theme Toggle.
  - Tablet/Medium (600-1024px): Collapsed NavigationRail with tooltips.
  - Mobile/Compact (<600px): Bottom NavigationBar + Hamburger Drawer + App Bar.

---

## 6. Screen-by-Screen Parity Checklist

| # | Screen | Web Route | Flutter Route / Component | Parity Status |
|---|---|---|---|---|
| 1 | Sign In | `/sign-in` | `/sign-in` (Clerk Auth Screen) | PENDING |
| 2 | Sign Up | `/sign-up` | `/sign-up` (Clerk Register Screen) | PENDING |
| 3 | Student Dashboard | `/` | `/` (DashboardScreen) | PENDING |
| 4 | Browse & Search | `/search` | `/search` (SearchScreen) | PENDING |
| 5 | Course Detail & Player | `/course/[id]/chapters/[id]` | `/course/:courseId/chapters/:chapterId` (ChapterPlayerScreen) | PENDING |
| 6 | Stripe Checkout Return | `/course/[id]?success=1` | Deep Link `termini://checkout/success` | PENDING |
| 7 | Live Class (ShortMeet) | `/meet/[roomName]` | `/meet/:roomName` (LiveMeetScreen) | PENDING |
| 8 | Community Hub | `/community` | `/community` (CommunityScreen) | PENDING |
| 9 | Teacher Courses List | `/teacher/courses` | `/teacher/courses` (TeacherCoursesScreen) | PENDING |
| 10 | Teacher Create Course | `/teacher/create` | `/teacher/create` (CreateCourseScreen) | PENDING |
| 11 | Teacher Edit Course | `/teacher/courses/[id]` | `/teacher/courses/:id` (CourseEditorScreen) | PENDING |
| 12 | Teacher Edit Chapter | `/teacher/courses/[id]/chapters/[id]` | `/teacher/courses/:id/chapters/:chapterId` (ChapterEditorScreen) | PENDING |
| 13 | Teacher Analytics | `/teacher/analytics` | `/teacher/analytics` (TeacherAnalyticsScreen) | PENDING |
| 14 | Teacher Live Sessions | `/teacher/meet` | `/teacher/meet` (TeacherMeetScreen) | PENDING |
| 15 | Teacher Community Settings | `/teacher/community/settings` | `/teacher/community/settings` (CommunitySettingsScreen) | PENDING |
| 16 | User Profile & Settings | Clerk UserButton | `/profile` (ProfileScreen) | PENDING |
