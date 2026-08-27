const { request } = require('../../../utils/request');
const { getRider, saveRider } = require('../../../utils/rider');

Page({
  data: {
    rider: null,
    activeOrder: null,
    todayEarnings: 0,
    todayOrders: 0,
    store: null,
    form: { name: '', phone: '' },
    loading: true,
  },

  onShow() {
    this.init();
  },

  async init() {
    const rider = getRider();
    if (!rider) {
      this.setData({ loading: false, rider: null });
      return;
    }
    this.setData({ rider, loading: true });
    try {
      const [activeOrder, earnings, store] = await Promise.all([
        request({ url: `/api/riders/${rider.id}/active` }),
        request({ url: `/api/riders/${rider.id}/earnings` }),
        request({ url: '/api/riders/store' }),
      ]);
      this.setData({
        activeOrder,
        todayEarnings: earnings.today?.today_earnings || 0,
        todayOrders: earnings.today?.today_orders || 0,
        store,
        rider: earnings.rider || rider,
        loading: false,
      });
    } catch {
      this.setData({ loading: false });
    }
  },

  onName(e) {
    this.setData({ 'form.name': e.detail.value });
  },

  onPhone(e) {
    this.setData({ 'form.phone': e.detail.value });
  },

  login() {
    const { name, phone } = this.data.form;
    if (!name || !phone) {
      wx.showToast({ title: '请填写姓名和手机号', icon: 'none' });
      return;
    }
    wx.login({
      success: async (res) => {
        try {
          const rider = await request({
            url: '/api/riders/login',
            method: 'POST',
            data: { code: res.code || 'dev', name, phone },
          });
          saveRider(rider);
          wx.showToast({ title: '登录成功', icon: 'success' });
          this.init();
        } catch {}
      },
    });
  },

  goPool() {
    wx.navigateTo({ url: '/pages/rider/pool/pool' });
  },

  goTask() {
    wx.navigateTo({ url: '/pages/rider/task/task' });
  },

  goEarnings() {
    wx.navigateTo({ url: '/pages/rider/earnings/earnings' });
  },

  callStore() {
    const phone = this.data.store?.phone;
    if (phone) wx.makePhoneCall({ phoneNumber: phone });
  },
});
