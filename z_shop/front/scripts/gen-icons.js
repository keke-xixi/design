const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const SIZE = 81;

function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let j = 0; j < 8; j++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  }
  return (~c) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const typeBuf = Buffer.from(type);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])));
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function hex(color) {
  const h = color.replace('#', '');
  return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16), 255];
}

function createPNG(drawFn) {
  const raw = Buffer.alloc(SIZE * (1 + SIZE * 4));
  for (let y = 0; y < SIZE; y++) {
    raw[y * (1 + SIZE * 4)] = 0;
    for (let x = 0; x < SIZE; x++) {
      const i = y * (1 + SIZE * 4) + 1 + x * 4;
      const [r, g, b, a] = drawFn(x, y);
      raw[i] = r;
      raw[i + 1] = g;
      raw[i + 2] = b;
      raw[i + 3] = a;
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(SIZE, 0);
  ihdr.writeUInt32BE(SIZE, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;

  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function fill(pixels, x, y, w, h, color) {
  const [r, g, b, a] = hex(color);
  for (let dy = 0; dy < h; dy++) {
    for (let dx = 0; dx < w; dx++) {
      const px = x + dx;
      const py = y + dy;
      if (px >= 0 && px < SIZE && py >= 0 && py < SIZE) pixels[py * SIZE + px] = [r, g, b, a];
    }
  }
}

function circle(pixels, cx, cy, radius, color) {
  const [r, g, b, a] = hex(color);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const d = Math.hypot(x - cx, y - cy);
      if (d <= radius) pixels[y * SIZE + x] = [r, g, b, a];
    }
  }
}

function drawHome(pixels, color) {
  fill(pixels, 18, 38, 45, 28, color);
  for (let i = 0; i < 30; i++) {
    fill(pixels, 40 - i, 18 + i, 2 + i * 2, 2, color);
  }
  fill(pixels, 34, 48, 14, 18, '#FFFFFF');
}

function drawCategory(pixels, color) {
  [22, 42, 62].forEach((x) => {
    [22, 42, 62].forEach((y) => circle(pixels, x, y, 7, color));
  });
}

function drawCart(pixels, color) {
  fill(pixels, 20, 28, 42, 4, color);
  fill(pixels, 18, 32, 4, 26, color);
  fill(pixels, 58, 32, 4, 26, color);
  fill(pixels, 20, 54, 42, 4, color);
  circle(pixels, 28, 64, 5, color);
  circle(pixels, 52, 64, 5, color);
  fill(pixels, 24, 36, 34, 16, color);
}

function drawProfile(pixels, color) {
  circle(pixels, 40, 28, 12, color);
  fill(pixels, 18, 44, 44, 24, color);
  fill(pixels, 22, 50, 36, 20, '#FFFFFF');
}

const ICONS = [
  { name: 'home', draw: drawHome },
  { name: 'category', draw: drawCategory },
  { name: 'cart', draw: drawCart },
  { name: 'profile', draw: drawProfile },
];

const dir = path.join(__dirname, '../assets/icons');
fs.mkdirSync(dir, { recursive: true });

ICONS.forEach(({ name, draw }) => {
  ['#BBBBBB', '#FF6B35'].forEach((color, idx) => {
    const pixels = Array(SIZE * SIZE).fill([0, 0, 0, 0]);
    draw(pixels, color);
    const suffix = idx === 0 ? '' : '-active';
    const png = createPNG((x, y) => pixels[y * SIZE + x] || [0, 0, 0, 0]);
    fs.writeFileSync(path.join(dir, `${name}${suffix}.png`), png);
  });
});

console.log('TabBar 图标已生成');
