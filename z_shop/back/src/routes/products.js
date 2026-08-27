const express = require('express');
const pool = require('../config/db');
const { success, fail } = require('../utils/response');

const router = express.Router();

function parseProduct(row) {
  return {
    ...row,
    ingredients: safeJson(row.ingredients, []),
    steps: safeJson(row.steps, []),
  };
}

function safeJson(str, fallback) {
  if (str == null || str === '') return fallback;
  if (typeof str === 'object') return str;
  try {
    return JSON.parse(str);
  } catch {
    return fallback;
  }
}

// 商品列表
router.get('/', async (req, res, next) => {
  try {
    const { category_id, keyword, page = 1, pageSize = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    let sql = 'SELECT * FROM products WHERE status = 1';
    const params = [];

    if (category_id) {
      sql += ' AND category_id = ?';
      params.push(category_id);
    }
    if (keyword) {
      sql += ' AND (name LIKE ? OR subtitle LIKE ? OR description LIKE ?)';
      const kw = `%${keyword}%`;
      params.push(kw, kw, kw);
    }
    sql += ' ORDER BY sales DESC LIMIT ? OFFSET ?';
    params.push(Number(pageSize), offset);

    const [rows] = await pool.query(sql, params);
    success(res, rows.map(parseProduct));
  } catch (err) {
    next(err);
  }
});

// 商品详情
router.get('/:id', async (req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT * FROM products WHERE id = ? AND status = 1', [req.params.id]);
    if (!rows.length) return fail(res, '商品不存在', 404, 404);
    success(res, parseProduct(rows[0]));
  } catch (err) {
    next(err);
  }
});

module.exports = router;
