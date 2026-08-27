const { request } = require('../../../utils/request');

Page({
  data: {
    addresses: [],
    loading: true,
    selectMode: false,
  },

  onLoad(options) {
    this.setData({ selectMode: options.select === '1' });
  },

  onShow() {
    this.load();
  },

  async load() {
    const app = getApp();
    let user = app.globalData.userInfo || wx.getStorageSync('user');
    if (!user) user = await app.ensureLogin();
    if (!user) {
      wx.showToast({ title: '请先登录', icon: 'none' });
      return;
    }
    this.userId = user.id;
    this.setData({ loading: true });
    try {
      const addresses = await request({ url: '/api/addresses', data: { user_id: user.id } });
      this.setData({ addresses, loading: false });
    } catch {
      this.setData({ loading: false });
    }
  },

  addAddress() {
    if (this.data.addresses.length >= 10) {
      wx.showToast({ title: '最多10个地址', icon: 'none' });
      return;
    }
    wx.navigateTo({ url: '/pages/address/edit/edit' });
  },

  editAddress(e) {
    wx.navigateTo({ url: `/pages/address/edit/edit?id=${e.currentTarget.dataset.id}` });
  },

  selectAddress(e) {
    const item = e.currentTarget.dataset.item;
    wx.setStorageSync('selectedAddress', item);
    wx.navigateBack();
  },

  onTapCard(e) {
    if (this.data.selectMode) this.selectAddress(e);
  },

  stopProp() {},

  async setDefault(e) {
    const id = e.currentTarget.dataset.id;
    try {
      await request({
        url: `/api/addresses/${id}/default`,
        method: 'PATCH',
        data: { user_id: this.userId },
      });
      wx.showToast({ title: '已设为默认', icon: 'success' });
      this.load();
    } catch {}
  },

  deleteAddress(e) {
    const id = e.currentTarget.dataset.id;
    wx.showModal({
      title: '删除地址',
      content: '确定删除这个地址吗？',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await request({
            url: `/api/addresses/${id}?user_id=${this.userId}`,
            method: 'DELETE',
          });
          wx.showToast({ title: '已删除', icon: 'success' });
          this.load();
        } catch {}
      },
    });
  },
});
