const { request } = require('../../utils/request');

Page({
  data: {
    contact: null,
    loading: true,
  },

  onLoad() {
    this.load();
  },

  async load() {
    try {
      const contact = await request({ url: '/api/service/contact' });
      this.setData({ contact, loading: false });
    } catch {
      this.setData({ loading: false });
    }
  },

  callPhone() {
    const phone = this.data.contact?.phone;
    if (phone) wx.makePhoneCall({ phoneNumber: phone.replace(/-/g, '') });
  },

  copyWechat() {
    const id = this.data.contact?.wechat_id;
    if (id) {
      wx.setClipboardData({ data: id });
      wx.showToast({ title: '微信号已复制', icon: 'success' });
    }
  },
});
