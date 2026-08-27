const { request } = require('../../utils/request');
const cartUtil = require('../../utils/cart');

Page({
  data: {
    cart: [],
    totalPrice: 0,
    deliveryFee: 0,
    payAmount: 0,
    address: null,
    remark: '',
    submitting: false,
  },

  onShow() {
    const cart = cartUtil.getCart();
    const totalPrice = cartUtil.getTotalPrice();
    const deliveryFee = totalPrice >= 39 ? 0 : 5;
    this.setData({ cart, totalPrice, deliveryFee, payAmount: totalPrice + deliveryFee });

    const selected = wx.getStorageSync('selectedAddress');
    if (selected) {
      wx.removeStorageSync('selectedAddress');
      this.setData({ address: selected });
    } else {
      this.loadDefaultAddress();
    }
  },

  async loadDefaultAddress() {
    if (this.data.address) return;
    const app = getApp();
    let user = app.globalData.userInfo || wx.getStorageSync('user');
    if (!user) user = await app.ensureLogin();
    if (!user) return;

    try {
      const list = await request({ url: '/api/addresses', data: { user_id: user.id } });
      const defaultAddr = list.find((a) => a.is_default) || list[0];
      if (defaultAddr) this.setData({ address: defaultAddr });
    } catch {}
  },

  chooseAddress() {
    wx.navigateTo({ url: '/pages/address/list/list?select=1' });
  },

  addAddress() {
    wx.navigateTo({ url: '/pages/address/edit/edit' });
  },

  onRemark(e) {
    this.setData({ remark: e.detail.value });
  },

  async submitOrder() {
    const { address, remark, cart, submitting } = this.data;
    if (submitting) return;

    if (!address) {
      wx.showToast({ title: '请选择收货地址', icon: 'none' });
      return;
    }

    const app = getApp();
    let user = app.globalData.userInfo;
    if (!user) user = await app.ensureLogin();
    if (!user) {
      wx.showToast({ title: '请先登录', icon: 'none' });
      return;
    }

    const orderAddress = {
      name: address.name,
      phone: address.phone,
      detail: address.full_detail || address.detail,
    };

    this.setData({ submitting: true });
    try {
      await request({
        url: '/api/orders',
        method: 'POST',
        data: {
          user_id: user.id,
          items: cart.map((i) => ({ product_id: i.product_id, quantity: i.quantity })),
          address: orderAddress,
          remark,
        },
      });
      cartUtil.clearCart();
      wx.showToast({ title: '下单成功', icon: 'success' });
      setTimeout(() => {
        wx.redirectTo({ url: '/pages/orders/orders' });
      }, 1500);
    } catch {
      this.setData({ submitting: false });
    }
  },
});
