Page({
  data: {
    user: null,
  },

  onShow() {
    const app = getApp();
    const user = app.globalData.userInfo || wx.getStorageSync('user');
    this.setData({ user });
  },

  goOrders() {
    wx.navigateTo({ url: '/pages/orders/orders' });
  },
});
