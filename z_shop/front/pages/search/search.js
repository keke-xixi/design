const { request } = require('../../utils/request');
const cartUtil = require('../../utils/cart');
const { resolveImage } = require('../../utils/image');

Page({
  data: {
    keyword: '',
    products: [],
    searched: false,
    loading: false,
    hotKeywords: ['西红柿', '鸡蛋', '牛腩', '烤鸭', '白菜', '基围虾'],
  },

  onLoad(options) {
    if (options.keyword) {
      this.setData({ keyword: options.keyword });
      this.doSearch();
    }
  },

  onInput(e) {
    this.setData({ keyword: e.detail.value });
  },

  onClear() {
    this.setData({ keyword: '', products: [], searched: false });
  },

  onSearch() {
    this.doSearch();
  },

  tapHot(e) {
    const keyword = e.currentTarget.dataset.word;
    this.setData({ keyword });
    this.doSearch();
  },

  async doSearch() {
    const keyword = this.data.keyword.trim();
    if (!keyword) {
      wx.showToast({ title: '请输入菜名', icon: 'none' });
      return;
    }
    this.setData({ loading: true, searched: true });
    try {
      const products = await request({
        url: '/api/products',
        data: { keyword, pageSize: 50 },
      });
      this.setData({ products: products.map((p) => ({ ...p, image: resolveImage(p.image) })), loading: false });
    } catch {
      this.setData({ loading: false });
    }
  },

  goProduct(e) {
    wx.navigateTo({ url: `/pages/product/product?id=${e.currentTarget.dataset.id}` });
  },

  addToCart(e) {
    cartUtil.addItem(e.currentTarget.dataset.item);
    wx.showToast({ title: '已加入购物车', icon: 'success' });
  },
});
