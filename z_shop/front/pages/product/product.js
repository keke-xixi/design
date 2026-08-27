const { request } = require('../../utils/request');
const { resolveImage } = require('../../utils/image');
const cartUtil = require('../../utils/cart');

Page({
  data: {
    product: null,
    quantity: 1,
  },

  onLoad(options) {
    this.loadProduct(options.id);
  },

  async loadProduct(id) {
    const product = await request({ url: `/api/products/${id}` });
    this.setData({ product: { ...product, image: resolveImage(product.image) } });
  },

  changeQty(e) {
    const type = e.currentTarget.dataset.type;
    let { quantity } = this.data;
    if (type === 'minus' && quantity > 1) quantity--;
    if (type === 'plus') quantity++;
    this.setData({ quantity });
  },

  addToCart() {
    const { product, quantity } = this.data;
    cartUtil.addItem(product, quantity);
    wx.showToast({ title: '已加入购物车', icon: 'success' });
  },

  buyNow() {
    const { product, quantity } = this.data;
    cartUtil.addItem(product, quantity);
    wx.navigateTo({ url: '/pages/checkout/checkout' });
  },
});
