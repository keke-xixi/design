# 想吃什么菜 (z_shop)

菜市场生鲜小程序 —— 在线买菜，骑手配送到家。支持分类浏览、搜索、购物车、下单。

## 商品分类

- 新鲜蔬菜：西红柿、大白菜、土豆等
- 肉禽蛋品：牛腩、鸡蛋、五花肉等
- 海鲜水产：基围虾、鲈鱼等
- 熟食卤味：北京烤鸭、卤牛肉等
- 粮油调味：大米、花生油、豆腐等

## 目录结构

```
z_shop/
├── front/          # 微信小程序前端
│   ├── pages/      # 页面：首页、分类、详情、购物车、结算、订单、我的
│   └── utils/      # 请求封装、购物车工具
└── back/           # Node.js + Express 后端 API
    ├── src/        # 路由、配置
    ├── sql/        # 数据库建表 & 示例数据
    └── scripts/    # 初始化脚本
```

## 快速启动

### 1. 后端

```bash
cd z_shop/back
npm install
npm run db:init    # 初始化数据库表
npm run db:grocery # 导入生鲜商品 & 下载图片
npm run dev      # 启动 API，默认 http://localhost:3000
```

### 2. 前端（微信开发者工具）

```bash
cd z_shop/front
node scripts/gen-icons.js   # 生成 TabBar 占位图标
```

1. 打开 [微信开发者工具](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html)
2. 导入项目，目录选 `z_shop/front`
3. AppID 先用测试号
4. 详情 → 本地设置 → 勾选「不校验合法域名」
5. 真机调试时，把 `utils/config.js` 里的 `BASE_URL` 改成电脑局域网 IP

## API 接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/health | 健康检查 |
| GET | /api/categories | 分类列表 |
| GET | /api/products | 商品列表（支持 category_id） |
| GET | /api/products/:id | 商品详情 |
| POST | /api/users/login | 登录（MVP 模拟） |
| POST | /api/orders | 创建订单 |
| GET | /api/orders?user_id= | 订单列表 |

## 业务说明

- **商品**：菜市场生鲜，按分类浏览，支持搜索
- **下单**：选商品 → 购物车 → 填地址 → 提交订单
- **配送**：满 39 元免配送费，否则 5 元

## 后续扩展方向

- [ ] 微信真实登录（code2Session）
- [ ] 微信支付
- [ ] 收货地址管理（CRUD）
- [ ] 骑手端小程序 / 配送状态推送
- [ ] 管理后台（商品、订单、骑手管理）
- [ ] 商品图片上传（OSS）
- [ ] 优惠券、会员体系

## 环境变量

后端配置见 `back/.env.example`，复制为 `.env` 并填写数据库信息。
