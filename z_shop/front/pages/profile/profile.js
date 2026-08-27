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

  goRider() {
    wx.navigateTo({ url: '/pages/rider/index/index' });
  },

  goAddress() {
    wx.navigateTo({ url: '/pages/address/list/list' });
  },

  goService() {
    wx.navigateTo({ url: '/pages/service/service' });
  },
});
