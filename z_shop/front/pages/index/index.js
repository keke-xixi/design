const { request } = require('../../utils/request');
const cartUtil = require('../../utils/cart');

Page({
  data: {
    categories: [],
    products: [],
    loading: true,
  },

  onShow() {
    cartUtil.updateTabBarBadge(cartUtil.getCart());
    this.loadData();
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const [categories, products] = await Promise.all([
        request({ url: '/api/categories' }),
        request({ url: '/api/products', data: { pageSize: 10 } }),
      ]);
      this.setData({ categories, products, loading: false });
    } catch {
      this.setData({ loading: false });
    }
  },

  goCategory(e) {
    const id = e.currentTarget.dataset.id;
    wx.navigateTo({ url: `/pages/category/category?id=${id}` });
  },

  goProduct(e) {
    const id = e.currentTarget.dataset.id;
    wx.navigateTo({ url: `/pages/product/product?id=${id}` });
  },

  addToCart(e) {
    const product = e.currentTarget.dataset.item;
    cartUtil.addItem(product);
    wx.showToast({ title: '已加入购物车', icon: 'success' });
  },
});
