-- =============================================
-- CDC 用户和权限配置脚本
-- 作者：Vance Chen
-- 为 Flink CDC 创建专用用户和必要权限
-- =============================================

-- 创建 CDC 用户
CREATE USER IF NOT EXISTS 'flink_cdc'@'%' IDENTIFIED BY 'flink_cdc123';

-- 授予必要的权限
-- 1. SELECT 权限 - 读取数据
GRANT SELECT ON business_db.* TO 'flink_cdc'@'%';

-- 2. REPLICATION 权限 - 读取 binlog
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'flink_cdc'@'%';

-- 3. SHOW DATABASES 权限
GRANT SHOW DATABASES ON *.* TO 'flink_cdc'@'%';

-- 4. LOCK TABLES 权限 - 用于一致性快照
GRANT LOCK TABLES ON business_db.* TO 'flink_cdc'@'%';

-- 刷新权限
FLUSH PRIVILEGES;

-- 验证用户创建
SELECT User, Host FROM mysql.user WHERE User = 'flink_cdc';

-- 验证权限
SHOW GRANTS FOR 'flink_cdc'@'%';

-- 提示信息
SELECT 'CDC 用户 flink_cdc 创建完成，密码: flink_cdc123' AS message;
SELECT 'CDC 权限配置完成，支持 Flink CDC 连接器' AS cdc_ready; 