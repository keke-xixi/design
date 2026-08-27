-- 改用小程序本地图片，避免外链 404
UPDATE products SET image = '/assets/products/yuxiang.jpg' WHERE name = '鱼香肉丝';
UPDATE products SET image = '/assets/products/fanqie.jpg' WHERE name = '番茄炒蛋';
UPDATE products SET image = '/assets/products/paigu.jpg' WHERE name = '红烧排骨';
UPDATE products SET image = '/assets/products/tang.jpg' WHERE name = '番茄蛋花汤';
UPDATE products SET image = '/assets/products/chaofan.jpg' WHERE name = '扬州炒饭';
