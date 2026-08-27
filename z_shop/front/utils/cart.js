const CART_KEY = 'cart';

function getCart() {
  return wx.getStorageSync(CART_KEY) || [];
}

function saveCart(cart) {
  wx.setStorageSync(CART_KEY, cart);
  updateTabBarBadge(cart);
}

function addItem(product, quantity = 1) {
  const cart = getCart();
  const idx = cart.findIndex((i) => i.product_id === product.id);
  if (idx >= 0) {
    cart[idx].quantity += quantity;
  } else {
    cart.push({
      product_id: product.id,
      name: product.name,
      image: product.image,
      price: product.price,
      quantity,
    });
  }
  saveCart(cart);
  return cart;
}

function updateQuantity(productId, quantity) {
  let cart = getCart();
  if (quantity <= 0) {
    cart = cart.filter((i) => i.product_id !== productId);
  } else {
    const item = cart.find((i) => i.product_id === productId);
    if (item) item.quantity = quantity;
  }
  saveCart(cart);
  return cart;
}

function removeItem(productId) {
  const cart = getCart().filter((i) => i.product_id !== productId);
  saveCart(cart);
  return cart;
}

function clearCart() {
  saveCart([]);
}

function getTotalCount() {
  return getCart().reduce((sum, i) => sum + i.quantity, 0);
}

function getTotalPrice() {
  return getCart().reduce((sum, i) => sum + i.price * i.quantity, 0);
}

function updateTabBarBadge(cart) {
  const count = cart.reduce((sum, i) => sum + i.quantity, 0);
  if (count > 0) {
    wx.setTabBarBadge({ index: 2, text: String(count > 99 ? '99+' : count) });
  } else {
    wx.removeTabBarBadge({ index: 2 });
  }
}

module.exports = {
  getCart,
  addItem,
  updateQuantity,
  removeItem,
  clearCart,
  getTotalCount,
  getTotalPrice,
  updateTabBarBadge,
};
