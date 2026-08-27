const { request } = require('../../../utils/request');
const { getRider, saveRider } = require('../../../utils/rider');

Page({
  data: {
    order: null,
    store: null,
    loading: true,
    submitting: false,
  },

  onShow() {
    this.load();
  },

  async load() {
    const rider = getRider();
    if (!rider) {
      wx.redirectTo({ url: '/pages/rider/index/index' });
      return;
    }
    this.setData({ loading: true });
    try {
      const [order, store] = await Promise.all([
        request({ url: `/api/riders/${rider.id}/active` }),
        request({ url: '/api/riders/store' }),
      ]);
      if (!order) {
        wx.showToast({ title: '暂无进行中的订单', icon: 'none' });
        setTimeout(() => wx.navigateBack(), 1500);
        return;
      }
      this.setData({ order, store, loading: false });
    } catch {
      this.setData({ loading: false });
    }
  },

  callCustomer() {
    const phone = this.data.order?.address_snapshot?.phone;
    if (phone) wx.makePhoneCall({ phoneNumber: phone });
  },

  copyAddress() {
    const addr = this.data.order?.address_snapshot;
    if (addr) {
      const text = `${addr.name} ${addr.phone}\n${addr.detail}`;
      wx.setClipboardData({ data: text });
    }
  },

  openStoreMap() {
    const { store } = this.data;
    if (store?.latitude) {
      wx.openLocation({
        latitude: Number(store.latitude),
        longitude: Number(store.longitude),
        name: store.name,
        address: store.address,
      });
    } else {
      wx.setClipboardData({ data: store?.address || '' });
      wx.showToast({ title: '地址已复制', icon: 'none' });
    }
  },

  async doAction() {
    const { order, submitting } = this.data;
    const rider = getRider();
    if (!order || !rider || submitting) return;

    const actionMap = {
      2: { url: 'pickup', title: '确认取货', msg: '确认已从取货点拿齐所有商品？' },
      3: { url: 'deliver', title: '确认送达', msg: '确认已送达客户手中？' },
    };
    const action = actionMap[order.status];
    if (!action) return;

    wx.showModal({
      title: action.title,
      content: action.msg,
      success: async (res) => {
        if (!res.confirm) return;
        this.setData({ submitting: true });
        try {
          const result = await request({
            url: `/api/riders/orders/${order.id}/${action.url}`,
            method: 'POST',
            data: { rider_id: rider.id },
          });
          if (order.status === 3) {
            if (result.rider) saveRider(result.rider);
            wx.showModal({
              title: '送达完成',
              content: `本单收入 ¥${result.settlement?.amount || 6}`,
              showCancel: false,
              success: () => wx.redirectTo({ url: '/pages/rider/index/index' }),
            });
          } else {
            wx.showToast({ title: '取货成功', icon: 'success' });
            this.setData({ submitting: false });
            this.load();
          }
        } catch {
          this.setData({ submitting: false });
        }
      },
    });
  },
});
