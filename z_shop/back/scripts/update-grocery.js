const fs = require('fs');
const path = require('path');
const https = require('https');
const mysql = require('mysql2/promise');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const IMAGES = {
  tomato: 'https://images.unsplash.com/photo-1546094096-0df4bcaaa337?w=400&h=400&fit=crop',
  cabbage: 'https://images.pexels.com/photos/1300975/pexels-photo-1300975.jpeg?auto=compress&cs=tinysrgb&w=400',
  potato: 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=400&h=400&fit=crop',
  carrot: 'https://images.pexels.com/photos/143133/pexels-photo-143133.jpeg?auto=compress&cs=tinysrgb&w=400',
  pepper: 'https://images.unsplash.com/photo-1563565375-f3fdfdbefa83?w=400&h=400&fit=crop',
  onion: 'https://images.unsplash.com/photo-1518977956812-cd3dbadaaf31?w=400&h=400&fit=crop',
  beef: 'https://images.pexels.com/photos/3611844/pexels-photo-3611844.jpeg?auto=compress&cs=tinysrgb&w=400',
  egg: 'https://images.pexels.com/photos/162712/egg-white-food-protein-162712.jpeg?auto=compress&cs=tinysrgb&w=400',
  pork: 'https://images.pexels.com/photos/3688/food-dinner-lunch-chicken.jpg?auto=compress&cs=tinysrgb&w=400',
  rib: 'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=400&h=400&fit=crop',
  chicken: 'https://images.pexels.com/photos/2338407/pexels-photo-2338407.jpeg?auto=compress&cs=tinysrgb&w=400',
  shrimp: 'https://images.pexels.com/photos/566566/pexels-photo-566566.jpeg?auto=compress&cs=tinysrgb&w=400',
  fish: 'https://images.pexels.com/photos/725991/pexels-photo-725991.jpeg?auto=compress&cs=tinysrgb&w=400',
  duck: 'https://images.pexels.com/photos/2233348/pexels-photo-2233348.jpeg?auto=compress&cs=tinysrgb&w=400',
  brisket: 'https://images.pexels.com/photos/3611844/pexels-photo-3611844.jpeg?auto=compress&cs=tinysrgb&w=400',
  rice: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400&h=400&fit=crop',
  oil: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400&h=400&fit=crop',
  tofu: 'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?w=400&h=400&fit=crop',
};

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    https.get(url, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        file.close();
        fs.unlinkSync(dest);
        return download(res.headers.location, dest).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        file.close();
        fs.unlinkSync(dest);
        return reject(new Error(`${url} -> ${res.statusCode}`));
      }
      res.pipe(file);
      file.on('finish', () => file.close(resolve));
    }).on('error', reject);
  });
}

async function run() {
  const dir = path.join(__dirname, '../../front/assets/products');
  fs.mkdirSync(dir, { recursive: true });

  for (const [name, url] of Object.entries(IMAGES)) {
    const dest = path.join(dir, `${name}.jpg`);
    try {
      await download(url, dest);
      console.log('OK', name);
    } catch (err) {
      console.warn('SKIP', name, err.message);
    }
  }

  const sql = fs.readFileSync(path.join(__dirname, '../sql/update-grocery.sql'), 'utf8');
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
  console.log('生鲜商品数据已更新');
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
