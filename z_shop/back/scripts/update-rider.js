const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function run() {
  const sql = fs.readFileSync(path.join(__dirname, '../sql/update-rider.sql'), 'utf8');
  const statements = sql
    .split(';')
    .map((s) => s.trim())
    .filter((s) => s && !s.startsWith('--'));

  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    multipleStatements: true,
  });

  console.log('开始骑手模块数据库迁移...');
  for (const stmt of statements) {
    try {
      await conn.query(stmt);
    } catch (err) {
      if (err.code === 'ER_DUP_FIELDNAME' || err.message.includes('Duplicate column')) {
        console.log('跳过已有字段');
      } else {
        console.warn('跳过:', err.message.slice(0, 100));
      }
    }
  }
  await conn.end();
  console.log('骑手模块迁移完成');
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
