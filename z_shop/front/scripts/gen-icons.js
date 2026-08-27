const fs = require('fs');
const path = require('path');

// 1x1 透明 PNG
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64'
);

const dir = path.join(__dirname, 'assets/icons');
fs.mkdirSync(dir, { recursive: true });

['home', 'home-active', 'category', 'category-active', 'cart', 'cart-active', 'profile', 'profile-active'].forEach(
  (name) => fs.writeFileSync(path.join(dir, `${name}.png`), PNG)
);

console.log('TabBar 占位图标已生成，后续可替换为设计稿图标');
