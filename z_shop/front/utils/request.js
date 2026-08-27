const { BASE_URL } = require('./config');

function request({ url, method = 'GET', data = {} }) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: BASE_URL + url,
      method,
      data,
      header: { 'Content-Type': 'application/json' },
      success(res) {
        if (res.data && res.data.code === 0) {
          resolve(res.data.data);
        } else {
          wx.showToast({ title: res.data?.message || '请求失败', icon: 'none' });
          reject(res.data);
        }
      },
      fail(err) {
        wx.showToast({ title: '网络错误', icon: 'none' });
        reject(err);
      },
    });
  });
}

module.exports = { request };
