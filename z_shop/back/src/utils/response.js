function success(res, data = null, message = 'ok') {
  return res.json({ code: 0, message, data });
}

function fail(res, message = 'error', code = 1, status = 400) {
  return res.status(status).json({ code, message, data: null });
}

module.exports = { success, fail };
