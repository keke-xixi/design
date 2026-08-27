const RIDER_KEY = 'rider';

function getRider() {
  return wx.getStorageSync(RIDER_KEY) || null;
}

function saveRider(rider) {
  wx.setStorageSync(RIDER_KEY, rider);
}

function clearRider() {
  wx.removeStorageSync(RIDER_KEY);
}

module.exports = { getRider, saveRider, clearRider };
