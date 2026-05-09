const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
});

(async () => {
    try {
        const client = await pool.connect();
        console.log('Connected to Supabase PostgreSQL');
        client.release();
    } catch (err) {
        console.error('PostgreSQL connection failed:', err.message);
        process.exit(1);
    }
})();

module.exports = pool;
