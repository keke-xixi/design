const express = require('express');
const pool = require('../config/db');
const { success, fail } = require('../utils/response');

const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, icon, sort_order FROM categories WHERE status = 1 ORDER BY sort_order ASC'
    );
    success(res, rows);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
