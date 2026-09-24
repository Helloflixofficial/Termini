const http = require('http');
const url = require('url');
const fs = require('fs');
const path = require('path');

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
        email: userId.includes('@') ? userId : `${userId}@oeplatform.dev`,
        firstName: userId.startsWith('teacher') ? 'Alex' : 'Jordan',
        lastName: userId.startsWith('teacher') ? 'Instructor' : 'Learner',
        bio: 'Passionate student exploring cross-platform mobile development and cloud systems.',
        imageUrl: userId.startsWith('teacher')
          ? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=256&q=80'
          : 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=256&q=80',
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

      // If user has no purchases, show all published courses as "in progress" with 0%
      const coursesToShow = purchasedCourseIds.size > 0
        ? allCourses.filter(c => purchasedCourseIds.has(c.id))
        : allCourses;

      for (const course of coursesToShow) {
        const totalChapters = course.chapters ? course.chapters.length : 0;
        let completedChapterCount = 0;
        if (course.chapters) {
          for (const chap of course.chapters) {
            if (userProg[chap.id]) completedChapterCount++;
          }
        }
        const progress = totalChapters > 0 ? (completedChapterCount / totalChapters) * 100 : 0;
        const courseWithProgress = { ...course, progress: Math.round(progress) };
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
      let allCourses = await loadCoursesFromDB(null, true);
      if (qTitle) allCourses = allCourses.filter(c => c.title.toLowerCase().includes(qTitle));
      if (qCategoryId) allCourses = allCourses.filter(c => c.categoryId === qCategoryId);
      return sendJson(res, 200, allCourses.map(c => ({ ...c, progress: 0 })));
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
      const allCourses = await loadCoursesFromDB();
      const course = allCourses.find(c => c.id === courseId);
      if (!course) return sendJson(res, 404, { error: 'Course not found' });
      return sendJson(res, 200, { ...course, progress: 0 });
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
        attachments: [],
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
    return sendJson(res, 200, communitySpaces);
  }

  // 15. Community Posts (GET & POST /api/community/posts)
  if (pathname === '/api/community/posts' && method === 'GET') {
    return sendJson(res, 200, communityPosts);
  }

  if (pathname === '/api/community/posts' && method === 'POST') {
    const body = await parseBody(req);
    const author = users[userId] || { firstName: 'Student', imageUrl: null };
    const newPost = {
      id: `post-${Date.now()}`,
      spaceId: body.spaceId || communitySpaces[0].id,
      userId: userId,
      authorName: `${author.firstName || ''} ${author.lastName || ''}`.trim() || 'Learner',
      authorImageUrl: author.imageUrl,
      title: body.title || 'Untitled Discussion',
      content: body.content || '',
      createdAt: new Date().toISOString(),
      likesCount: 0,
      comments: [],
    };
    communityPosts.unshift(newPost);
    return sendJson(res, 200, newPost);
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
