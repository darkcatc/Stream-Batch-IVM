# CDC 时区同步问题修复方案

**发现者：** 用户反馈  
**问题：** Kafka消息中的时间字段与MySQL时间不一致  
**根本原因：** Flink 和 MySQL 容器时区不一致

## 🚨 问题分析

### 当前时区状态
- **宿主机**：CST (东八区, UTC+8)
- **MySQL 容器**：SYSTEM 时区 → 跟随宿主机 CST (UTC+8)
- **Flink 容器**：UTC (UTC+0)
- **时差**：8小时

### 示例问题
```json
{
  "event_time": "2025-06-27 07:53:21Z",    // UTC 时间 (Flink)
  "created_time": "2025-06-27 15:53:21"    // CST 时间 (MySQL)
}
```

## 🔧 解决方案

### 方案1：统一时区为 UTC（推荐）

#### 1.1 修改 MySQL 时区配置
```bash
# 在 docker-compose.yml 中添加环境变量
environment:
  TZ: 'UTC'
  MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
  # ...其他配置
```

#### 1.2 修改 Flink CDC 连接器配置
```sql
CREATE TABLE mysql_store_sales (
    -- ...字段定义
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'mysql',
    'port' = '3306',
    'username' = 'flink_cdc',
    'password' = 'flink_cdc123',
    'database-name' = 'business_db',
    'table-name' = 'store_sales',
    'server-time-zone' = 'UTC',           -- 修改：统一使用UTC
    'server-id' = '5001-5010',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '8192',
    'debezium.snapshot.mode' = 'initial'
);
```

### 方案2：统一时区为 Asia/Shanghai

#### 2.1 修改 Flink 容器时区
```bash
# 在 docker-compose.yml 中添加
environment:
  TZ: 'Asia/Shanghai'
  FLINK_PROPERTIES: |
    jobmanager.rpc.address: flink-jobmanager
    # ...其他配置
```

#### 2.2 保持 CDC 连接器配置
```sql
'server-time-zone' = 'Asia/Shanghai',     -- 保持东八区
```

### 方案3：时区转换处理（当前快速修复）

#### 3.1 在 Flink SQL 中显式转换时区
```sql
-- 修改 Kafka sink 的 SELECT 语句
INSERT INTO kafka_sales_sink
SELECT 
    id,
    ss_sold_date_sk,
    ss_sold_time_sk,
    ss_item_sk,
    ss_customer_sk,
    -- ...其他字段
    CONVERT_TZ(created_at, 'Asia/Shanghai', 'UTC') as created_at,    -- 时区转换
    CONVERT_TZ(updated_at, 'Asia/Shanghai', 'UTC') as updated_at     -- 时区转换
FROM mysql_store_sales;
```

## ✅ 推荐实施方案

### 立即修复（方案3）
为了不影响当前运行的环境，建议先使用方案3进行快速修复。

### 长期解决（方案1）
下次重新部署时，建议统一使用 UTC 时区，这是分布式系统的最佳实践。

## 🔧 修复脚本

### 快速修复当前环境
```sql
-- 检查当前时区差异
SELECT 
    NOW() as mysql_local_time,
    UTC_TIMESTAMP() as mysql_utc_time,
    TIMESTAMPDIFF(HOUR, UTC_TIMESTAMP(), NOW()) as timezone_offset_hours
FROM DUAL;
```

### Docker 重启修复
```bash
# 停止当前容器
docker-compose down

# 修改 docker-compose.yml 添加时区环境变量
# 然后重新启动
docker-compose up -d
```

## 📋 验证方法

### 1. 检查时区一致性
```bash
# MySQL 时区
docker exec mysql-stage3 mysql -uroot -proot123 -e "SELECT NOW(), UTC_TIMESTAMP();"

# Flink 时区
docker exec flink-jobmanager-stage3 date

# 应该显示相同的时间（如果统一为UTC）或已知的时差
```

### 2. 验证 Kafka 消息时间
```bash
# 查看最新消息的时间字段
docker exec kafka-stage3 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic sales-events \
  --from-beginning --max-messages 1
```

### 3. 对比 MySQL 源数据
```sql
-- 在 MySQL 中查看最新记录
SELECT id, created_at, updated_at, NOW(), UTC_TIMESTAMP() 
FROM store_sales 
ORDER BY id DESC 
LIMIT 1;
```

## 🎯 最佳实践建议

1. **统一时区**：分布式系统应统一使用 UTC 时区
2. **显式配置**：不依赖系统默认时区，显式配置所有组件
3. **时间戳标准化**：存储时使用 UTC，展示时进行本地化
4. **监控验证**：定期检查各组件的时区一致性

## ⚠️ 注意事项

- 修改时区配置需要重启容器
- 历史数据的时间戳解释可能需要调整
- 下游消费者也需要了解时区处理逻辑
- 建议在非生产环境先验证修复效果

---

**结论：** 时区不一致是分布式CDC系统的常见问题，通过统一时区配置或显式时区转换可以解决。建议采用 UTC 统一时区的方案作为长期解决方案。 