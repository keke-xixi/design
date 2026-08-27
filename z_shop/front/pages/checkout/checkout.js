const { request } = require('../../utils/request');
const cartUtil = require('../../utils/cart');

Page({
  data: {
    cart: [],
    totalPrice: 0,
    deliveryFee: 0,
    payAmount: 0,
    address: { name: '', phone: '', detail: '' },
    remark: '',
    submitting: false,
  },

  onShow() {
    const cart = cartUtil.getCart();
    const totalPrice = cartUtil.getTotalPrice();
    const deliveryFee = totalPrice >= 39 ? 0 : 5;
    this.setData({ cart, totalPrice, deliveryFee, payAmount: totalPrice + deliveryFee });
  },

  onInput(e) {
    const { field } = e.currentTarget.dataset;
    this.setData({ [`address.${field}`]: e.detail.value });
  },

  onRemark(e) {
    this.setData({ remark: e.detail.value });
  },

  async submitOrder() {
    const { address, remark, cart, submitting } = this.data;
    if (submitting) return;

    if (!address.name || !address.phone || !address.detail) {
      wx.showToast({ title: '请填写完整收货信息', icon: 'none' });
      return;
    }

    const app = getApp();
    let user = app.globalData.userInfo;
    if (!user) {
      user = await app.ensureLogin();
    }
    if (!user) {
      wx.showToast({ title: '请先登录', icon: 'none' });
      return;
    }

    this.setData({ submitting: true });
    try {
      const result = await request({
        url: '/api/orders',
        method: 'POST',
        data: {
          user_id: user.id,
          items: cart.map((i) => ({ product_id: i.product_id, quantity: i.quantity })),
          address,
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
