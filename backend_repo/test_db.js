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
    'SELECT COUNT(*)::int AS count FROM "Chapter" WHERE "courseId" = $1',
    ['522fbb14-79c1-4d75-bc3e-114c0a977c61'],
  );
  console.log('Chapter count:', result.rows[0].count);
}

main()
  .catch((error) => {
    console.error('Chapter query failed:', error.code || error.name || 'unknown error');
    process.exitCode = 1;
  })
  .finally(() => pool.end());
