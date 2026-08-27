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

## 完整业务流程

```
用户买菜下单 → 待接单(1) → 骑手接单(2) → 到取货点拿货 → 确认取货(3)
    → 配送到客户 → 确认送达(4) → 骑手自动结算配送费
```

| 角色 | 操作 |
|------|------|
| **用户** | 选菜 → 下单 → 查看订单进度（待接单/配送中/已完成） |
| **骑手** | 我的 → 骑手入口 → 待接订单 → 接单 → 取货 → 送达 → 查看收入 |
| **系统** | 记录哪个骑手、拿了哪些菜、送到哪；送达后自动入账 ¥6/单 |

## 骑手端入口

小程序 **我的 → 骑手配送入口**，首次需填写姓名和手机号。

骑手操作只需 **3 步**：接单 → 确认取货 → 确认送达

## 数据库迁移

```bash
npm run db:rider   # 骑手表、结算表、订单状态扩展
```

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
