const express = require('express');
const pool = require('../config/db');
const { success, fail } = require('../utils/response');

const router = express.Router();
const MAX_ADDRESSES = 10;

function formatAddress(row) {
  const region = [row.province, row.city, row.district].filter(Boolean).join('');
  return {
    ...row,
    is_default: !!row.is_default,
    full_detail: region ? `${region}${row.detail}` : row.detail,
  };
}

// 地址列表
router.get('/', async (req, res, next) => {
  try {
    const { user_id } = req.query;
    if (!user_id) return fail(res, '缺少 user_id');

    const [rows] = await pool.query(
      'SELECT * FROM addresses WHERE user_id = ? ORDER BY is_default DESC, id DESC',
      [user_id]
    );
    success(res, rows.map(formatAddress));
  } catch (err) {
    next(err);
  }
});

// 新增地址
router.post('/', async (req, res, next) => {
  try {
    const { user_id, name, phone, province = '', city = '', district = '', detail, is_default = false } = req.body;
    if (!user_id || !name || !phone || !detail) return fail(res, '请填写完整地址信息');

    const [countRows] = await pool.query('SELECT COUNT(*) AS cnt FROM addresses WHERE user_id = ?', [user_id]);
    if (countRows[0].cnt >= MAX_ADDRESSES) {
      return fail(res, `最多保存 ${MAX_ADDRESSES} 个地址`);
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      if (is_default) {
        await conn.query('UPDATE addresses SET is_default = 0 WHERE user_id = ?', [user_id]);
      }
      const [result] = await conn.query(
        `INSERT INTO addresses (user_id, name, phone, province, city, district, detail, is_default)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [user_id, name, phone, province, city, district, detail, is_default ? 1 : 0]
      );
      // 首个地址自动设为默认
      if (countRows[0].cnt === 0) {
        await conn.query('UPDATE addresses SET is_default = 1 WHERE id = ?', [result.insertId]);
      }
      await conn.commit();
      const [rows] = await pool.query('SELECT * FROM addresses WHERE id = ?', [result.insertId]);
      success(res, formatAddress(rows[0]), '添加成功');
    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  } catch (err) {
    next(err);
  }
});

// 更新地址
router.put('/:id', async (req, res, next) => {
  try {
    const { user_id, name, phone, province = '', city = '', district = '', detail, is_default } = req.body;
    const id = req.params.id;

    const [existing] = await pool.query('SELECT * FROM addresses WHERE id = ? AND user_id = ?', [id, user_id]);
    if (!existing.length) return fail(res, '地址不存在', 404, 404);

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      if (is_default) {
        await conn.query('UPDATE addresses SET is_default = 0 WHERE user_id = ?', [user_id]);
      }
      await conn.query(
        `UPDATE addresses SET name=?, phone=?, province=?, city=?, district=?, detail=?, is_default=?
         WHERE id=? AND user_id=?`,
        [name, phone, province, city, district, detail, is_default ? 1 : 0, id, user_id]
      );
      await conn.commit();
      const [rows] = await pool.query('SELECT * FROM addresses WHERE id = ?', [id]);
      success(res, formatAddress(rows[0]), '保存成功');
    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  } catch (err) {
    next(err);
  }
});

// 设为默认
router.patch('/:id/default', async (req, res, next) => {
  try {
    const { user_id } = req.body;
    const id = req.params.id;

    const [existing] = await pool.query('SELECT * FROM addresses WHERE id = ? AND user_id = ?', [id, user_id]);
    if (!existing.length) return fail(res, '地址不存在', 404, 404);

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      await conn.query('UPDATE addresses SET is_default = 0 WHERE user_id = ?', [user_id]);
      await conn.query('UPDATE addresses SET is_default = 1 WHERE id = ?', [id]);
      await conn.commit();
      success(res, null, '已设为默认');
    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  } catch (err) {
    next(err);
  }
});

// 删除地址
router.delete('/:id', async (req, res, next) => {
  try {
    const { user_id } = req.query;
    const id = req.params.id;
    if (!user_id) return fail(res, '缺少 user_id');

    const [existing] = await pool.query('SELECT * FROM addresses WHERE id = ? AND user_id = ?', [id, user_id]);
    if (!existing.length) return fail(res, '地址不存在', 404, 404);

    const wasDefault = existing[0].is_default;
    await pool.query('DELETE FROM addresses WHERE id = ?', [id]);

    if (wasDefault) {
      const [left] = await pool.query(
        'SELECT id FROM addresses WHERE user_id = ? ORDER BY id DESC LIMIT 1',
        [user_id]
      );
      if (left.length) {
        await pool.query('UPDATE addresses SET is_default = 1 WHERE id = ?', [left[0].id]);
      }
    }
    success(res, null, '已删除');
  } catch (err) {
    next(err);
  }
});

module.exports = router;
