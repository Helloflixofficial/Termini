# Backend Changes Documentation (`BACKEND_CHANGES.md`)

This document records all modifications made to the Next.js LMS backend (`OEPlatform`) to support the multiplatform Flutter application.

---

### 1. `next.config.js`
- **Change**: Added CORS headers to `/api/:path*` for both development and production environments.
- **Headers Added**:
  - `Access-Control-Allow-Origin: *`
  - `Access-Control-Allow-Methods: GET, DELETE, PATCH, POST, PUT, OPTIONS`
  - `Access-Control-Allow-Headers: X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization`
  - `Access-Control-Allow-Credentials: true`
- **Purpose**: Enables seamless communication from Flutter Web, Mobile, and Desktop HTTP clients without encountering CORS browser security or header rejection errors.

---

### 2. `app/api/dashboard/route.ts` *(New Endpoint)*
- **Method**: `GET`, `OPTIONS`
- **Authentication**: Bearer Token (Clerk `auth()`)
- **Action**: Invokes `getDashboardCourses(userId)`.
- **Response**: `{ completedCourses: DashboardCourse[], coursesInProgress: DashboardCourse[] }`
- **Purpose**: Exposes the student dashboard course data previously executed as a React Server Component directly in `app/(dashboard)/(routes)/(root)/page.tsx`.

---

### 3. `app/api/categories/route.ts` *(New Endpoint)*
- **Method**: `GET`, `OPTIONS`
- **Authentication**: Public / Optional Bearer
- **Action**: Queries `db.category.findMany({ orderBy: { name: "asc" } })`.
- **Response**: `Category[]`
- **Purpose**: Provides category filter chips for the search and browse catalog.

---

### 4. `app/api/courses/route.ts` *(Updated)*
- **Added Methods**: `GET`, `OPTIONS`
- **Authentication**: Public / Optional Bearer
- **Action**: Invokes `getCourses({ userId, title, categoryId })`.
- **Response**: `CourseWithProgressWithCategory[]`
- **Purpose**: Serves course listings filtered by search query or category, complete with calculated learner progress.

---

### 5. `app/api/courses/[courseId]/route.ts` *(Updated)*
- **Added Methods**: `GET`, `OPTIONS`
- **Authentication**: Optional Bearer
- **Action**: Fetches course by ID, including its ordered chapters, attachments, category, and user progress.
- **Response**: Full course object with chapters and progress.
- **Purpose**: Enables the Flutter app to retrieve full course details for display and editing.

---

### 6. `app/api/courses/[courseId]/chapters/[chapterId]/route.ts` *(Updated)*
- **Added Methods**: `GET`, `OPTIONS`
- **Authentication**: Optional Bearer
- **Action**: Calls `getChapter({ userId, courseId, chapterId })`.
- **Response**: `{ course, chapter, muxData, purchase, attachments, nextChapter, userProgress }`
- **Purpose**: Returns all player data, including Mux playback ID, lock status, and attachments.

---

### 7. `app/api/teacher/courses/route.ts` *(New Endpoint)*
- **Method**: `GET`, `OPTIONS`
- **Authentication**: Teacher Bearer Token (`isTeacher(userId)`)
- **Action**: Queries teacher's courses with chapters and categories.
- **Response**: `Course[]`
- **Purpose**: Supplies the course management list in the Teacher Studio.

---

### 8. `app/api/teacher/analytics/route.ts` *(New Endpoint)*
- **Method**: `GET`, `OPTIONS`
- **Authentication**: Teacher Bearer Token (`isTeacher(userId)`)
- **Action**: Invokes `getAnalytics(userId)`.
- **Response**: `AnalyticsSnapshot` (total revenue, sales, monthly metrics, course performance).
- **Purpose**: Provides data for the Teacher Analytics dashboard and charts.

---

### 9. `app/api/courses/[courseId]/checkout/route.ts` *(Updated)*
- **Change**: Added support for optional `returnUrl` in the JSON request body and added `OPTIONS` preflight handling.
- **Purpose**: Allows mobile apps to provide deep link return URLs (e.g. `termini://course/{courseId}`) for the Stripe Checkout web redirect flow.
