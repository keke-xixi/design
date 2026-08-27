const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  maxIdle: 5,
  idleTimeout: 60000,
  connectTimeout: 30000,
  enableKeepAlive: true,
  keepAliveInitialDelay: 10000,
  charset: 'utf8mb4',
});

const rawQuery = pool.query.bind(pool);

pool.query = async function queryWithRetry(sql, params) {
  try {
    return await rawQuery(sql, params);
  } catch (err) {
    const retryable = ['ECONNRESET', 'PROTOCOL_CONNECTION_LOST', 'ETIMEDOUT', 'ECONNREFUSED'];
    if (retryable.includes(err.code)) {
      console.warn('[DB] 连接断开，重试:', err.code);
      return rawQuery(sql, params);
    }
    throw err;
  }
};

pool.ping = async () => rawQuery('SELECT 1');

module.exports = pool;
