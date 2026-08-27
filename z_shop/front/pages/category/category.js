const { request } = require('../../utils/request');
const cartUtil = require('../../utils/cart');

Page({
  data: {
    categories: [],
    activeId: 0,
    products: [],
  },

  onLoad(options) {
    if (options.id) this.setData({ activeId: Number(options.id) });
    this.loadCategories();
  },

  onShow() {
    cartUtil.updateTabBarBadge(cartUtil.getCart());
  },

  async loadCategories() {
    const categories = await request({ url: '/api/categories' });
    const activeId = this.data.activeId || categories[0]?.id;
    this.setData({ categories, activeId });
    this.loadProducts(activeId);
  },

  async loadProducts(categoryId) {
    const products = await request({ url: '/api/products', data: { category_id: categoryId } });
    this.setData({ products });
  },

  switchCategory(e) {
    const id = e.currentTarget.dataset.id;
    this.setData({ activeId: id });
    this.loadProducts(id);
  },

  goProduct(e) {
    wx.navigateTo({ url: `/pages/product/product?id=${e.currentTarget.dataset.id}` });
  },

  addToCart(e) {
    cartUtil.addItem(e.currentTarget.dataset.item);
    wx.showToast({ title: '已加入购物车', icon: 'success' });
  },
});
