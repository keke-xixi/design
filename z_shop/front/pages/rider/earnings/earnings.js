const { request } = require('../../../utils/request');
const { getRider } = require('../../../utils/rider');

Page({
  data: {
    rider: null,
    today: {},
    settlements: [],
    loading: true,
  },

  onShow() {
    this.load();
  },

  async load() {
    const rider = getRider();
    if (!rider) return;
    try {
      const data = await request({ url: `/api/riders/${rider.id}/earnings` });
      this.setData({
        rider: data.rider,
        today: data.today,
        settlements: data.settlements,
        loading: false,
      });
    } catch {
      this.setData({ loading: false });
    }
  },
});
