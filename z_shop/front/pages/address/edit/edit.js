const { request } = require('../../../utils/request');

Page({
  data: {
    id: null,
    form: {
      name: '',
      phone: '',
      province: '',
      city: '',
      district: '',
      detail: '',
      is_default: false,
    },
    submitting: false,
  },

  onLoad(options) {
    if (options.id) {
      this.setData({ id: options.id });
      this.loadAddress(options.id);
    }
  },

  async loadAddress(id) {
    const app = getApp();
    const user = app.globalData.userInfo || wx.getStorageSync('user');
    const list = await request({ url: '/api/addresses', data: { user_id: user.id } });
    const addr = list.find((a) => String(a.id) === String(id));
    if (addr) {
      this.setData({
        form: {
          name: addr.name,
          phone: addr.phone,
          province: addr.province || '',
          city: addr.city || '',
          district: addr.district || '',
          detail: addr.detail,
          is_default: addr.is_default,
        },
      });
    }
  },

  onInput(e) {
    const { field } = e.currentTarget.dataset;
    this.setData({ [`form.${field}`]: e.detail.value });
  },

  toggleDefault(e) {
    this.setData({ 'form.is_default': e.detail.value });
  },

  async save() {
    const { form, id, submitting } = this.data;
    if (submitting) return;
    if (!form.name || !form.phone || !form.detail) {
      wx.showToast({ title: '请填写姓名、电话和详细地址', icon: 'none' });
      return;
    }
    if (!/^1\d{10}$/.test(form.phone)) {
      wx.showToast({ title: '手机号格式不正确', icon: 'none' });
      return;
    }

    const app = getApp();
    let user = app.globalData.userInfo || wx.getStorageSync('user');
    if (!user) user = await app.ensureLogin();

    this.setData({ submitting: true });
    try {
      if (id) {
        await request({
          url: `/api/addresses/${id}`,
          method: 'PUT',
          data: { user_id: user.id, ...form },
        });
      } else {
        await request({
          url: '/api/addresses',
          method: 'POST',
          data: { user_id: user.id, ...form },
        });
      }
      wx.showToast({ title: '保存成功', icon: 'success' });
      setTimeout(() => wx.navigateBack(), 1000);
    } catch {
      this.setData({ submitting: false });
    }
  },
});
