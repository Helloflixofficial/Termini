const http = require('http');
const url = require('url');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = process.env.PORT || 3000;

// ─── Load .env manually (no dotenv dep required) ─────────────────────────────
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
  fs.readFileSync(envPath, 'utf8').split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const idx = trimmed.indexOf('=');
      if (idx !== -1) {
        const key = trimmed.substring(0, idx).trim();
        const val = trimmed.substring(idx + 1).trim();
        if (!process.env[key]) process.env[key] = val;
      }
    }
  });
}

// ─── Real Neon PostgreSQL connection ─────────────────────────────────────────
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || process.env.DIRECT_URL,
  ssl: { rejectUnauthorized: false },
  max: 5,
  idleTimeoutMillis: 30000,
});

pool.connect((err, client, done) => {
  if (err) {
    console.error('[DB] Failed to connect to Neon PostgreSQL:', err.message);
  } else {
    console.log('[DB] Connected to Neon PostgreSQL successfully!');
    done();
  }
});

// ─── DB query helpers ─────────────────────────────────────────────────────────
async function dbQuery(sql, params = []) {
  const client = await pool.connect();
  try {
    const result = await client.query(sql, params);
    return result.rows;
  } finally {
    client.release();
  }
}

// Load all published courses with chapters + mux data + category from DB
async function loadCoursesFromDB(filterUserId = null, publishedOnly = false) {
  // Note: Prisma mapped Course -> "title" table in this schema
  let courseWhere = publishedOnly ? `WHERE c."isPublished" = true` : 'WHERE 1=1';
  if (filterUserId) {
    courseWhere += ` AND c."userId" = '${filterUserId.replace(/'/g, "''")}'`;
  }

  const courseRows = await dbQuery(`
    SELECT c.*, cat."name" as "categoryName"
    FROM "title" c
    LEFT JOIN "Category" cat ON c."categoryId" = cat."id"
    ${courseWhere}
    ORDER BY c."updatedAt" DESC
  `);

  if (courseRows.length === 0) return [];

  const courseIds = courseRows.map(c => c.id);
  const placeholders = courseIds.map((_, i) => `$${i + 1}`).join(',');

  // Load chapters
  const chapterRows = await dbQuery(`
    SELECT ch.*, md."assetId", md."playbackId", md."id" as "muxId"
    FROM "Chapter" ch
    LEFT JOIN "MuxData" md ON md."chapterId" = ch."id"
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

  return dbQuery(
    `SELECT
       p."id", p."title", p."content", p."authorId", p."ownerId", p."spaceId",
       p."isPinned", p."isAnnouncement", p."isApproved", p."createdAt",
       p."mediaUrl", p."mediaType", p."linkUrl", p."linkTitle",
       p."authorName", p."authorImageUrl",
       COALESCE(l."likesCount", 0)::int AS "likesCount",
       COALESCE(l."isLikedByMe", false) AS "isLikedByMe",
       json_build_object('id', s."id", 'name', s."name", 'color', s."color") AS "space",
       COALESCE(
         json_agg(json_build_object(
           'id', c."id", 'content', c."content", 'authorId', c."authorId",
           'postId', c."postId", 'createdAt', c."createdAt",
           'authorName', c."authorName", 'authorImageUrl', c."authorImageUrl"
         ) ORDER BY c."createdAt" ASC) FILTER (WHERE c."id" IS NOT NULL),
         '[]'::json
       ) AS "comments"
     FROM "CommunityPost" p
     JOIN "CommunitySpace" s ON s."id" = p."spaceId"
     LEFT JOIN "CommunityComment" c ON c."postId" = p."id"
     LEFT JOIN LATERAL (
       SELECT COUNT(*) AS "likesCount",
              BOOL_OR("userId" = ${userParam}) AS "isLikedByMe"
       FROM "CommunityLike" WHERE "postId" = p."id"
     ) l ON true
     WHERE p."ownerId" = $1 ${spaceFilter}
     GROUP BY p."id", s."id", l."likesCount", l."isLikedByMe"
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
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Credentials': 'true',
  });
  res.end(JSON.stringify(data));
}

function sendCors(res) {
  res.writeHead(204, {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Credentials': 'true',
  });
  res.end();
}

// Request Body Parser
function parseBody(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk.toString();
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        resolve({});
      }
    });
  });
}

// Video Streaming Endpoint with Full HTTP 206 Byte Range Support (ExoPlayer compatible)
function serveVideoStream(req, res, chapterId) {
  const videoDir = path.join(__dirname, 'public', 'videos');
  const filePath = path.join(videoDir, `${chapterId}.mp4`);

  if (!fs.existsSync(filePath)) {
    return sendJson(res, 404, { error: 'Video file not found or not yet cached' });
  }

  const stat = fs.statSync(filePath);
  const fileSize = stat.size;
  const range = req.headers.range;

  if (req.method.toUpperCase() === 'HEAD') {
    res.writeHead(200, {
      'Content-Length': fileSize,
      'Accept-Ranges': 'bytes',
      'Content-Type': 'video/mp4',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Range, Origin, Content-Type, Accept',
      'Access-Control-Expose-Headers': 'Content-Range, Accept-Ranges, Content-Length',
    });
    return res.end();
  }

  if (range) {
    const parts = range.replace(/bytes=/, "").split("-");
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

    if (start >= fileSize) {
      res.writeHead(416, {
        'Content-Range': `bytes */${fileSize}`,
        'Access-Control-Allow-Origin': '*',
      });
      return res.end();
    }

    const chunksize = (end - start) + 1;
    const file = fs.createReadStream(filePath, { start, end });
    const head = {
      'Content-Range': `bytes ${start}-${end}/${fileSize}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': chunksize,
      'Content-Type': 'video/mp4',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Range, Origin, Content-Type, Accept',
      'Access-Control-Expose-Headers': 'Content-Range, Accept-Ranges, Content-Length',
    };
    res.writeHead(206, head);
    file.pipe(res);
  } else {
    const head = {
      'Content-Length': fileSize,
      'Accept-Ranges': 'bytes',
      'Content-Type': 'video/mp4',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Range, Origin, Content-Type, Accept',
      'Access-Control-Expose-Headers': 'Content-Range, Accept-Ranges, Content-Length',
    };
    res.writeHead(200, head);
    fs.createReadStream(filePath).pipe(res);
  }
}

// HTTP Server
const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method.toUpperCase();

  // Handle CORS Preflight
  if (method === 'OPTIONS') {
    return sendCors(res);
  }

  // 0. Video Streaming Endpoint (HTTP 206 Byte Range)
  const videoStreamMatch = pathname.match(/^\/api\/videos\/([^\/]+)$/);
  if (videoStreamMatch && (method === 'GET' || method === 'HEAD')) {
    const chapterId = videoStreamMatch[1];
    return serveVideoStream(req, res, chapterId);
  }

  const userId = extractUserId(req);

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

      // Load ALL published courses from DB
      const allCourses = await loadCoursesFromDB(null, true);

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
      console.error('[Dashboard] DB error:', dbErr.message);
      return sendJson(res, 500, { error: 'Database error: ' + dbErr.message });
    }
  }

  // 5. Categories Endpoint — real from DB
  if (pathname === '/api/categories' && method === 'GET') {
    try {
      const cats = await loadCategoriesFromDB();
      return sendJson(res, 200, cats.length > 0 ? cats : categories);
    } catch (e) {
      return sendJson(res, 200, categories);
    }
  }

  // 6. Courses Search & Catalog — real from DB
  if (pathname === '/api/courses' && method === 'GET') {
    try {
      const qTitle = (parsedUrl.query.title || '').toLowerCase();
      const qCategoryId = parsedUrl.query.categoryId || '';
      let allCourses = await addCoursePurchaseState(
        await loadCoursesFromDB(null, true),
        userId,
      );
      if (qTitle) allCourses = allCourses.filter(c => c.title.toLowerCase().includes(qTitle));
      if (qCategoryId) allCourses = allCourses.filter(c => c.categoryId === qCategoryId);
      return sendJson(res, 200, allCourses);
    } catch (e) {
      console.error('[Courses] DB error:', e.message);
      return sendJson(res, 500, { error: e.message });
    }
  }

  // 7. Teacher Create Course (POST /api/courses)
  if (pathname === '/api/courses' && method === 'POST') {
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
      const allCourses = await addCoursePurchaseState(await loadCoursesFromDB(), userId);
      const course = allCourses.find(c => c.id === courseId);
      if (!course) return sendJson(res, 404, { error: 'Course not found' });
      return sendJson(res, 200, course);
    } catch (e) {
      return sendJson(res, 500, { error: e.message });
    }
  }

  // 9. Chapter Detail — real from DB
  const chapterMatch = pathname.match(/^\/api\/courses\/([^\/]+)\/chapters\/([^\/]+)$/);
  if (chapterMatch && method === 'GET') {
    const courseId = chapterMatch[1];
    const chapterId = chapterMatch[2];
    try {
      const allCourses = await loadCoursesFromDB();
      const course = allCourses.find(c => c.id === courseId);
      if (!course) return sendJson(res, 404, { error: 'Course not found' });
      const chapter = course.chapters?.find(ch => ch.id === chapterId);
      if (!chapter) return sendJson(res, 404, { error: 'Chapter not found' });

      const purchaseRows = await dbQuery(
        'SELECT "id" FROM "Purchase" WHERE "userId" = $1 AND "courseId" = $2',
        [userId, courseId]
      );
      const hasPurchased = purchaseRows.length > 0;

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
      return sendJson(res, 500, { error: e.message });
    }
  }

  // 10. Update Chapter Progress (PUT /api/courses/:courseId/chapters/:chapterId/progress)
  const progressMatch = pathname.match(/^\/api\/courses\/([^\/]+)\/chapters\/([^\/]+)\/progress$/);
  if (progressMatch && method === 'PUT') {
    const chapterId = progressMatch[2];
    const body = await parseBody(req);
    const isCompleted = !!body.isCompleted;

    if (!userProgress[userId]) {
      userProgress[userId] = {};
    }
    userProgress[userId][chapterId] = isCompleted;

    return sendJson(res, 200, {
      id: `prog-${chapterId}`,
      userId: userId,
      chapterId: chapterId,
      isCompleted: isCompleted,
    });
  }

  // 11. Checkout Endpoint (POST /api/courses/:courseId/checkout)
  const checkoutMatch = pathname.match(/^\/api\/courses\/([^\/]+)\/checkout$/);
  if (checkoutMatch && method === 'POST') {
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
      const teacherCourses = await loadCoursesFromDB(userId);
      if (teacherCourses.length > 0) {
        return sendJson(res, 200, teacherCourses);
      }
      // Fallback: if userId doesn't match, return all courses for teacher_admin
      const allCourses = await loadCoursesFromDB('user_2ZrBFVtrrTrK0EbbS93RQHjQgX3');
      return sendJson(res, 200, allCourses);
    } catch (e) {
      console.error('[Teacher Courses] DB error:', e.message);
      return sendJson(res, 500, { error: e.message });
    }
  }

  // 13. Teacher Analytics (GET /api/teacher/analytics)
  if (pathname === '/api/teacher/analytics' && method === 'GET') {
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
      console.error('[Community Spaces] DB error:', e.message);
      return sendJson(res, 500, { error: 'Unable to load community spaces' });
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
      if (!content) return sendJson(res, 400, { error: 'Comment content is required' });
      const authorId = body.authorId || userId;
      const rows = await dbQuery(
        `INSERT INTO "CommunityComment"
           ("id", "content", "authorId", "authorName", "authorImageUrl", "postId", "createdAt")
         VALUES ($1, $2, $3, $4, $5, $6, NOW())
         RETURNING "id", "content", "authorId", "authorName", "authorImageUrl", "postId", "createdAt"`,
        [crypto.randomUUID(), content, authorId, body.authorName || null, body.authorImageUrl || null, postId],
      );
      return sendJson(res, 201, rows[0]);
    } catch (e) {
      console.error('[Community Comments] DB error:', e.message);
      return sendJson(res, 500, { error: 'Unable to load or save community comment' });
    }
  }

  const communityLikesMatch = pathname.match(/^\/api\/community\/posts\/([^/]+)\/likes$/);
  if (communityLikesMatch && method === 'POST') {
    const postId = decodeURIComponent(communityLikesMatch[1]);
    const ownerId = getCommunityOwnerId();
    const body = await parseBody(req);
    const likedByUserId = body.userId || userId;
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
      console.error('[Community Likes] DB error:', e.message);
      return sendJson(res, 500, { error: 'Unable to update community like' });
    }
  }

  // 15. Community Posts (GET & POST /api/community/posts)
  if (pathname === '/api/community/notifications' && method === 'GET') {
    const ownerId = getCommunityOwnerId();
    const requestedUserId = typeof parsedUrl.query.userId === 'string'
      ? parsedUrl.query.userId
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
      console.error('[Community Notifications] DB error:', e.message);
      return sendJson(res, 500, { error: 'Unable to load community notifications' });
    }
  }

  if (pathname === '/api/community/posts' && method === 'GET') {
    try {
      const spaceId = typeof parsedUrl.query.spaceId === 'string'
        ? parsedUrl.query.spaceId
        : null;
      const requestedUserId = typeof parsedUrl.query.userId === 'string'
        ? parsedUrl.query.userId
        : userId;
      return sendJson(res, 200, await loadCommunityPostsFromDB(spaceId, requestedUserId));
    } catch (e) {
      console.error('[Community Posts] DB error:', e.message);
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
    if (!spaceId || !title || !content) {
      return sendJson(res, 400, { error: 'Space, title, and post content are required' });
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
      const authorName = String(body.authorName || `${author.firstName || ''} ${author.lastName || ''}`.trim() || 'Learner');
      const rows = await dbQuery(
        `INSERT INTO "CommunityPost"
           ("id", "title", "content", "authorId", "ownerId", "spaceId", "isApproved", "createdAt", "updatedAt", "authorName", "authorImageUrl")
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW(), $8, $9)
         RETURNING "id", "title", "content", "authorId", "ownerId", "spaceId", "isPinned", "isAnnouncement", "isApproved", "createdAt", "authorName", "authorImageUrl"`,
        [crypto.randomUUID(), title, content, userId, ownerId, spaceId, isApproved, authorName, body.authorImageUrl || author.imageUrl || null],
      );
      return sendJson(res, 201, {
        ...rows[0],
        likesCount: 0,
        isLikedByMe: false,
        comments: [],
        commentsCount: 0,
      });
    } catch (e) {
      console.error('[Community Posts] DB error while creating post:', e.message);
      return sendJson(res, 500, { error: 'Unable to create community post' });
    }
  }

  // 16. LiveKit Meetings (GET /api/livekit/sessions, POST /api/livekit/token)
  if (pathname === '/api/livekit/sessions' && method === 'GET') {
    return sendJson(res, 200, liveSessions);
  }

  if (pathname === '/api/livekit/token' && method === 'POST') {
    const body = await parseBody(req);
    const room = body.room || 'general-live';
    const participant = body.username || userId;
    return sendJson(res, 200, {
      token: `mock_livekit_jwt_token_${participant}_${room}_${Date.now()}`,
      wsUrl: 'wss://livekit.example.com',
      room: room,
    });
  }

  // Fallback 404
  return sendJson(res, 404, { error: 'Not found', path: pathname });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[Termini LMS Server] Running at http://0.0.0.0:${PORT}`);
  console.log(`[Termini LMS Server] Reverse adb forwarded to 127.0.0.1:${PORT}`);
});
