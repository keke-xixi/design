const { request } = require('../../../utils/request');
const { getRider } = require('../../../utils/rider');

Page({
  data: {
    orders: [],
    store: null,
    loading: true,
  },

  onShow() {
    this.load();
  },

  async load() {
    this.setData({ loading: true });
    try {
      const data = await request({ url: '/api/riders/orders/pending' });
      this.setData({ orders: data.orders, store: data.store, loading: false });
    } catch {
      this.setData({ loading: false });
    }
  },

  async accept(e) {
    const orderId = e.currentTarget.dataset.id;
    const rider = getRider();
    if (!rider) return;

    wx.showModal({
      title: '确认接单',
      content: '接单后请先到取货点拿货，再配送给客户',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await request({
            url: `/api/riders/orders/${orderId}/accept`,
            method: 'POST',
            data: { rider_id: rider.id },
          });
          wx.showToast({ title: '接单成功', icon: 'success' });
          wx.redirectTo({ url: '/pages/rider/task/task' });
        } catch {}
      },
    });
  },

  openStoreMap() {
    const { store } = this.data;
    if (store?.latitude) {
      wx.openLocation({
        latitude: Number(store.latitude),
        longitude: Number(store.longitude),
        name: store.name,
        address: store.address,
      });
    } else {
      wx.setClipboardData({ data: store?.address || '' });
      wx.showToast({ title: '地址已复制', icon: 'none' });
    }
  },
});
