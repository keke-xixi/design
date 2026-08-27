-- 骑手配送流程扩展
-- 订单状态: 0待支付 1待接单 2待取货 3配送中 4已完成 5已取消

CREATE TABLE IF NOT EXISTS riders (
  id INT PRIMARY KEY AUTO_INCREMENT,
  openid VARCHAR(64) UNIQUE COMMENT '微信 openid',
  name VARCHAR(50) NOT NULL COMMENT '骑手姓名',
  phone VARCHAR(20) NOT NULL COMMENT '手机号',
  online TINYINT DEFAULT 1 COMMENT '1在线 0离线',
  total_orders INT DEFAULT 0 COMMENT '累计完成单数',
  total_earnings DECIMAL(10,2) DEFAULT 0 COMMENT '累计收入',
  balance DECIMAL(10,2) DEFAULT 0 COMMENT '可结算余额',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='骑手';

CREATE TABLE IF NOT EXISTS rider_settlements (
  id INT PRIMARY KEY AUTO_INCREMENT,
  rider_id INT NOT NULL,
  order_id INT NOT NULL,
  order_no VARCHAR(32) NOT NULL,
  amount DECIMAL(10,2) NOT NULL COMMENT '配送费收入',
  status TINYINT DEFAULT 1 COMMENT '1已入账',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_rider (rider_id),
  INDEX idx_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='骑手配送结算';

-- 扩展 orders 表（列已存在则跳过报错，脚本会忽略）
ALTER TABLE orders ADD COLUMN rider_id INT DEFAULT NULL COMMENT '骑手ID' AFTER user_id;
ALTER TABLE orders ADD COLUMN accepted_at TIMESTAMP NULL COMMENT '接单时间' AFTER rider_phone;
ALTER TABLE orders ADD COLUMN picked_up_at TIMESTAMP NULL COMMENT '取货时间' AFTER accepted_at;

-- 门店取货点配置
CREATE TABLE IF NOT EXISTS store_config (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL DEFAULT '想吃什么菜·前置仓',
  address VARCHAR(200) NOT NULL DEFAULT '菜市场A区3号档口',
  phone VARCHAR(20) DEFAULT '',
  latitude DECIMAL(10,6) DEFAULT NULL,
  longitude DECIMAL(10,6) DEFAULT NULL,
  rider_fee DECIMAL(10,2) DEFAULT 6.00 COMMENT '每单骑手配送收入',
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='门店配置';

INSERT INTO store_config (name, address, phone, rider_fee) VALUES
  ('想吃什么菜·前置仓', '菜市场A区3号档口（早7点-晚9点）', '13800000000', 6.00)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- 已有「已支付」订单统一改为待接单
UPDATE orders SET status = 1 WHERE status IN (0, 1) AND rider_id IS NULL;
