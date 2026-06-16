// shared/db.js — Reusable MariaDB pool for all services
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host:               process.env.DB_HOST     || 'localhost',
  port:               parseInt(process.env.DB_PORT || '3306'),
  user:               process.env.DB_USER     || 'root',
  password:           process.env.DB_PASSWORD || 'password',
  database:           process.env.DB_NAME     || 'abhi_ejaz_shop',
  waitForConnections: true,
  connectionLimit:    10,
  queueLimit:         0,
  connectTimeout:     10000,
  ssl:                process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

// Test connection on startup
pool.getConnection()
  .then(conn => {
    console.log(`✅ DB connected: ${process.env.DB_HOST || 'localhost'}`);
    conn.release();
  })
  .catch(err => {
    console.error('❌ DB connection failed:', err.message);
  });

module.exports = pool;
