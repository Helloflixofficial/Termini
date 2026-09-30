const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { verifyToken } = require('@clerk/backend');
const { AccessToken } = require('livekit-server-sdk');

const MAX_BODY_BYTES = 1024 * 1024;
const VIDEO_ACCESS_CACHE_TTL_MS = 15000;
const MAX_VIDEO_ACCESS_CACHE_ENTRIES = 5000;
const videoAccessCache = new Map();

// ─── Load .env manually (no dotenv dep required) ─────────────────────────────
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
  fs.readFileSync(envPath, 'utf8').split(/\r?\n/).forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const idx = trimmed.indexOf('=');
      if (idx !== -1) {
        const key = trimmed.substring(0, idx).trim();
        let val = trimmed.substring(idx + 1).trim();
        if (val.length >= 2 && ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'")))) {
          val = val.slice(1, -1);
        }
        if (!process.env[key]) process.env[key] = val;
      }
    }
  });
}

const PORT = Number.parseInt(process.env.PORT || '3000', 10);
const isProduction = process.env.NODE_ENV === 'production';

// ─── Real Neon PostgreSQL connection ─────────────────────────────────────────
const { Pool } = require('pg');
const databaseUrl = process.env.DATABASE_URL || process.env.DIRECT_URL;
const pool = new Pool({
  connectionString: databaseUrl,
  ssl: { rejectUnauthorized: false },
  max: Math.min(50, Math.max(1, Number.parseInt(process.env.PG_POOL_MAX || '5', 10) || 5)),
  connectionTimeoutMillis: 10000,
  idleTimeoutMillis: 30000,
});

pool.on('error', (err) => {
  console.error('[DB] Idle connection error:', err.code || err.name || 'unknown error');
});

// ─── DB query helpers ─────────────────────────────────────────────────────────
async function dbQuery(sql, params = []) {
  const result = await pool.query(sql, params);
  return result.rows;
}

async function canUserWatchChapter(chapterId, userId) {
  const key = `${userId}:${chapterId}`;
  const cached = videoAccessCache.get(key);
  if (cached && cached.expiresAt > Date.now()) return cached.allowed;
  if (cached) videoAccessCache.delete(key);

  const rows = await dbQuery(
    `SELECT ch."isFree",
            EXISTS(SELECT 1 FROM "Purchase" p WHERE p."courseId" = ch."courseId" AND p."userId" = $2) AS "isPurchased"
     FROM "Chapter" ch WHERE ch."id" = $1 LIMIT 1`,
    [chapterId, userId],
  );
  const allowed = rows.length > 0 && (rows[0].isFree || rows[0].isPurchased);
  if (allowed) {
    if (videoAccessCache.size >= MAX_VIDEO_ACCESS_CACHE_ENTRIES) {
      const oldestKey = videoAccessCache.keys().next().value;
      if (oldestKey) videoAccessCache.delete(oldestKey);
    }
    videoAccessCache.set(key, { allowed, expiresAt: Date.now() + VIDEO_ACCESS_CACHE_TTL_MS });
  }
  return allowed;
}

// Load all published courses with chapters + mux data + category from DB
async function loadCoursesFromDB(filterUserId = null, publishedOnly = false, options = {}) {
  // Note: Prisma mapped Course -> "title" table in this schema
  const filters = [];
  const params = [];
  if (publishedOnly) filters.push('c."isPublished" = true');
  if (filterUserId) {
    params.push(filterUserId);
    filters.push(`c."userId" = $${params.length}`);
  }
  if (options.courseId) {
    params.push(options.courseId);
    filters.push(`c."id" = $${params.length}`);
  }
  if (Array.isArray(options.courseIds)) {
    if (options.courseIds.length === 0) return [];
    params.push(options.courseIds);
    filters.push(`c."id" = ANY($${params.length}::text[])`);
  }
  if (options.categoryId) {
    params.push(options.categoryId);
    filters.push(`c."categoryId" = $${params.length}`);
  }
  if (options.title) {
    params.push(`%${options.title.replace(/[\\%_]/g, '\\$&')}%`);
    filters.push(`c."title" ILIKE $${params.length} ESCAPE '\\'`);
  }
  const courseWhere = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

  const courseRows = await dbQuery(`
    SELECT c.*, cat."name" as "categoryName"
    FROM "title" c
    LEFT JOIN "Category" cat ON c."categoryId" = cat."id"
    ${courseWhere}
    ORDER BY c."updatedAt" DESC
  `, params);

  if (courseRows.length === 0) return [];

  const courseIds = courseRows.map(c => c.id);
  const placeholders = courseIds.map((_, i) => `$${i + 1}`).join(',');

  // Load chapters
  const includeMux = options.includeMux !== false;
  const mediaColumns = includeMux
    ? 'md."assetId", md."playbackId", md."id" as "muxId"'
    : 'NULL::text AS "assetId", NULL::text AS "playbackId", NULL::text AS "muxId"';
  const mediaJoin = includeMux ? 'LEFT JOIN "MuxData" md ON md."chapterId" = ch."id"' : '';
  const chapterRows = await dbQuery(`
    SELECT ch.*, ${mediaColumns}
    FROM "Chapter" ch
    ${mediaJoin}
    WHERE ch."courseId" IN (${placeholders})
    ORDER BY ch."position" ASC
  `, courseIds);

  // Group chapters by courseId
  const chaptersByCourse = {};
  for (const ch of chapterRows) {
    if (!chaptersByCourse[ch.courseId]) chaptersByCourse[ch.courseId] = [];
    chaptersByCourse[ch.courseId].push({
      id: ch.id,
      title: ch.title,
      description: ch.description,
      videoUrl: ch.videoUrl,
      position: ch.position,
      isPublished: ch.isPublished,
      isFree: ch.isFree,
      courseId: ch.courseId,
      createdAt: ch.createdAt,
      updatedAt: ch.updatedAt,
      muxData: ch.playbackId ? {
        id: ch.muxId,
        assetId: ch.assetId,
        playbackId: ch.playbackId,
        chapterId: ch.id,
      } : null,
    });
  }

  return courseRows.map(c => ({
    id: c.id,
    userId: c.userId,
    title: c.title,
    description: c.description,
    imageUrl: c.imageUrl,
    price: c.price,
    isPublished: c.isPublished,
    categoryId: c.categoryId,
    category: c.categoryId ? { id: c.categoryId, name: c.categoryName } : null,
    createdAt: c.createdAt,
    updatedAt: c.updatedAt,
    chapters: (chaptersByCourse[c.id] || []),
  }));
}

// Load categories from DB
async function loadCategoriesFromDB() {
  const rows = await dbQuery('SELECT * FROM "Category" ORDER BY "name" ASC');
  return rows.map(r => ({ id: r.id, name: r.name }));
}

function getCommunityOwnerId() {
  return (process.env.NEXT_PUBLIC_TEACHER_ID || '').split(',')[0].trim();
}

function safeHttpsUrl(value) {
  if (typeof value !== 'string' || value.length > 2048) return null;
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'https:' ? parsed.toString() : null;
  } catch (_) {
    return null;
  }
}

async function loadCommunitySpacesFromDB() {
  const ownerId = getCommunityOwnerId();
  if (!ownerId) throw new Error('Community owner is not configured');

  return dbQuery(
    `SELECT "id", "name", "slug", "description", "color"
     FROM "CommunitySpace"
     WHERE "ownerId" = $1
     ORDER BY "createdAt" ASC`,
    [ownerId],
  );
}

async function loadCommunityPostsFromDB(spaceId, userId) {
  const ownerId = getCommunityOwnerId();
  if (!ownerId) throw new Error('Community owner is not configured');

  const params = [ownerId];
  let spaceFilter = '';
  if (spaceId) {
    params.push(spaceId);
    spaceFilter = `AND p."spaceId" = $${params.length}`;
  }
  const userParam = userId ? (params.push(userId), `$${params.length}`) : 'NULL';
  const teacherIds = (process.env.NEXT_PUBLIC_TEACHER_ID || '').split(',').map(id => id.trim());
  const isTeacherViewer = teacherIds.includes(userId) || (!isProduction && Boolean(users[userId]?.isTeacher));
  let approvalFilter = '';
  if (!isTeacherViewer && userId) {
    params.push(userId);
    approvalFilter = `AND (p."isApproved" = true OR p."authorId" = $${params.length})`;
  }

  return dbQuery(
    `SELECT
       p."id", p."title", p."content", p."authorId", p."ownerId", p."spaceId",
       p."isPinned", p."isAnnouncement", p."isApproved", p."createdAt",
       p."mediaUrl", p."mediaType", p."linkUrl", p."linkTitle",
       p."authorName", p."authorImageUrl",
       COALESCE(l."likesCount", 0)::int AS "likesCount",
       COALESCE(l."isLikedByMe", false) AS "isLikedByMe",
       COALESCE(comments_data."comments", '[]'::json) AS "comments",
       (SELECT COUNT(*)::int FROM "CommunityComment" cc WHERE cc."postId" = p."id") AS "commentsCount",
       json_build_object('id', s."id", 'name', s."name", 'color', s."color") AS "space"
     FROM "CommunityPost" p
     JOIN "CommunitySpace" s ON s."id" = p."spaceId"
     LEFT JOIN LATERAL (
       SELECT COUNT(*) AS "likesCount",
              BOOL_OR("userId" = ${userParam}) AS "isLikedByMe"
       FROM "CommunityLike" WHERE "postId" = p."id"
     ) l ON true
     LEFT JOIN LATERAL (
       SELECT COALESCE(json_agg(json_build_object(
         'id', c."id", 'content', c."content", 'authorId', c."authorId",
         'postId', c."postId", 'createdAt', c."createdAt",
         'authorName', c."authorName", 'authorImageUrl', c."authorImageUrl"
       ) ORDER BY c."createdAt" ASC), '[]'::json) AS "comments"
       FROM (
         SELECT "id", "content", "authorId", "postId", "createdAt", "authorName", "authorImageUrl"
         FROM "CommunityComment" WHERE "postId" = p."id"
         ORDER BY "createdAt" DESC LIMIT 20
       ) c
     ) comments_data ON true
     WHERE p."ownerId" = $1 ${spaceFilter} ${approvalFilter}
     ORDER BY p."isPinned" DESC, p."createdAt" DESC
     LIMIT 100`,
    params,
  );
}

// In-memory fallback for users (not in Neon LMS schema)
const users = {
  'student_learner_demo': {
    id: 'student_learner_demo',
    email: 'student@oeplatform.dev',
    firstName: 'Jordan',
    lastName: 'Learner',
    bio: 'Passionate student exploring cross-platform mobile development and cloud systems.',
    imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=256&q=80',
    isTeacher: false,
    joinedDate: 'January 2026',
  },
  'teacher_admin_demo': {
    id: 'teacher_admin_demo',
    email: 'teacher@oeplatform.dev',
    firstName: 'Alex',
    lastName: 'Instructor',
    bio: 'Senior Software Architect & Course Creator with over 10 years of industry experience.',
    imageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=256&q=80',
    isTeacher: true,
    joinedDate: 'September 2024',
  },
};

const categories = [
  { id: 'cat-cs', name: 'Computer Science' },
  { id: 'cat-music', name: 'Music' },
  { id: 'cat-fitness', name: 'Fitness' },
  { id: 'cat-photo', name: 'Photography' },
  { id: 'cat-account', name: 'Accounting' },
  { id: 'cat-eng', name: 'Engineering' },
  { id: 'cat-film', name: 'Filming' },
];

const courses = [
  {
    id: 'course-1',
    userId: 'teacher_admin_demo',
    title: 'Complete Flutter & Dart Bootcamp 2026',
    description: 'Master Flutter and Dart by building production-grade iOS, Android, and Web apps with modern architecture, Riverpod, clean code, and cloud backends.',
    imageUrl: 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?auto=format&fit=crop&w=800&q=80',
    price: 49.99,
    isPublished: true,
    categoryId: 'cat-cs',
    category: { id: 'cat-cs', name: 'Computer Science' },
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    chapters: [
      {
        id: 'chap-101',
        title: 'Introduction to Flutter Architecture',
        description: 'Understand the widget tree, state management patterns, and the compilation pipeline.',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        position: 1,
        isPublished: true,
        isFree: true,
        muxData: { playbackId: 'mux-sample-01' },
      },
      {
        id: 'chap-102',
        title: 'Advanced Riverpod & Asynchronous State',
        description: 'Deep dive into StateNotifier, FutureProvider, and fine-grained reactive rebuilding.',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        position: 2,
        isPublished: true,
        isFree: false,
        muxData: { playbackId: 'mux-sample-02' },
      },
      {
        id: 'chap-103',
        title: 'Offline-First Storage & Network Layer',
        description: 'Building robust Dio interceptors, error handling, caching, and token refresh.',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        position: 3,
        isPublished: true,
        isFree: false,
        muxData: { playbackId: 'mux-sample-03' },
      },
    ],
  },
  {
    id: 'course-2',
    userId: 'teacher_admin_demo',
    title: 'Fullstack Next.js 14 & Prisma Masterclass',
    description: 'Learn Server Components, Server Actions, Prisma ORM, Neon PostgreSQL, Clerk Auth, Stripe Checkout, and LiveKit WebRTC from zero to production.',
    imageUrl: 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?auto=format&fit=crop&w=800&q=80',
    price: 79.99,
    isPublished: true,
    categoryId: 'cat-cs',
    category: { id: 'cat-cs', name: 'Computer Science' },
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    chapters: [
      {
        id: 'chap-201',
        title: 'Next.js App Router Fundamentals',
        description: 'Layouts, route groups, error boundaries, and streaming UI with Suspense.',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
        position: 1,
        isPublished: true,
        isFree: true,
        muxData: { playbackId: 'mux-sample-04' },
      },
      {
        id: 'chap-202',
        title: 'Prisma ORM & PostgreSQL Data Modeling',
        description: 'Schemas, relations, migrations, indexing, and transactional queries.',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
        position: 2,
        isPublished: true,
        isFree: false,
        muxData: { playbackId: 'mux-sample-05' },
      },
    ],
  },
  {
    id: 'course-3',
    userId: 'teacher_admin_demo',
    title: 'Modern UI/UX Design System with Figma',
    description: 'Craft harmonious typography, responsive grids, dark/light color tokens, micro-interactions, and component variants that convert.',
    imageUrl: 'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?auto=format&fit=crop&w=800&q=80',
    price: 34.99,
    isPublished: true,
    categoryId: 'cat-film',
    category: { id: 'cat-film', name: 'Filming' },
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    chapters: [
      {
        id: 'chap-301',
        title: 'Design Tokens & Visual Hierarchy',
        description: 'Setting up spacing scales, typography ramps, and accessibility contrast ratios.',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyBlazes.mp4',
        position: 1,
        isPublished: true,
        isFree: true,
        muxData: { playbackId: 'mux-sample-06' },
      },
    ],
  },
];

// Purchases: userId -> Set of courseIds
const purchases = {
  'student_learner_demo': new Set(['course-1']),
};

// UserProgress: userId -> { [chapterId]: boolean }
const userProgress = {
  'student_learner_demo': {
    'chap-101': true,
  },
};

// Community Spaces
const communitySpaces = [
  {
    id: 'space-general',
    name: 'General Discussion',
    slug: 'general',
    description: 'Connect with peers, share learning milestones, and discuss tech topics.',
    color: '#0284c7',
  },
  {
    id: 'space-flutter',
    name: 'Flutter Engineers',
    slug: 'flutter-engineers',
    description: 'Mobile architecture, state management tips, and cross-platform UI showcases.',
    color: '#10b981',
  },
  {
    id: 'space-ask',
    name: 'Ask an Instructor',
    slug: 'ask-instructor',
    description: 'Got stuck on a chapter? Post your question here for feedback.',
    color: '#8b5cf6',
  },
];

// Community Posts
const communityPosts = [
  {
    id: 'post-1',
    spaceId: 'space-flutter',
    userId: 'student_learner_demo',
    authorName: 'Jordan Learner',
    authorImageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=256&q=80',
    title: 'Just finished Chapter 1 of the Flutter Bootcamp!',
    content: 'The explanations on widget tree lifecycle and rendering pipeline were super clear. Excited to implement custom painters next!',
    createdAt: new Date(Date.now() - 3600000 * 4).toISOString(),
    likesCount: 12,
    comments: [
      {
        id: 'comm-1',
        authorName: 'Alex Instructor',
        content: 'Great work Jordan! Keep experimenting with CustomPainter and Impeller shaders.',
        createdAt: new Date(Date.now() - 3600000 * 2).toISOString(),
      },
    ],
  },
  {
    id: 'post-2',
    spaceId: 'space-general',
    userId: 'teacher_admin_demo',
    authorName: 'Alex Instructor',
    authorImageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=256&q=80',
    title: 'Live Q&A Session this Friday at 4 PM UTC',
    content: 'We will be reviewing student course submissions and talking about fullstack architecture with Next.js 14 and Flutter!',
    createdAt: new Date(Date.now() - 3600000 * 12).toISOString(),
    likesCount: 28,
    comments: [],
  },
];

// Meeting Sessions
const liveSessions = [
  {
    id: 'session-101',
    title: 'Weekly Live Coding & Office Hours',
    description: 'Live architecture review, state management deep dive, and Q&A.',
    roomName: 'room-office-hours-101',
    hostId: 'teacher_admin_demo',
    isActive: true,
    createdAt: new Date().toISOString(),
  },
];

// Auth & User Extraction Helper
function extractUserId(req) {
  const profileUserId = req.headers['x-user-id'];
  if (typeof profileUserId === 'string' && profileUserId.trim()) {
    return profileUserId.trim();
  }
  const authHeader = req.headers['authorization'] || '';
  if (authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    if (token.startsWith('demo_session_token_')) {
      return token.replace('demo_session_token_', '');
    }
    if (token.startsWith('session_token_')) {
      const parts = token.split('_');
      const id = parts.slice(3).join('_');
      return id || token;
    }
    return token;
  }
  return 'student_learner_demo'; // default dev user
}

async function resolveUserId(req) {
  if (!isProduction) return extractUserId(req);

  const authorization = req.headers.authorization || '';
  if (!authorization.startsWith('Bearer ')) return null;
  const bearer = authorization.slice(7).trim();
  const token = bearer.startsWith('clerk_session_')
    ? bearer.slice('clerk_session_'.length)
    : bearer;
  if (!token || !process.env.CLERK_SECRET_KEY) return null;

  const payload = await verifyToken(token, { secretKey: process.env.CLERK_SECRET_KEY });
  return typeof payload.sub === 'string' && payload.sub ? payload.sub : null;
}

async function addCoursePurchaseState(courses, userId) {
  if (!courses.length) return [];
  const courseIds = courses.map(course => course.id);
  const purchases = await dbQuery(
    `SELECT "id", "courseId" FROM "Purchase"
     WHERE "userId" = $1 AND "courseId" = ANY($2::text[])`,
    [userId, courseIds],
  );
  const purchaseByCourse = new Map(purchases.map(purchase => [purchase.courseId, purchase]));
  const enrolledCourses = courses.filter(course => purchaseByCourse.has(course.id));
  const chapterIds = enrolledCourses.flatMap(course =>
    (course.chapters || []).filter(chapter => chapter.isPublished).map(chapter => chapter.id),
  );
  const completed = chapterIds.length
    ? await dbQuery(
        `SELECT "chapterId" FROM "UserProgress"
         WHERE "userId" = $1 AND "isCompleted" = true AND "chapterId" = ANY($2::text[])`,
        [userId, chapterIds],
      )
    : [];
  const completedIds = new Set(completed.map(row => row.chapterId));

  return courses.map(course => {
    const purchase = purchaseByCourse.get(course.id);
    if (!purchase) return { ...course, isPurchased: false, purchases: [], progress: null };
    const chapters = (course.chapters || []).filter(chapter => chapter.isPublished);
    const completedCount = chapters.filter(chapter => completedIds.has(chapter.id)).length;
    const progress = chapters.length ? Math.round((completedCount / chapters.length) * 100) : 0;
    return { ...course, isPurchased: true, purchases: [purchase], progress };
  });
}

// CORS & Response Helpers
function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  res.end(JSON.stringify(data));
}

function sendCors(res) {
  res.writeHead(204, {
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-User-Id, Range',
    'Access-Control-Max-Age': '600',
  });
  res.end();
}

function applyCors(req, res) {
  const origin = req.headers.origin;
  if (!origin) return true;

  const configuredOrigins = (process.env.CORS_ORIGINS || '')
    .split(',')
    .map(value => value.trim())
    .filter(Boolean);
  let isAllowed = configuredOrigins.includes(origin);
  if (!isProduction && !isAllowed) {
    try {
      const parsedOrigin = new URL(origin);
      isAllowed = ['localhost', '127.0.0.1', '::1'].includes(parsedOrigin.hostname);
    } catch (_) {}
  }
  if (!isAllowed) return false;

  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Vary', 'Origin');
  return true;
}

// Request Body Parser
function parseBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let settled = false;
    const contentLength = Number.parseInt(req.headers['content-length'] || '0', 10);
    if (contentLength > MAX_BODY_BYTES) {
      const error = new Error('Request body is too large');
      error.statusCode = 413;
      req.resume();
      reject(error);
      return;
    }
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        if (!settled) {
          settled = true;
          const error = new Error('Request body is too large');
          error.statusCode = 413;
          reject(error);
          req.resume();
        }
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (settled) return;
      try {
        const body = Buffer.concat(chunks).toString('utf8');
        const parsed = body ? JSON.parse(body) : {};
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
          const error = new Error('JSON request body must be an object');
          error.statusCode = 400;
          reject(error);
          return;
        }
        settled = true;
        resolve(parsed);
      } catch (_) {
        const error = new Error('Request body contains invalid JSON');
        error.statusCode = 400;
        settled = true;
        reject(error);
      }
    });
    req.on('error', error => {
      if (!settled) {
        settled = true;
        reject(error);
      }
    });
  });
}

// Video Streaming Endpoint with Full HTTP 206 Byte Range Support (ExoPlayer compatible)
function serveVideoStream(req, res, chapterId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(chapterId)) {
    return sendJson(res, 404, { error: 'Video not found' });
  }
  const videoDir = path.join(__dirname, 'public', 'videos');
  const filePath = path.join(videoDir, `${chapterId}.mp4`);

  if (!fs.existsSync(filePath)) {
    return sendJson(res, 404, { error: 'Video file not found or not yet cached' });
  }

  let stat;
  try {
    stat = fs.statSync(filePath);
  } catch (_) {
    return sendJson(res, 404, { error: 'Video not found' });
  }
  if (!stat.isFile()) return sendJson(res, 404, { error: 'Video not found' });
  const fileSize = stat.size;
  const range = req.headers.range;

  if (req.method.toUpperCase() === 'HEAD') {
    res.writeHead(200, {
      'Content-Length': fileSize,
      'Accept-Ranges': 'bytes',
      'Content-Type': 'video/mp4',
      'Access-Control-Expose-Headers': 'Content-Range, Accept-Ranges, Content-Length',
    });
    return res.end();
  }

  if (range) {
    const match = /^bytes=(\d*)-(\d*)$/.exec(range);
    if (!match || (!match[1] && !match[2])) {
      res.writeHead(416, {
        'Content-Range': `bytes */${fileSize}`,
      });
      return res.end();
    }

    let start = match[1] ? Number(match[1]) : null;
    let end = match[2] ? Number(match[2]) : null;
    if (start === null) {
      const suffixLength = end;
      if (!Number.isSafeInteger(suffixLength) || suffixLength <= 0) {
        res.writeHead(416, { 'Content-Range': `bytes */${fileSize}` });
        return res.end();
      }
      start = Math.max(fileSize - suffixLength, 0);
      end = fileSize - 1;
    } else {
      if (!Number.isSafeInteger(start) || start >= fileSize || (end !== null && (!Number.isSafeInteger(end) || end < start))) {
        res.writeHead(416, { 'Content-Range': `bytes */${fileSize}` });
        return res.end();
      }
      end = Math.min(end ?? fileSize - 1, fileSize - 1);
    }

    const chunksize = end - start + 1;
    const file = fs.createReadStream(filePath, { start, end });
    res.writeHead(206, {
      'Content-Range': `bytes ${start}-${end}/${fileSize}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': chunksize,
      'Content-Type': 'video/mp4',
      'Access-Control-Expose-Headers': 'Content-Range, Accept-Ranges, Content-Length',
    });
    file.on('error', () => res.destroy());
    file.pipe(res);
  } else {
    res.writeHead(200, {
      'Content-Length': fileSize,
      'Accept-Ranges': 'bytes',
      'Content-Type': 'video/mp4',
      'Access-Control-Expose-Headers': 'Content-Range, Accept-Ranges, Content-Length',
    });
    const file = fs.createReadStream(filePath);
    file.on('error', () => res.destroy());
    file.pipe(res);
  }
}

// HTTP Server
const server = http.createServer((req, res) => {
  handleRequest(req, res).catch(error => {
    console.error('[HTTP] Unhandled request error:', error.code || error.name || 'unknown error');
    if (res.headersSent) return res.destroy();
    const statusCode = error.statusCode || (error instanceof URIError ? 400 : 500);
    return sendJson(res, statusCode, {
      error: error.statusCode ? error.message : (error instanceof URIError ? 'Invalid URL encoding' : 'Internal server error'),
    });
  });
});

async function handleRequest(req, res) {
  const parsedUrl = new URL(req.url, 'http://localhost');
  const query = Object.fromEntries(parsedUrl.searchParams.entries());
  const pathname = parsedUrl.pathname;
  const method = req.method.toUpperCase();

  if (!applyCors(req, res)) {
    return sendJson(res, 403, { error: 'Origin is not allowed' });
  }

  if (pathname === '/healthz' && method === 'GET') {
    try {
      await dbQuery('SELECT 1');
      return sendJson(res, 200, { status: 'ok', database: 'connected' });
    } catch (_) {
      return sendJson(res, 503, { status: 'degraded', database: 'unavailable' });
    }
  }

  // Handle CORS Preflight
  if (method === 'OPTIONS') {
    return sendCors(res);
  }

  let userId;
  try {
    userId = await resolveUserId(req);
  } catch (_) {
    return sendJson(res, 401, { error: 'Authentication required' });
  }
  if (!userId) return sendJson(res, 401, { error: 'Authentication required' });

  if (isProduction && (pathname === '/api/auth/sign-in' || pathname === '/api/auth/sign-up')) {
    return sendJson(res, 410, { error: 'Sign-in is managed by Clerk' });
  }

  // Video Streaming Endpoint (HTTP 206 Byte Range)
  const videoStreamMatch = pathname.match(/^\/api\/videos\/([^\/]+)$/);
  if (videoStreamMatch && (method === 'GET' || method === 'HEAD')) {
    const chapterId = videoStreamMatch[1];
    try {
      if (!await canUserWatchChapter(chapterId, userId)) {
        return sendJson(res, 403, { error: 'Video is unavailable or enrollment is required' });
      }
    } catch (error) {
      console.error('[Video] Database error:', error.code || error.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to verify video access' });
    }
    return serveVideoStream(req, res, chapterId);
  }

  // 1. Auth Sign In
  if (pathname === '/api/auth/sign-in' && method === 'POST') {
    const body = await parseBody(req);
    const email = body.email || '';
    const isTeacher = email.includes('teacher') || email.includes('admin');
    const uId = isTeacher ? 'teacher_admin_demo' : (users[email] ? email : `user_${email.replace(/[^a-zA-Z0-9]/g, '_')}`);
    
    if (!users[uId]) {
      users[uId] = {
        id: uId,
        email: email,
        firstName: email.split('@')[0] || 'User',
        lastName: '',
        bio: 'Enthusiastic learner at Termini LMS.',
        imageUrl: isTeacher
          ? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=256&q=80'
          : 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=256&q=80',
        isTeacher: isTeacher,
        joinedDate: 'September 2026',
      };
    }
    const user = users[uId];
    return sendJson(res, 200, {
      token: `session_token_${Date.now()}_${user.id}`,
      user: user,
    });
  }

  // 2. Auth Sign Up
  if (pathname === '/api/auth/sign-up' && method === 'POST') {
    const body = await parseBody(req);
    const email = body.email || 'user@oeplatform.dev';
    const uId = `user_${email.replace(/[^a-zA-Z0-9]/g, '_')}`;
    const user = {
      id: uId,
      email: email,
      firstName: body.firstName || email.split('@')[0],
      lastName: body.lastName || '',
      bio: 'Enthusiastic learner at Termini LMS.',
      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
      isTeacher: false,
      joinedDate: 'September 2026',
    };
    users[uId] = user;
    return sendJson(res, 200, {
      token: `session_token_${Date.now()}_${user.id}`,
      user: user,
    });
  }

  // 3. User Profile (GET & PUT)
  if ((pathname === '/api/user/profile' || pathname === '/api/user/me') && method === 'GET') {
    if (isProduction) {
      try {
        const [purchaseRows, progressRows] = await Promise.all([
          dbQuery('SELECT COUNT(*)::int AS count FROM "Purchase" WHERE "userId" = $1', [userId]),
          dbQuery('SELECT COUNT(*)::int AS count FROM "UserProgress" WHERE "userId" = $1 AND "isCompleted" = true', [userId]),
        ]);
        const configuredTeachers = (process.env.NEXT_PUBLIC_TEACHER_ID || '').split(',').map(id => id.trim());
        return sendJson(res, 200, {
          id: userId,
          email: '',
          firstName: '',
          lastName: '',
          bio: '',
          imageUrl: null,
          isTeacher: configuredTeachers.includes(userId),
          joinedDate: null,
          stats: {
            enrolledCoursesCount: purchaseRows[0].count,
            completedChaptersCount: progressRows[0].count,
            certificatesCount: 0,
            hoursLearned: 0,
          },
        });
      } catch (error) {
        console.error('[Profile] Database error:', error.code || error.name || 'unknown error');
        return sendJson(res, 500, { error: 'Unable to load profile data' });
      }
    }

    let user = users[userId];
    if (!user) {
      user = {
        id: userId,
        email: userId.includes('@') ? userId : '',
        firstName: userId.startsWith('teacher') ? 'Alex' : '',
        lastName: userId.startsWith('teacher') ? 'Instructor' : '',
        bio: '',
        imageUrl: userId.startsWith('teacher')
          ? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=256&q=80'
          : null,
        isTeacher: userId.startsWith('teacher'),
        joinedDate: 'January 2026',
      };
      users[userId] = user;
    }

    // Compute active stats
    const userPurchased = purchases[userId] || new Set();
    const userProg = userProgress[userId] || {};
    const completedChapters = Object.values(userProg).filter(Boolean).length;

    return sendJson(res, 200, {
      ...user,
      stats: {
        enrolledCoursesCount: userPurchased.size,
        completedChaptersCount: completedChapters,
        certificatesCount: completedChapters > 2 ? 1 : 0,
        hoursLearned: completedChapters * 1.5,
      },
    });
  }

  if ((pathname === '/api/user/profile' || pathname === '/api/user/me') && method === 'PUT') {
    if (isProduction) {
      return sendJson(res, 501, { error: 'Profile updates must be saved through Clerk' });
    }
    const body = await parseBody(req);
    let user = users[userId] || { id: userId };
    user.firstName = body.firstName !== undefined ? body.firstName : user.firstName;
    user.lastName = body.lastName !== undefined ? body.lastName : user.lastName;
    user.bio = body.bio !== undefined ? body.bio : user.bio;
    user.imageUrl = body.imageUrl !== undefined ? body.imageUrl : user.imageUrl;
    users[userId] = user;
    return sendJson(res, 200, user);
  }

  // 4. Dashboard Endpoint — real courses from Neon DB
  if (pathname === '/api/dashboard' && method === 'GET') {
    try {
      // Get purchases from DB for this user
      const purchaseRows = await dbQuery(
        'SELECT "courseId" FROM "Purchase" WHERE "userId" = $1',
        [userId]
      );
      const purchasedCourseIds = new Set(purchaseRows.map(r => r.courseId));
      if (purchasedCourseIds.size === 0) {
        return sendJson(res, 200, { completedCourses: [], coursesInProgress: [] });
      }

      // Only load courses the current student has purchased.
      const allCourses = await loadCoursesFromDB(null, true, {
        courseIds: [...purchasedCourseIds],
        includeMux: false,
      });

      // Get user progress from DB
      const progressRows = await dbQuery(
        'SELECT "chapterId", "isCompleted" FROM "UserProgress" WHERE "userId" = $1',
        [userId]
      );
      const userProg = {};
      for (const p of progressRows) {
        userProg[p.chapterId] = p.isCompleted;
      }

      const completedCourses = [];
      const coursesInProgress = [];

      // The dashboard represents enrolled courses only.
      const coursesToShow = allCourses.filter(c => purchasedCourseIds.has(c.id));

      for (const course of coursesToShow) {
        const totalChapters = course.chapters ? course.chapters.length : 0;
        let completedChapterCount = 0;
        if (course.chapters) {
          for (const chap of course.chapters) {
            if (userProg[chap.id]) completedChapterCount++;
          }
        }
        const progress = totalChapters > 0 ? (completedChapterCount / totalChapters) * 100 : 0;
        const courseWithProgress = { ...course, isPurchased: true, progress: Math.round(progress) };
        if (progress >= 100) {
          completedCourses.push(courseWithProgress);
        } else {
          coursesInProgress.push(courseWithProgress);
        }
      }

      return sendJson(res, 200, { completedCourses, coursesInProgress });
    } catch (dbErr) {
      console.error('[Dashboard] Database error:', dbErr.code || dbErr.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to load dashboard data' });
    }
  }

  // 5. Categories Endpoint — real from DB
  if (pathname === '/api/categories' && method === 'GET') {
    try {
      const cats = await loadCategoriesFromDB();
      return sendJson(res, 200, isProduction ? cats : (cats.length > 0 ? cats : categories));
    } catch (e) {
      return sendJson(res, isProduction ? 503 : 200,
        isProduction ? { error: 'Unable to load categories' } : categories);
    }
  }

  // 6. Courses Search & Catalog — real from DB
  if (pathname === '/api/courses' && method === 'GET') {
    try {
      const qTitle = typeof query.title === 'string'
        ? query.title.trim().slice(0, 120)
        : '';
      const qCategoryId = typeof query.categoryId === 'string'
        ? query.categoryId.slice(0, 128)
        : '';
      const allCourses = await addCoursePurchaseState(
        await loadCoursesFromDB(null, true, {
          ...(qTitle ? { title: qTitle } : {}),
          ...(qCategoryId ? { categoryId: qCategoryId } : {}),
          includeMux: false,
        }),
        userId,
      );
      return sendJson(res, 200, allCourses);
    } catch (e) {
      console.error('[Courses] Database error:', e.code || e.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to load courses' });
    }
  }

  // 7. Teacher Create Course (POST /api/courses)
  if (pathname === '/api/courses' && method === 'POST') {
    if (isProduction) {
      return sendJson(res, 501, { error: 'Course creation is not available on this API server' });
    }
    const body = await parseBody(req);
    const newCourse = {
      id: `course-${Date.now()}`,
      userId: userId,
      title: body.title || 'Untitled Course',
      description: '',
      imageUrl: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=800&q=80',
      price: 0,
      isPublished: false,
      categoryId: categories[0].id,
      category: categories[0],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      chapters: [],
    };
    courses.push(newCourse);
    return sendJson(res, 200, newCourse);
  }

  // 8. Single Course Detail (GET /api/courses/:id) — real from DB
  const singleCourseMatch = pathname.match(/^\/api\/courses\/([^\/]+)$/);
  if (singleCourseMatch && method === 'GET') {
    const courseId = singleCourseMatch[1];
    try {
      const coursesForId = await loadCoursesFromDB(null, false, { courseId });
      let course = (await addCoursePurchaseState(coursesForId, userId))[0];
      if (!course) return sendJson(res, 404, { error: 'Course not found' });
      if (isProduction && !course.isPurchased) {
        course = {
          ...course,
          chapters: course.chapters.map(chapter => ({
            ...chapter,
            muxData: chapter.isFree ? chapter.muxData : null,
          })),
        };
      }
      return sendJson(res, 200, course);
    } catch (e) {
      return sendJson(res, 500, { error: 'Unable to load course details' });
    }
  }

  // 9. Chapter Detail — real from DB
  const chapterMatch = pathname.match(/^\/api\/courses\/([^\/]+)\/chapters\/([^\/]+)$/);
  if (chapterMatch && method === 'GET') {
    const courseId = chapterMatch[1];
    const chapterId = chapterMatch[2];
    try {
      const coursesForId = await loadCoursesFromDB(null, false, { courseId });
      const course = coursesForId[0];
      if (!course) return sendJson(res, 404, { error: 'Course not found' });
      const chapter = course.chapters?.find(ch => ch.id === chapterId);
      if (!chapter) return sendJson(res, 404, { error: 'Chapter not found' });

      const purchaseRows = await dbQuery(
        'SELECT "id" FROM "Purchase" WHERE "userId" = $1 AND "courseId" = $2',
        [userId, courseId]
      );
      const hasPurchased = purchaseRows.length > 0;
      if (isProduction && !hasPurchased && !chapter.isFree) {
        return sendJson(res, 403, { error: 'Course enrollment is required for this chapter' });
      }

      const progressRows = await dbQuery(
        'SELECT "isCompleted" FROM "UserProgress" WHERE "userId" = $1 AND "chapterId" = $2',
        [userId, chapterId]
      );
      const isCompleted = progressRows.length > 0 ? progressRows[0].isCompleted : false;

      return sendJson(res, 200, {
        course,
        chapter,
        muxData: chapter.muxData,
        purchase: hasPurchased ? { id: purchaseRows[0].id, userId, courseId } : null,
        attachments: hasPurchased
          ? await dbQuery(
              `SELECT "id", "name", "url", "courseId" FROM "Attachment"
               WHERE "courseId" = $1 ORDER BY "createdAt" ASC`,
              [courseId],
            )
          : [],
        nextChapter: null,
        userProgress: { id: `prog-${chapterId}`, userId, chapterId, isCompleted },
      });
    } catch (e) {
      return sendJson(res, 500, { error: 'Unable to load chapter details' });
    }
  }

  // 10. Update Chapter Progress (PUT /api/courses/:courseId/chapters/:chapterId/progress)
  const progressMatch = pathname.match(/^\/api\/courses\/([^\/]+)\/chapters\/([^\/]+)\/progress$/);
  if (progressMatch && method === 'PUT') {
    const chapterId = progressMatch[2];
    const body = await parseBody(req);
    const isCompleted = body.isCompleted === true;

    try {
      const rows = await dbQuery(
        `INSERT INTO "UserProgress" ("id", "userId", "chapterId", "isCompleted", "createdAt", "updatedAt")
         VALUES ($1, $2, $3, $4, NOW(), NOW())
         ON CONFLICT ("userId", "chapterId")
         DO UPDATE SET "isCompleted" = EXCLUDED."isCompleted", "updatedAt" = NOW()
         RETURNING "id", "userId", "chapterId", "isCompleted"`,
        [crypto.randomUUID(), userId, chapterId, isCompleted],
      );
      return sendJson(res, 200, rows[0]);
    } catch (error) {
      console.error('[Progress] Database error:', error.code || error.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to update chapter progress' });
    }

  }

  // 11. Checkout Endpoint (POST /api/courses/:courseId/checkout)
  const checkoutMatch = pathname.match(/^\/api\/courses\/([^\/]+)\/checkout$/);
  if (checkoutMatch && method === 'POST') {
    if (isProduction) {
      return sendJson(res, 501, { error: 'Checkout is not configured on this API server' });
    }
    const courseId = checkoutMatch[1];
    if (!purchases[userId]) {
      purchases[userId] = new Set();
    }
    purchases[userId].add(courseId);
    return sendJson(res, 200, {
      url: `https://checkout.stripe.com/test_session?courseId=${courseId}`,
      success: true,
    });
  }

  // 12. Teacher Courses — real from DB
  if (pathname === '/api/teacher/courses' && method === 'GET') {
    try {
      // Load courses for this teacher userId (the Clerk user ID)
      const teacherCourses = await loadCoursesFromDB(userId, false, { includeMux: false });
      if (teacherCourses.length > 0 || isProduction) return sendJson(res, 200, teacherCourses);
      // Fallback: if userId doesn't match, return all courses for teacher_admin
      const allCourses = await loadCoursesFromDB('user_2ZrBFVtrrTrK0EbbS93RQHjQgX3', false, { includeMux: false });
      return sendJson(res, 200, allCourses);
    } catch (e) {
      console.error('[Teacher Courses] Database error:', e.code || e.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to load teacher courses' });
    }
  }

  // 13. Teacher Analytics (GET /api/teacher/analytics)
  if (pathname === '/api/teacher/analytics' && method === 'GET') {
    if (isProduction) {
      const teacherIds = (process.env.NEXT_PUBLIC_TEACHER_ID || '').split(',').map(id => id.trim()).filter(Boolean);
      if (!teacherIds.includes(userId)) return sendJson(res, 403, { error: 'Teacher access required' });
      try {
        const totals = await dbQuery(
          `SELECT COUNT(*)::int AS "totalSales",
                  COALESCE(SUM(c."price"), 0)::float AS "totalRevenue"
           FROM "Purchase" p
           JOIN "title" c ON c."id" = p."courseId"
           WHERE c."userId" = $1`,
          [userId],
        );
        const monthlyRows = await dbQuery(
          `SELECT DATE_TRUNC('month', p."createdAt") AS "month",
                  COALESCE(SUM(c."price"), 0)::float AS "total"
           FROM "Purchase" p
           JOIN "title" c ON c."id" = p."courseId"
           WHERE c."userId" = $1
             AND p."createdAt" >= DATE_TRUNC('month', NOW()) - INTERVAL '5 months'
           GROUP BY DATE_TRUNC('month', p."createdAt")
           ORDER BY "month" ASC`,
          [userId],
        );
        const monthlyTotals = new Map(monthlyRows.map(row => [
          new Date(row.month).toISOString().slice(0, 7),
          Number(row.total),
        ]));
        const now = new Date();
        const data = Array.from({ length: 6 }, (_, index) => {
          const month = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 5 + index, 1));
          return {
            name: month.toLocaleString('en-US', { month: 'short', timeZone: 'UTC' }),
            total: monthlyTotals.get(month.toISOString().slice(0, 7)) || 0,
          };
        });
        return sendJson(res, 200, {
          data,
          totalRevenue: Number(totals[0]?.totalRevenue || 0),
          totalSales: Number(totals[0]?.totalSales || 0),
        });
      } catch (error) {
        console.error('[Teacher Analytics] Database error:', error.code || error.name || 'unknown error');
        return sendJson(res, 500, { error: 'Unable to load teacher analytics' });
      }
    }
    return sendJson(res, 200, {
      data: [
        { name: 'Jan', total: 1200 },
        { name: 'Feb', total: 1900 },
        { name: 'Mar', total: 2400 },
        { name: 'Apr', total: 3100 },
        { name: 'May', total: 2800 },
        { name: 'Jun', total: 4200 },
      ],
      totalRevenue: 15600,
      totalSales: 248,
    });
  }

  // 14. Community Spaces (GET /api/community/spaces)
  if (pathname === '/api/community/spaces' && method === 'GET') {
    try {
      return sendJson(res, 200, await loadCommunitySpacesFromDB());
    } catch (e) {
      console.error('[Community Spaces] Database error:', e.code || e.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to load community spaces' });
    }
  }

  if (pathname === '/api/community/settings' && (method === 'GET' || method === 'PATCH')) {
    const ownerId = getCommunityOwnerId();
    const teacherIds = (process.env.NEXT_PUBLIC_TEACHER_ID || '')
      .split(',').map(id => id.trim()).filter(Boolean);
    const isTeacher = teacherIds.includes(userId) || (!isProduction && Boolean(users[userId]?.isTeacher));
    if (!ownerId || !isTeacher) {
      return sendJson(res, 403, { error: 'Teacher access required' });
    }

    const fields = `"communityName", "tagline", "welcomeMessage", "allowStudentPosts",
                    "allowStudentComments", "requirePostApproval", "showMemberCount"`;
    try {
      if (method === 'GET') {
        const settings = await dbQuery(
          `SELECT ${fields} FROM "CommunitySettings" WHERE "ownerId" = $1 LIMIT 1`,
          [ownerId],
        );
        return sendJson(res, 200, settings[0] || {
          communityName: 'Community',
          tagline: 'Learn together, grow together.',
          welcomeMessage: null,
          allowStudentPosts: true,
          allowStudentComments: true,
          requirePostApproval: false,
          showMemberCount: true,
        });
      }

      const body = await parseBody(req);
      const communityName = typeof body.communityName === 'string' ? body.communityName.trim() : '';
      const tagline = typeof body.tagline === 'string' ? body.tagline.trim() : '';
      const welcomeMessage = typeof body.welcomeMessage === 'string' ? body.welcomeMessage.trim() : null;
      const booleanFields = ['allowStudentPosts', 'allowStudentComments', 'requirePostApproval', 'showMemberCount'];
      if (communityName.length < 2 || communityName.length > 80 || tagline.length > 160 ||
          (welcomeMessage && welcomeMessage.length > 600) ||
          booleanFields.some(field => typeof body[field] !== 'boolean')) {
        return sendJson(res, 400, { error: 'Invalid community settings' });
      }

      const values = [
        communityName, tagline, welcomeMessage || null,
        body.allowStudentPosts, body.allowStudentComments,
        body.requirePostApproval, body.showMemberCount,
      ];
      const assignments = [
        '"communityName"', '"tagline"', '"welcomeMessage"',
        '"allowStudentPosts"', '"allowStudentComments"',
        '"requirePostApproval"', '"showMemberCount"',
      ].map((field, index) => `${field} = $${index + 3}`).join(', ');
      const rows = await dbQuery(
        `INSERT INTO "CommunitySettings" ("id", "ownerId", ${fields}, "createdAt", "updatedAt")
         VALUES ($1, $2, ${values.map((_, index) => `$${index + 3}`).join(', ')}, NOW(), NOW())
         ON CONFLICT ("ownerId") DO UPDATE SET ${assignments}, "updatedAt" = NOW()
         RETURNING ${fields}`,
        [crypto.randomUUID(), ownerId, ...values],
      );
      return sendJson(res, 200, rows[0]);
    } catch (error) {
      console.error('[Community Settings] Database error:', error.code || error.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to read or save community settings' });
    }
  }

  // Community comments and likes are stored in Neon for the configured community.
  const communityCommentsMatch = pathname.match(/^\/api\/community\/posts\/([^/]+)\/comments$/);
  if (communityCommentsMatch && (method === 'GET' || method === 'POST')) {
    const postId = decodeURIComponent(communityCommentsMatch[1]);
    const ownerId = getCommunityOwnerId();
    try {
      const post = await dbQuery(
        'SELECT "id" FROM "CommunityPost" WHERE "id" = $1 AND "ownerId" = $2',
        [postId, ownerId],
      );
      if (!post.length) return sendJson(res, 404, { error: 'Community post not found' });

      if (method === 'GET') {
        const comments = await dbQuery(
          `SELECT "id", "content", "authorId", "authorName", "authorImageUrl", "postId", "createdAt"
           FROM "CommunityComment" WHERE "postId" = $1 ORDER BY "createdAt" ASC`,
          [postId],
        );
        return sendJson(res, 200, comments);
      }

      const body = await parseBody(req);
      const content = String(body.content || '').trim();
      if (!content || content.length > 2000) {
        return sendJson(res, 400, { error: 'Comment content must be between 1 and 2000 characters' });
      }
      if (isProduction) {
        const [settings] = await dbQuery(
          'SELECT "allowStudentComments" FROM "CommunitySettings" WHERE "ownerId" = $1 LIMIT 1',
          [ownerId],
        );
        const teacherIds = (process.env.NEXT_PUBLIC_TEACHER_ID || '').split(',').map(id => id.trim());
        if (settings && !settings.allowStudentComments && !teacherIds.includes(userId)) {
          return sendJson(res, 403, { error: 'Comments are disabled for students' });
        }
      }
      const authorId = isProduction ? userId : (body.authorId || userId);
      const authorName = String(body.authorName || (isProduction ? 'Learner' : '')).trim().slice(0, 80) || null;
      const authorImageUrl = safeHttpsUrl(body.authorImageUrl);
      const rows = await dbQuery(
        `INSERT INTO "CommunityComment"
           ("id", "content", "authorId", "ownerId", "authorName", "authorImageUrl", "postId", "createdAt", "updatedAt")
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
         RETURNING "id", "content", "authorId", "authorName", "authorImageUrl", "postId", "createdAt"`,
        [crypto.randomUUID(), content, authorId,
          ownerId,
          authorName,
          authorImageUrl, postId],
      );
      return sendJson(res, 201, rows[0]);
    } catch (e) {
      console.error('[Community Comments] Database error:', e.code || e.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to load or save community comment' });
    }
  }

  const communityLikesMatch = pathname.match(/^\/api\/community\/posts\/([^/]+)\/likes$/);
  if (communityLikesMatch && method === 'POST') {
    const postId = decodeURIComponent(communityLikesMatch[1]);
    const ownerId = getCommunityOwnerId();
    const body = await parseBody(req);
    const likedByUserId = isProduction ? userId : (body.userId || userId);
    try {
      const post = await dbQuery(
        'SELECT "id" FROM "CommunityPost" WHERE "id" = $1 AND "ownerId" = $2',
        [postId, ownerId],
      );
      if (!post.length) return sendJson(res, 404, { error: 'Community post not found' });

      const existing = await dbQuery(
        'SELECT "id" FROM "CommunityLike" WHERE "postId" = $1 AND "userId" = $2',
        [postId, likedByUserId],
      );
      if (existing.length) {
        await dbQuery('DELETE FROM "CommunityLike" WHERE "postId" = $1 AND "userId" = $2', [postId, likedByUserId]);
      } else {
        await dbQuery(
          `INSERT INTO "CommunityLike" ("id", "userId", "ownerId", "postId", "createdAt")
           VALUES ($1, $2, $3, $4, NOW()) ON CONFLICT ("userId", "postId") DO NOTHING`,
          [crypto.randomUUID(), likedByUserId, ownerId, postId],
        );
      }
      const rows = await dbQuery(
        `SELECT COUNT(*)::int AS "likesCount",
                BOOL_OR("userId" = $2) AS "isLikedByMe"
         FROM "CommunityLike" WHERE "postId" = $1`,
        [postId, likedByUserId],
      );
      return sendJson(res, 200, {
        likesCount: rows[0].likesCount,
        isLikedByMe: rows[0].isLikedByMe || false,
      });
    } catch (e) {
      console.error('[Community Likes] Database error:', e.code || e.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to update community like' });
    }
  }

  // 15. Community Posts (GET & POST /api/community/posts)
  if (pathname === '/api/community/notifications' && method === 'GET') {
    const ownerId = getCommunityOwnerId();
    const requestedUserId = !isProduction && typeof query.userId === 'string'
      ? query.userId
      : userId;
    try {
      const notifications = await dbQuery(
        `SELECT p."id", p."title", p."content", p."authorId", p."ownerId", p."spaceId",
                p."isPinned", p."isAnnouncement", p."isApproved", p."createdAt",
                p."authorName", p."authorImageUrl",
                0::int AS "likesCount", false AS "isLikedByMe",
                '[]'::json AS "comments", 0::int AS "commentsCount"
         FROM "CommunityPost" p
         WHERE p."ownerId" = $1 AND p."isApproved" = true AND p."authorId" <> $2
         ORDER BY p."createdAt" DESC
         LIMIT 100`,
        [ownerId, requestedUserId],
      );
      return sendJson(res, 200, notifications);
    } catch (e) {
      console.error('[Community Notifications] Database error:', e.code || e.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to load community notifications' });
    }
  }

  if (pathname === '/api/community/posts' && method === 'GET') {
    try {
      const spaceId = typeof query.spaceId === 'string'
        ? query.spaceId
        : null;
      const requestedUserId = !isProduction && typeof query.userId === 'string'
        ? query.userId
        : userId;
      return sendJson(res, 200, await loadCommunityPostsFromDB(spaceId, requestedUserId));
    } catch (e) {
      console.error('[Community Posts] Database error:', e.code || e.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to load community posts' });
    }
  }

  if (pathname === '/api/community/posts' && method === 'POST') {
    const body = await parseBody(req);
    const ownerId = getCommunityOwnerId();
    const spaceId = String(body.spaceId || '');
    const title = String(body.title || '').trim();
    const content = String(body.content || '').trim();
    const author = users[userId] || { firstName: 'Student', imageUrl: null };
    const isTeacher = Boolean(author.isTeacher) ||
      (process.env.NEXT_PUBLIC_TEACHER_ID || '').split(',').map(id => id.trim()).includes(userId);

    if (!ownerId) return sendJson(res, 500, { error: 'Community owner is not configured' });
    if (!spaceId || !title || !content || title.length > 160 || content.length > 20000) {
      return sendJson(res, 400, { error: 'Space and content are required; title must be under 160 characters and post under 20000 characters' });
    }

    try {
      const spaces = await dbQuery(
        'SELECT "id" FROM "CommunitySpace" WHERE "id" = $1 AND "ownerId" = $2',
        [spaceId, ownerId],
      );
      if (!spaces.length) return sendJson(res, 404, { error: 'Community space not found' });

      const settings = await dbQuery(
        'SELECT "allowStudentPosts", "requirePostApproval" FROM "CommunitySettings" WHERE "ownerId" = $1 LIMIT 1',
        [ownerId],
      );
      const communitySettings = settings[0] || { allowStudentPosts: true, requirePostApproval: false };
      if (!isTeacher && !communitySettings.allowStudentPosts) {
        return sendJson(res, 403, { error: 'Student posts are disabled for this community' });
      }

      const isApproved = isTeacher || !communitySettings.requirePostApproval;
      const authorName = String(body.authorName || `${author.firstName || ''} ${author.lastName || ''}`.trim() || 'Learner')
        .trim().slice(0, 80);
      const authorImageUrl = safeHttpsUrl(body.authorImageUrl) || (isProduction ? null : safeHttpsUrl(author.imageUrl));
      const rows = await dbQuery(
        `INSERT INTO "CommunityPost"
           ("id", "title", "content", "authorId", "ownerId", "spaceId", "isApproved", "createdAt", "updatedAt", "authorName", "authorImageUrl")
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW(), $8, $9)
         RETURNING "id", "title", "content", "authorId", "ownerId", "spaceId", "isPinned", "isAnnouncement", "isApproved", "createdAt", "authorName", "authorImageUrl"`,
        [crypto.randomUUID(), title, content, userId, ownerId, spaceId, isApproved, authorName, authorImageUrl],
      );
      return sendJson(res, 201, {
        ...rows[0],
        likesCount: 0,
        isLikedByMe: false,
        comments: [],
        commentsCount: 0,
      });
    } catch (e) {
      console.error('[Community Posts] Database error:', e.code || e.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to create community post' });
    }
  }

  // LiveKit meeting sessions
  if (pathname === '/api/livekit/sessions' && method === 'GET') {
    if (isProduction) {
      try {
        return sendJson(res, 200, await dbQuery(
          `SELECT "id", "title", "description", "roomName", "hostId", "isActive", "createdAt"
           FROM "MeetingSession" WHERE "isActive" = true ORDER BY "createdAt" DESC LIMIT 100`,
        ));
      } catch (error) {
        console.error('[LiveKit Sessions] Database error:', error.code || error.name || 'unknown error');
        return sendJson(res, 500, { error: 'Unable to load live sessions' });
      }
    }
    return sendJson(res, 200, liveSessions);
  }

  if (pathname === '/api/livekit/sessions' && method === 'POST') {
    if (!isProduction) return sendJson(res, 501, { error: 'Create meetings through the teacher dashboard' });
    const teacherIds = (process.env.NEXT_PUBLIC_TEACHER_ID || '').split(',').map(id => id.trim()).filter(Boolean);
    if (!teacherIds.includes(userId)) return sendJson(res, 403, { error: 'Teacher access required' });
    const body = await parseBody(req);
    const title = String(body.title || '').trim();
    const description = String(body.description || '').trim();
    if (!title || title.length > 160 || description.length > 2000) {
      return sendJson(res, 400, { error: 'Meeting title is required and fields must be within the allowed length' });
    }
    const id = crypto.randomUUID();
    const roomName = `termini-${crypto.randomUUID()}`;
    try {
      const rows = await dbQuery(
        `INSERT INTO "MeetingSession" ("id", "title", "description", "roomName", "hostId", "isActive", "createdAt", "updatedAt")
         VALUES ($1, $2, $3, $4, $5, true, NOW(), NOW())
         RETURNING "id", "title", "description", "roomName", "hostId", "isActive", "createdAt"`,
        [id, title, description || null, roomName, userId],
      );
      return sendJson(res, 201, rows[0]);
    } catch (error) {
      console.error('[LiveKit Sessions] Database error:', error.code || error.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to create live session' });
    }
  }

  const liveSessionMatch = pathname.match(/^\/api\/livekit\/sessions\/([^/]+)$/);
  if (liveSessionMatch && method === 'DELETE') {
    if (!isProduction) return sendJson(res, 501, { error: 'End meetings through the teacher dashboard' });
    const teacherIds = (process.env.NEXT_PUBLIC_TEACHER_ID || '').split(',').map(id => id.trim()).filter(Boolean);
    if (!teacherIds.includes(userId)) return sendJson(res, 403, { error: 'Teacher access required' });
    try {
      const rows = await dbQuery(
        `UPDATE "MeetingSession" SET "isActive" = false, "updatedAt" = NOW()
         WHERE "id" = $1 AND "hostId" = $2 AND "isActive" = true
         RETURNING "id", "title", "description", "roomName", "hostId", "isActive", "createdAt"`,
        [decodeURIComponent(liveSessionMatch[1]), userId],
      );
      if (!rows.length) return sendJson(res, 404, { error: 'Live session not found' });
      return sendJson(res, 200, rows[0]);
    } catch (error) {
      console.error('[LiveKit Sessions] Database error:', error.code || error.name || 'unknown error');
      return sendJson(res, 500, { error: 'Unable to end live session' });
    }
  }

  if (pathname === '/api/livekit/token' && (method === 'GET' || method === 'POST')) {
    const body = method === 'POST' ? await parseBody(req) : {};
    const room = String(query.room || body.room || '').trim();
    if (!room || room.length > 128) return sendJson(res, 400, { error: 'A valid room is required' });

    if (isProduction) {
      const apiKey = process.env.LIVEKIT_API_KEY;
      const apiSecret = process.env.LIVEKIT_API_SECRET;
      const wsUrl = process.env.NEXT_PUBLIC_LIVEKIT_URL;
      if (!apiKey || !apiSecret || !wsUrl) {
        return sendJson(res, 503, { error: 'Live meetings are not configured' });
      }
      try {
        const sessions = await dbQuery(
          `SELECT "hostId" FROM "MeetingSession" WHERE "roomName" = $1 AND "isActive" = true LIMIT 1`,
          [room],
        );
        if (!sessions.length) return sendJson(res, 404, { error: 'Live session not found' });
        const isHost = sessions[0].hostId === userId;
        const accessToken = new AccessToken(apiKey, apiSecret, { identity: userId, name: userId });
        accessToken.addGrant({ roomJoin: true, room, canPublish: true, canSubscribe: true });
        return sendJson(res, 200, {
          token: await accessToken.toJwt(),
          wsUrl,
          room,
          participantName: userId,
          isHost,
        });
      } catch (error) {
        console.error('[LiveKit Token] Token creation failed:', error.code || error.name || 'unknown error');
        return sendJson(res, 500, { error: 'Unable to create live session token' });
      }
    }

    return sendJson(res, 200, {
      token: `mock_livekit_jwt_token_${userId}_${room}_${Date.now()}`,
      wsUrl: process.env.NEXT_PUBLIC_LIVEKIT_URL || 'wss://livekit.example.com',
      room,
      participantName: userId,
      isHost: userId === 'teacher_admin_demo',
    });
  }

  // Fallback 404
  return sendJson(res, 404, { error: 'Not found', path: pathname });
}

server.requestTimeout = 120000;
server.headersTimeout = 15000;
server.keepAliveTimeout = 5000;
server.maxHeadersCount = 100;

async function startServer() {
  if (!Number.isInteger(PORT) || PORT < 1 || PORT > 65535) {
    throw new Error('PORT must be a valid TCP port');
  }
  if (!databaseUrl) throw new Error('DATABASE_URL or DIRECT_URL must be configured');
  await dbQuery('SELECT 1');
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(PORT, '0.0.0.0', resolve);
  });
  console.log(`[Termini LMS Server] Listening on port ${PORT}`);
  console.log('[DB] Connected to PostgreSQL successfully');
}

let isShuttingDown = false;
async function shutdown(signal) {
  if (isShuttingDown) return;
  isShuttingDown = true;
  console.log(`[Termini LMS Server] ${signal} received; shutting down`);
  const forceExit = setTimeout(() => process.exit(1), 10000);
  forceExit.unref();
  server.close(async () => {
    try {
      await pool.end();
      clearTimeout(forceExit);
      process.exit(0);
    } catch (_) {
      process.exit(1);
    }
  });
  if (typeof server.closeIdleConnections === 'function') server.closeIdleConnections();
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

startServer().catch(async error => {
  console.error('[Termini LMS Server] Startup failed:', error.code || error.name || 'configuration error');
  await pool.end().catch(() => {});
  process.exitCode = 1;
});
