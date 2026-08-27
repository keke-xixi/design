const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function init() {
  const sql = fs.readFileSync(path.join(__dirname, '../sql/init.sql'), 'utf8');

  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    multipleStatements: true,
  });

  console.log('连接数据库成功，开始初始化...');
  await conn.query(sql);
  await conn.end();
  console.log('数据库初始化完成');
}

init().catch((err) => {
  console.error('初始化失败:', err.message);
  process.exit(1);
});
