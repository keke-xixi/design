-- z_shop 数据库初始化
-- 净菜配送：用户下单 → 骑手配送 → 回家直接炒

CREATE TABLE IF NOT EXISTS categories (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL COMMENT '分类名',
  icon VARCHAR(255) DEFAULT '' COMMENT '图标 URL',
  sort_order INT DEFAULT 0,
  status TINYINT DEFAULT 1 COMMENT '1启用 0禁用',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='菜品分类';

CREATE TABLE IF NOT EXISTS products (
  id INT PRIMARY KEY AUTO_INCREMENT,
  category_id INT NOT NULL,
  name VARCHAR(100) NOT NULL COMMENT '菜名',
  subtitle VARCHAR(200) DEFAULT '' COMMENT '副标题，如"免洗免切 30分钟上桌"',
  description TEXT COMMENT '详情描述',
  image VARCHAR(255) DEFAULT '',
  price DECIMAL(10,2) NOT NULL COMMENT '售价',
  original_price DECIMAL(10,2) DEFAULT NULL COMMENT '原价',
  servings INT DEFAULT 2 COMMENT '几人份',
  cook_time INT DEFAULT 30 COMMENT '预计烹饪分钟',
  ingredients TEXT COMMENT '食材清单 JSON',
  steps TEXT COMMENT '烹饪步骤 JSON',
  stock INT DEFAULT 999 COMMENT '库存',
  sales INT DEFAULT 0 COMMENT '销量',
  status TINYINT DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_category (category_id),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='净菜套餐';

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
  ('家常小炒', '🍳', 1),
  ('硬菜大宴', '🥩', 2),
  ('汤羹暖锅', '🍲', 3),
  ('快手简餐', '🍜', 4)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- 示例净菜套餐
INSERT INTO products (category_id, name, subtitle, description, image, price, original_price, servings, cook_time, ingredients, steps, sales) VALUES
  (1, '鱼香肉丝', '免洗免切 · 经典川味', '猪里脊、木耳、胡萝卜、青椒全部切好配齐，附鱼香汁包，回家热锅快炒即可。', '', 28.80, 35.00, 2, 15,
   '["猪里脊 150g","木耳 30g","胡萝卜 50g","青椒 50g","鱼香汁 1包","葱姜蒜 各1份"]',
   '["1. 热锅凉油，下肉丝滑散","2. 加入蔬菜快炒","3. 倒入鱼香汁翻匀即可"]', 128),
  (1, '番茄炒蛋', '净菜配齐 · 10分钟上桌', '番茄切块、鸡蛋打好，调料配齐，新手也能做出餐厅味。', '', 18.80, 22.00, 2, 10,
   '["番茄 2个","鸡蛋 3个","葱花 1份","盐糖 各1包"]',
   '["1. 鸡蛋炒熟盛出","2. 番茄炒出汁","3. 倒入鸡蛋翻炒均匀"]', 256),
  (2, '红烧排骨', '已焯水 · 附红烧料包', '排骨切好块并焯水，配红烧料包，回家慢炖40分钟软烂入味。', '', 45.80, 52.00, 3, 40,
   '["排骨 500g","姜片 3片","红烧料包 1份","八角 2颗"]',
   '["1. 排骨加料包和水","2. 大火烧开转小火","3. 炖至汤汁浓稠"]', 89),
  (3, '番茄蛋花汤', '食材洗净 · 5分钟搞定', '番茄、鸡蛋、香菜配齐，清淡暖胃。', '', 15.80, NULL, 2, 8,
   '["番茄 2个","鸡蛋 2个","香菜 1份","盐 1包"]',
   '["1. 番茄煮软","2. 淋入蛋液","3. 撒香菜调味"]', 167),
  (4, '扬州炒饭', '隔夜饭+配料全齐', '米饭、火腿丁、青豆、玉米、虾仁全部配好，一锅炒香。', '', 22.80, 26.00, 2, 12,
   '["米饭 300g","火腿丁 50g","青豆玉米 80g","虾仁 50g","酱油 1包"]',
   '["1. 热锅下料","2. 倒入米饭","3. 大火翻炒均匀"]', 203);
