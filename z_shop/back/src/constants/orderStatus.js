const STATUS_MAP = {
  0: '待支付',
  1: '待接单',
  2: '待取货',
  3: '配送中',
  4: '已完成',
  5: '已取消',
};

const RIDER_ACTION = {
  1: '接单',
  2: '确认取货',
  3: '确认送达',
};

function safeJson(val) {
  if (typeof val === 'object') return val;
  try {
    return JSON.parse(val);
  } catch {
    return null;
  }
}

module.exports = { STATUS_MAP, RIDER_ACTION, safeJson };
