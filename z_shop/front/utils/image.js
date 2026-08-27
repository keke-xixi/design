const DEFAULT_IMG = '/assets/products/tomato.jpg';

function resolveImage(url) {
  if (!url) return DEFAULT_IMG;
  if (url.startsWith('/assets/')) return url;
  if (url.startsWith('http')) return url;
  return DEFAULT_IMG;
}

module.exports = { resolveImage, DEFAULT_IMG };
