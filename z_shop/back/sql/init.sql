-- z_shop 数据库初始化
-- 菜市场生鲜：用户下单 → 骑手配送到家

CREATE TABLE IF NOT EXISTS categories (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL COMMENT '分类名',
  icon VARCHAR(255) DEFAULT '' COMMENT '图标',
  sort_order INT DEFAULT 0,
  status TINYINT DEFAULT 1 COMMENT '1启用 0禁用',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品分类';

CREATE TABLE IF NOT EXISTS products (
  id INT PRIMARY KEY AUTO_INCREMENT,
  category_id INT NOT NULL,
  name VARCHAR(100) NOT NULL COMMENT '商品名',
  subtitle VARCHAR(200) DEFAULT '' COMMENT '规格副标题',
  description TEXT COMMENT '详情描述',
  image VARCHAR(255) DEFAULT '',
  price DECIMAL(10,2) NOT NULL COMMENT '售价',
  original_price DECIMAL(10,2) DEFAULT NULL COMMENT '原价',
  servings INT DEFAULT 1 COMMENT '预留字段',
  cook_time INT DEFAULT 0 COMMENT '预留字段',
  ingredients TEXT COMMENT '商品信息 JSON',
  steps TEXT COMMENT '预留字段',
  stock INT DEFAULT 999 COMMENT '库存',
  sales INT DEFAULT 0 COMMENT '销量',
  status TINYINT DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_category (category_id),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='生鲜商品';

CREATE TABLE IF NOT EXISTS users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  openid VARCHAR(64) UNIQUE COMMENT '微信 openid',
  nickname VARCHAR(50) DEFAULT '微信用户',
  avatar VARCHAR(255) DEFAULT '',
  phone VARCHAR(20) DEFAULT '',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户';

CREATE TABLE IF NOT EXISTS addresses (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  name VARCHAR(50) NOT NULL COMMENT '收货人',
  phone VARCHAR(20) NOT NULL,
  province VARCHAR(50) DEFAULT '',
  city VARCHAR(50) DEFAULT '',
  district VARCHAR(50) DEFAULT '',
  detail VARCHAR(200) NOT NULL COMMENT '详细地址',
  is_default TINYINT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收货地址';

CREATE TABLE IF NOT EXISTS orders (
  id INT PRIMARY KEY AUTO_INCREMENT,
  order_no VARCHAR(32) NOT NULL UNIQUE COMMENT '订单号',
  user_id INT NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  delivery_fee DECIMAL(10,2) DEFAULT 0,
  pay_amount DECIMAL(10,2) NOT NULL,
  status TINYINT DEFAULT 0 COMMENT '0待支付 1已支付 2配送中 3已完成 4已取消',
  address_snapshot JSON COMMENT '下单时地址快照',
  remark VARCHAR(200) DEFAULT '',
  rider_name VARCHAR(50) DEFAULT '' COMMENT '骑手姓名',
  rider_phone VARCHAR(20) DEFAULT '',
  paid_at TIMESTAMP NULL,
  delivered_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id),
  INDEX idx_status (status),
  INDEX idx_order_no (order_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单';

CREATE TABLE IF NOT EXISTS order_items (
  id INT PRIMARY KEY AUTO_INCREMENT,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  product_name VARCHAR(100) NOT NULL,
  product_image VARCHAR(255) DEFAULT '',
  price DECIMAL(10,2) NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  INDEX idx_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单明细';

-- 初始分类
INSERT INTO categories (name, icon, sort_order) VALUES
  ('新鲜蔬菜', '🥬', 1),
  ('肉禽蛋品', '🥩', 2),
  ('海鲜水产', '🦐', 3),
  ('熟食卤味', '🦆', 4),
  ('粮油调味', '🧂', 5)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- 示例生鲜商品（图片需先运行 npm run db:grocery 下载）
INSERT INTO products (category_id, name, subtitle, description, image, price, original_price, ingredients, sales) VALUES
  (1, '西红柿', '约500g · 新鲜采摘', '自然成熟，沙瓤多汁。', '/assets/products/tomato.jpg', 4.80, 6.00, '["产地直供","当日分拣"]', 892),
  (1, '大白菜', '约1kg · 当季鲜货', '叶嫩帮薄，清炒炖汤都合适。', '/assets/products/cabbage.jpg', 3.50, NULL, '["本地菜农","带泥保鲜"]', 654),
  (2, '牛腩', '约500g · 原切新鲜', '肥瘦相间，适合炖汤红烧。', '/assets/products/beef.jpg', 48.80, 55.00, '["冷鲜配送","原切不拼接"]', 186),
  (2, '鸡蛋', '10枚 · 农家散养', '蛋黄饱满，煎炒蒸煮皆宜。', '/assets/products/egg.jpg', 6.80, 8.00, '["当日到仓","无破损"]', 1203),
  (4, '北京烤鸭', '半只 · 门店现烤', '皮脆肉嫩，附饼酱葱丝。', '/assets/products/duck.jpg', 68.80, 78.00, '["现烤现配","2小时内送达"]', 245);
