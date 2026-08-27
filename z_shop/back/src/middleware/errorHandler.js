function errorHandler(err, req, res, next) {
  console.error('[API Error]', err.message);
  res.status(err.status || 500).json({
    code: err.code || 500,
    message: err.message || '服务器内部错误',
    data: null,
  });
}

module.exports = errorHandler;
