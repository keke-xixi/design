const { request } = require('../../utils/request');

Page({
  data: {
    orders: [],
    loading: true,
  },

  onShow() {
    this.loadOrders();
  },

  async loadOrders() {
    const app = getApp();
    let user = app.globalData.userInfo;
    if (!user) user = await app.ensureLogin();
    if (!user) {
      this.setData({ loading: false });
      return;
    }

    try {
      const orders = await request({ url: '/api/orders', data: { user_id: user.id } });
      this.setData({ orders, loading: false });
    } catch {
      this.setData({ loading: false });
    }
  },
});
