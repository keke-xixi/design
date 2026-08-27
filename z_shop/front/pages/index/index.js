const { request } = require('../../utils/request');
const cartUtil = require('../../utils/cart');
const { resolveImage } = require('../../utils/image');

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
      const enriched = products.map((p) => ({
        ...p,
        image: resolveImage(p.image),
      }));
      this.setData({ categories, products: enriched, loading: false });
    } catch {
      this.setData({ loading: false });
    }
  },

  goSearch() {
    wx.navigateTo({ url: '/pages/search/search' });
  },

  goCategory(e) {
    const id = e.currentTarget.dataset.id;
    wx.switchTab({ url: '/pages/category/category' });
    wx.setStorageSync('pendingCategoryId', id);
  },

  goAllCategory() {
    wx.switchTab({ url: '/pages/category/category' });
  },

  goProduct(e) {
    wx.navigateTo({ url: `/pages/product/product?id=${e.currentTarget.dataset.id}` });
  },

  addToCart(e) {
    cartUtil.addItem(e.currentTarget.dataset.item);
    wx.showToast({ title: '已加入购物车', icon: 'success' });
  },
});
