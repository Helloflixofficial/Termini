const { Pool } = require('pg');
const pool = new Pool({ connectionString: 'postgresql://neondb_owner:npg_Qiu6TdaDzg1F@ep-wispy-bush-admrhzad-pooler.c-2.us-east-1.aws.neon.tech/neondb?sslmode=require' });
async function run() {
  const r = await pool.query('SELECT id, title, "videoUrl" FROM "Chapter" WHERE "videoUrl" IS NOT NULL');
  console.log(JSON.stringify(r.rows, null, 2));
  await pool.end();
}
run().catch(console.error);
