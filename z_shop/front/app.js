const { request } = require('./utils/request');

App({
  globalData: {
    userInfo: null,
    baseUrl: 'http://localhost:3000',
  },

  onLaunch() {
    this.ensureLogin();
  },

  ensureLogin() {
    const user = wx.getStorageSync('user');
    if (user) {
      this.globalData.userInfo = user;
      return Promise.resolve(user);
    }
    return new Promise((resolve) => {
      wx.login({
        success: (res) => {
          request({ url: '/api/users/login', method: 'POST', data: { code: res.code || 'dev' } })
            .then((userInfo) => {
              wx.setStorageSync('user', userInfo);
              this.globalData.userInfo = userInfo;
              resolve(userInfo);
            })
            .catch(() => resolve(null));
        },
        fail: () => resolve(null),
      });
    });
  },
});
