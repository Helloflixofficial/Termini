const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://neondb_owner:npg_Qiu6TdaDzg1F@ep-wispy-bush-admrhzad-pooler.c-2.us-east-1.aws.neon.tech/neondb?sslmode=require',
  ssl: { rejectUnauthorized: false }
});

async function main() {
  const ch = await pool.query('SELECT * FROM "Chapter" WHERE "courseId" = $1', ['522fbb14-79c1-4d75-bc3e-114c0a977c61']);
  console.log('Chapters:', ch.rows);
  await pool.end();
}
main().catch(console.error);
