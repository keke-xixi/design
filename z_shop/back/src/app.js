const express = require('express');
const cors = require('cors');
require('dotenv').config();

const errorHandler = require('./middleware/errorHandler');
const pool = require('./config/db');
const categoryRoutes = require('./routes/categories');
const productRoutes = require('./routes/products');
const orderRoutes = require('./routes/orders');
const userRoutes = require('./routes/users');
const riderRoutes = require('./routes/riders');
const addressRoutes = require('./routes/addresses');
const serviceRoutes = require('./routes/service');
const { success } = require('./utils/response');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/api/health', async (req, res) => {
  try {
    await pool.ping();
    success(res, { status: 'ok', db: 'connected', time: new Date().toISOString() });
  } catch (err) {
    res.status(503).json({ code: 503, message: '数据库连接失败: ' + err.message, data: null });
  }
});

app.use('/api/categories', categoryRoutes);
app.use('/api/products', productRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/users', userRoutes);
app.use('/api/riders', riderRoutes);
app.use('/api/addresses', addressRoutes);
app.use('/api/service', serviceRoutes);

app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`z_shop API 运行在 http://localhost:${PORT}`);
});
