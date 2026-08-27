const express = require('express');
const pool = require('../config/db');
const { success, fail } = require('../utils/response');

const router = express.Router();

function genOrderNo() {
  const now = new Date();
  const pad = (n, len = 2) => String(n).padStart(len, '0');
  return `ZS${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}${Math.random().toString().slice(2, 6)}`;
}

const STATUS_MAP = {
  0: '待支付',
  1: '已支付',
  2: '配送中',
  3: '已完成',
  4: '已取消',
};

// 创建订单
router.post('/', async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const { user_id, items, address, remark = '' } = req.body;

    if (!user_id || !items?.length || !address) {
      return fail(res, '缺少必要参数');
    }

    await conn.beginTransaction();

    const productIds = items.map((i) => i.product_id);
    const [products] = await conn.query(
      `SELECT id, name, image, price, stock FROM products WHERE id IN (${productIds.map(() => '?').join(',')}) AND status = 1`,
      productIds
    );

    if (products.length !== items.length) {
      await conn.rollback();
      return fail(res, '部分商品不存在或已下架');
    }

    const productMap = Object.fromEntries(products.map((p) => [p.id, p]));
    let totalAmount = 0;
    const orderItems = [];

    for (const item of items) {
      const product = productMap[item.product_id];
      if (product.stock < item.quantity) {
        await conn.rollback();
        return fail(res, `${product.name} 库存不足`);
      }
      const subtotal = product.price * item.quantity;
      totalAmount += subtotal;
      orderItems.push({
        product_id: product.id,
        product_name: product.name,
        product_image: product.image,
        price: product.price,
        quantity: item.quantity,
      });
    }

    const deliveryFee = totalAmount >= 39 ? 0 : 5;
    const payAmount = totalAmount + deliveryFee;
    const orderNo = genOrderNo();

    const [orderResult] = await conn.query(
      `INSERT INTO orders (order_no, user_id, total_amount, delivery_fee, pay_amount, status, address_snapshot, remark)
       VALUES (?, ?, ?, ?, ?, 1, ?, ?)`,
      [orderNo, user_id, totalAmount, deliveryFee, payAmount, JSON.stringify(address), remark]
    );

    const orderId = orderResult.insertId;

    for (const item of orderItems) {
      await conn.query(
        'INSERT INTO order_items (order_id, product_id, product_name, product_image, price, quantity) VALUES (?, ?, ?, ?, ?, ?)',
        [orderId, item.product_id, item.product_name, item.product_image, item.price, item.quantity]
      );
      await conn.query('UPDATE products SET stock = stock - ?, sales = sales + ? WHERE id = ?', [
        item.quantity,
        item.quantity,
        item.product_id,
      ]);
    }

    await conn.commit();
    success(res, { order_id: orderId, order_no: orderNo, pay_amount: payAmount }, '下单成功');
  } catch (err) {
    await conn.rollback();
    next(err);
  } finally {
    conn.release();
  }
});

// 订单列表
router.get('/', async (req, res, next) => {
  try {
    const { user_id, status } = req.query;
    if (!user_id) return fail(res, '缺少 user_id');

    let sql = 'SELECT * FROM orders WHERE user_id = ?';
    const params = [user_id];
    if (status !== undefined && status !== '') {
      sql += ' AND status = ?';
      params.push(status);
    }
    sql += ' ORDER BY created_at DESC';

    const [orders] = await pool.query(sql, params);

    const result = [];
    for (const order of orders) {
      const [items] = await pool.query('SELECT * FROM order_items WHERE order_id = ?', [order.id]);
      result.push({
        ...order,
        status_text: STATUS_MAP[order.status] || '未知',
        address_snapshot: safeJson(order.address_snapshot),
        items,
      });
    }
    success(res, result);
  } catch (err) {
    next(err);
  }
});

// 订单详情
router.get('/:id', async (req, res, next) => {
  try {
    const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [req.params.id]);
    if (!orders.length) return fail(res, '订单不存在', 404, 404);

    const order = orders[0];
    const [items] = await pool.query('SELECT * FROM order_items WHERE order_id = ?', [order.id]);
    success(res, {
      ...order,
      status_text: STATUS_MAP[order.status] || '未知',
      address_snapshot: safeJson(order.address_snapshot),
      items,
    });
  } catch (err) {
    next(err);
  }
});

function safeJson(val) {
  if (typeof val === 'object') return val;
  try {
    return JSON.parse(val);
  } catch {
    return null;
  }
}

module.exports = router;
