const express = require('express');
const pool = require('../config/db');
const { success, fail } = require('../utils/response');

const router = express.Router();

// 微信登录（MVP：用 code 模拟，后续接入 wx.login + 服务端换 openid）
router.post('/login', async (req, res, next) => {
  try {
    const { code, nickname = '微信用户', avatar = '' } = req.body;
    if (!code) return fail(res, '缺少 code');

    const openid = `mock_${code}`;

    let [users] = await pool.query('SELECT * FROM users WHERE openid = ?', [openid]);
    if (!users.length) {
      const [result] = await pool.query(
        'INSERT INTO users (openid, nickname, avatar) VALUES (?, ?, ?)',
        [openid, nickname, avatar]
      );
      [users] = await pool.query('SELECT * FROM users WHERE id = ?', [result.insertId]);
    }

    success(res, users[0], '登录成功');
  } catch (err) {
    next(err);
  }
});

// 用户信息
router.get('/:id', async (req, res, next) => {
  try {
    const [users] = await pool.query('SELECT id, nickname, avatar, phone, created_at FROM users WHERE id = ?', [req.params.id]);
    if (!users.length) return fail(res, '用户不存在', 404, 404);
    success(res, users[0]);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
