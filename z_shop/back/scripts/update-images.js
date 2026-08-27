const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function run() {
  const sql = fs.readFileSync(path.join(__dirname, '../sql/update-images.sql'), 'utf8');
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    multipleStatements: true,
  });
  await conn.query(sql);
  await conn.end();
  console.log('菜品图片已更新');
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
