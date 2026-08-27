const express = require('express');
const pool = require('../config/db');
const { success, fail } = require('../utils/response');
const { STATUS_MAP, safeJson } = require('../constants/orderStatus');

const router = express.Router();

async function getStoreConfig() {
  const [rows] = await pool.query('SELECT * FROM store_config ORDER BY id LIMIT 1');
  return rows[0] || { name: '前置仓', address: '菜市场A区3号档口', rider_fee: 6 };
}

async function enrichOrder(order) {
  const [items] = await pool.query('SELECT * FROM order_items WHERE order_id = ?', [order.id]);
  let rider = null;
  if (order.rider_id) {
    const [riders] = await pool.query('SELECT id, name, phone FROM riders WHERE id = ?', [order.rider_id]);
    rider = riders[0] || null;
  }
  return {
    ...order,
    status_text: STATUS_MAP[order.status] || '未知',
    address_snapshot: safeJson(order.address_snapshot),
    items,
    item_count: items.reduce((s, i) => s + i.quantity, 0),
    rider,
  };
}

// 骑手登录/注册
router.post('/login', async (req, res, next) => {
  try {
    const { code, name, phone } = req.body;
    if (!code || !name || !phone) return fail(res, '请填写姓名和手机号');

    const openid = `rider_${code}`;

    let [riders] = await pool.query('SELECT * FROM riders WHERE openid = ?', [openid]);
    if (!riders.length) {
      const [result] = await pool.query(
        'INSERT INTO riders (openid, name, phone) VALUES (?, ?, ?)',
        [openid, name, phone]
      );
      [riders] = await pool.query('SELECT * FROM riders WHERE id = ?', [result.insertId]);
    } else if (name && phone) {
      await pool.query('UPDATE riders SET name = ?, phone = ? WHERE id = ?', [name, phone, riders[0].id]);
      [riders] = await pool.query('SELECT * FROM riders WHERE id = ?', [riders[0].id]);
    }

    success(res, riders[0], '登录成功');
  } catch (err) {
    next(err);
  }
});

// 待接单池（放在 /:id 之前）
router.get('/orders/pending', async (req, res, next) => {
  try {
    const store = await getStoreConfig();
    const [orders] = await pool.query(
      'SELECT * FROM orders WHERE status = 1 ORDER BY created_at ASC'
    );
    const result = [];
    for (const order of orders) {
      result.push(await enrichOrder(order));
    }
    success(res, { store, orders: result });
  } catch (err) {
    next(err);
  }
});

// 门店信息
router.get('/store', async (req, res, next) => {
  try {
    success(res, await getStoreConfig());
  } catch (err) {
    next(err);
  }
});

// 接单
router.post('/orders/:orderId/accept', async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const { rider_id } = req.body;
    const orderId = req.params.orderId;
    if (!rider_id) return fail(res, '缺少 rider_id');

    await conn.beginTransaction();

    const [orders] = await conn.query('SELECT * FROM orders WHERE id = ? FOR UPDATE', [orderId]);
    if (!orders.length) {
      await conn.rollback();
      return fail(res, '订单不存在', 404, 404);
    }
    const order = orders[0];
    if (order.status !== 1) {
      await conn.rollback();
      return fail(res, '订单已被接走');
    }

    const [riders] = await conn.query('SELECT * FROM riders WHERE id = ?', [rider_id]);
    if (!riders.length) {
      await conn.rollback();
      return fail(res, '骑手不存在');
    }
    const rider = riders[0];

    // 骑手同时只能有一单进行中
    const [active] = await conn.query(
      'SELECT id FROM orders WHERE rider_id = ? AND status IN (2, 3) LIMIT 1',
      [rider_id]
    );
    if (active.length) {
      await conn.rollback();
      return fail(res, '请先完成当前配送订单');
    }

    await conn.query(
      `UPDATE orders SET status = 2, rider_id = ?, rider_name = ?, rider_phone = ?, accepted_at = NOW()
       WHERE id = ?`,
      [rider_id, rider.name, rider.phone, orderId]
    );

    await conn.commit();
    const [updated] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);
    success(res, await enrichOrder(updated[0]), '接单成功，请前往取货');
  } catch (err) {
    await conn.rollback();
    next(err);
  } finally {
    conn.release();
  }
});

// 确认取货
router.post('/orders/:orderId/pickup', async (req, res, next) => {
  try {
    const { rider_id } = req.body;
    const orderId = req.params.orderId;

    const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);
    if (!orders.length) return fail(res, '订单不存在', 404, 404);

    const order = orders[0];
    if (order.rider_id !== Number(rider_id)) return fail(res, '无权操作此订单');
    if (order.status !== 2) return fail(res, '当前状态不可取货');

    await pool.query(
      'UPDATE orders SET status = 3, picked_up_at = NOW() WHERE id = ?',
      [orderId]
    );

    const [updated] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);
    success(res, await enrichOrder(updated[0]), '已取货，开始配送');
  } catch (err) {
    next(err);
  }
});

// 确认送达 + 结算
router.post('/orders/:orderId/deliver', async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const { rider_id } = req.body;
    const orderId = req.params.orderId;

    await conn.beginTransaction();

    const [orders] = await conn.query('SELECT * FROM orders WHERE id = ? FOR UPDATE', [orderId]);
    if (!orders.length) {
      await conn.rollback();
      return fail(res, '订单不存在', 404, 404);
    }

    const order = orders[0];
    if (order.rider_id !== Number(rider_id)) {
      await conn.rollback();
      return fail(res, '无权操作此订单');
    }
    if (order.status !== 3) {
      await conn.rollback();
      return fail(res, '请先确认取货');
    }

    const store = await getStoreConfig();
    const riderFee = Number(store.rider_fee || 6);

    await conn.query(
      'UPDATE orders SET status = 4, delivered_at = NOW() WHERE id = ?',
      [orderId]
    );

    await conn.query(
      'INSERT INTO rider_settlements (rider_id, order_id, order_no, amount) VALUES (?, ?, ?, ?)',
      [rider_id, orderId, order.order_no, riderFee]
    );

    await conn.query(
      'UPDATE riders SET total_orders = total_orders + 1, total_earnings = total_earnings + ?, balance = balance + ? WHERE id = ?',
      [riderFee, riderFee, rider_id]
    );

    await conn.commit();

    const [riders] = await pool.query('SELECT * FROM riders WHERE id = ?', [rider_id]);
    const [updated] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);
    success(res, {
      order: await enrichOrder(updated[0]),
      settlement: { amount: riderFee },
      rider: riders[0],
    }, `送达成功，收入 ¥${riderFee}`);
  } catch (err) {
    await conn.rollback();
    next(err);
  } finally {
    conn.release();
  }
});

// 骑手当前进行中的单
router.get('/:id/active', async (req, res, next) => {
  try {
    const [orders] = await pool.query(
      'SELECT * FROM orders WHERE rider_id = ? AND status IN (2, 3) ORDER BY accepted_at DESC LIMIT 1',
      [req.params.id]
    );
    if (!orders.length) return success(res, null);
    success(res, await enrichOrder(orders[0]));
  } catch (err) {
    next(err);
  }
});

// 骑手历史订单
router.get('/:id/orders', async (req, res, next) => {
  try {
    const [orders] = await pool.query(
      'SELECT * FROM orders WHERE rider_id = ? ORDER BY created_at DESC LIMIT 50',
      [req.params.id]
    );
    const result = [];
    for (const order of orders) {
      result.push(await enrichOrder(order));
    }
    success(res, result);
  } catch (err) {
    next(err);
  }
});

// 骑手收入明细
router.get('/:id/earnings', async (req, res, next) => {
  try {
    const riderId = req.params.id;
    const [rider] = await pool.query('SELECT id, name, total_orders, total_earnings, balance FROM riders WHERE id = ?', [riderId]);
    if (!rider.length) return fail(res, '骑手不存在', 404, 404);

    const [settlements] = await pool.query(
      `SELECT rs.*, o.address_snapshot FROM rider_settlements rs
       LEFT JOIN orders o ON o.id = rs.order_id
       WHERE rs.rider_id = ? ORDER BY rs.created_at DESC LIMIT 30`,
      [riderId]
    );

    const [todayRows] = await pool.query(
      `SELECT COALESCE(SUM(amount), 0) AS today_earnings, COUNT(*) AS today_orders
       FROM rider_settlements WHERE rider_id = ? AND DATE(created_at) = CURDATE()`,
      [riderId]
    );

    success(res, {
      rider: rider[0],
      today: todayRows[0],
      settlements: settlements.map((s) => ({
        ...s,
        address_snapshot: safeJson(s.address_snapshot),
      })),
    });
  } catch (err) {
    next(err);
  }
});

// 上下线
router.patch('/:id/online', async (req, res, next) => {
  try {
    const { online } = req.body;
    await pool.query('UPDATE riders SET online = ? WHERE id = ?', [online ? 1 : 0, req.params.id]);
    const [riders] = await pool.query('SELECT * FROM riders WHERE id = ?', [req.params.id]);
    success(res, riders[0]);
  } catch (err) {
    next(err);
  }
});

// 骑手信息
router.get('/:id', async (req, res, next) => {
  try {
    const [riders] = await pool.query('SELECT * FROM riders WHERE id = ?', [req.params.id]);
    if (!riders.length) return fail(res, '骑手不存在', 404, 404);
    success(res, riders[0]);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
