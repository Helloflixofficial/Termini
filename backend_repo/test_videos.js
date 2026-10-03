const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set DATABASE_URL in your local environment before running this diagnostic.');
  process.exit(1);
}

const pool = new Pool({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

async function main() {
  const result = await pool.query(
    'SELECT COUNT(*)::int AS count FROM "Chapter" WHERE "videoUrl" IS NOT NULL',
  );
  console.log('Chapters with video URLs:', result.rows[0].count);
}

main()
  .catch((error) => {
    console.error('Video query failed:', error.code || error.name || 'unknown error');
    process.exitCode = 1;
  })
  .finally(() => pool.end());
