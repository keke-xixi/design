const mysql = require('mysql2/promise');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function run() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  await conn.query(`
    CREATE TABLE IF NOT EXISTS store_config (
      id INT PRIMARY KEY AUTO_INCREMENT,
      name VARCHAR(100) NOT NULL DEFAULT '想吃什么菜·前置仓',
      address VARCHAR(200) NOT NULL DEFAULT '菜市场A区3号档口',
      phone VARCHAR(20) DEFAULT '',
      latitude DECIMAL(10,6) DEFAULT NULL,
      longitude DECIMAL(10,6) DEFAULT NULL,
      rider_fee DECIMAL(10,2) DEFAULT 6.00,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  `);

  const [existing] = await conn.query('SELECT id FROM store_config LIMIT 1');
  if (!existing.length) {
    await conn.query(
      `INSERT INTO store_config (name, address, phone, rider_fee) VALUES (?, ?, ?, ?)`,
      ['想吃什么菜·前置仓', '菜市场A区3号档口（早7点-晚9点）', '13800000000', 6]
    );
  }

  console.log('store_config 就绪');
  await conn.end();
}

run().catch(console.error);
