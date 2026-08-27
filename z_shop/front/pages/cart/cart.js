const cartUtil = require('../../utils/cart');

Page({
  data: {
    cart: [],
    totalPrice: 0,
    deliveryFee: 0,
    payAmount: 0,
  },

  onShow() {
    this.refresh();
  },

  refresh() {
    const cart = cartUtil.getCart();
    const totalPrice = cartUtil.getTotalPrice();
    const deliveryFee = totalPrice >= 39 || totalPrice === 0 ? 0 : 5;
    const payAmount = totalPrice + deliveryFee;
    this.setData({ cart, totalPrice, deliveryFee, payAmount });
    cartUtil.updateTabBarBadge(cart);
  },

  changeQty(e) {
    const { id, type } = e.currentTarget.dataset;
    const item = this.data.cart.find((i) => i.product_id === id);
    const qty = type === 'plus' ? item.quantity + 1 : item.quantity - 1;
    cartUtil.updateQuantity(id, qty);
    this.refresh();
  },

  removeItem(e) {
    cartUtil.removeItem(e.currentTarget.dataset.id);
    this.refresh();
  },

  checkout() {
    if (!this.data.cart.length) {
      wx.showToast({ title: '购物车为空', icon: 'none' });
      return;
    }
    wx.navigateTo({ url: '/pages/checkout/checkout' });
  },

  goShop() {
    wx.switchTab({ url: '/pages/index/index' });
  },
});
