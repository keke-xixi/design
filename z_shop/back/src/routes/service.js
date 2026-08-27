const express = require('express');
const pool = require('../config/db');
const { success } = require('../utils/response');

const router = express.Router();

router.get('/contact', async (req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT name, phone, address FROM store_config ORDER BY id LIMIT 1');
    const store = rows[0] || {};
    success(res, {
      phone: store.phone || '400-888-8888',
      service_hours: '每天 7:00 - 21:00',
      wechat_id: 'xiangchishenme',
      store_name: store.name || '想吃什么菜',
      tip: '有问题请电话或添加微信客服，我们会尽快回复',
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
