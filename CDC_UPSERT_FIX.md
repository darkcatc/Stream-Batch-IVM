# CDC Kafka Upsert 配置修复说明

**时间：** 基于用户反馈的重要修复  
**问题：** 主分支SQL未正确配置Kafka upsert支持  
**影响：** CDC的UPDATE和DELETE操作无法正确处理

## 🚨 问题分析

### 原始错误配置
```sql
-- ❌ 错误：使用普通 kafka 连接器
CREATE TABLE kafka_sales_sink (
    id BIGINT,
    -- ... 其他字段
) WITH (
    'connector' = 'kafka',           -- 问题：只支持追加
    'format' = 'json',
    'sink.partitioner' = 'round-robin'
);
```

### 问题后果
1. **UPDATE 操作**：会被当作新的INSERT处理，导致重复记录
2. **DELETE 操作**：完全无法处理，删除事件丢失
3. **数据不一致**：Kafka中的数据与MySQL源数据不同步
4. **下游影响**：基于Kafka的实时分析结果错误

## ✅ 修复方案

### 正确配置：upsert-kafka
```sql
-- ✅ 正确：使用 upsert-kafka 连接器
CREATE TABLE kafka_sales_sink (
    id BIGINT,
    -- ... 其他字段
    PRIMARY KEY (id) NOT ENFORCED,    -- 关键：定义主键
) WITH (
    'connector' = 'upsert-kafka',     -- 修复：支持upsert操作
    'topic' = 'tpcds.store_sales',
    'properties.bootstrap.servers' = 'kafka:29092',
    'key.format' = 'json',            -- 主键序列化
    'value.format' = 'json',          -- 值序列化
    'value.json.timestamp-format.standard' = 'ISO-8601',
    'value.json.fail-on-missing-field' = 'false',
    'value.json.ignore-parse-errors' = 'true'
);
```

## 🔧 技术原理

### CDC 操作映射
| MySQL CDC 操作 | 普通 kafka | upsert-kafka |
|----------------|------------|--------------|
| **INSERT** | ✅ 追加记录 | ✅ 插入记录 |
| **UPDATE** | ❌ 追加重复记录 | ✅ 覆盖原记录 |
| **DELETE** | ❌ 无法处理 | ✅ 删除记录 |

### upsert-kafka 工作机制
1. **基于主键**：使用 `PRIMARY KEY` 字段作为 Kafka 消息的 key
2. **覆盖写入**：相同key的新消息会覆盖旧消息
3. **删除处理**：DELETE操作发送 `null` 值消息（tombstone）
4. **分区策略**：根据主键hash分区，确保同一记录的所有变更在同一分区

## 📋 修复清单

### 已修复文件
- ✅ `flink-sql/01-sales-cdc-sync.sql` 
- ✅ `flink-sql/02-returns-cdc-sync.sql`
- ✅ `OPTIMIZED_SYNC_ARCHITECTURE.md` (添加upsert说明)

### 关键修改点
1. **连接器类型**：`kafka` → `upsert-kafka`
2. **格式配置**：`format` → `key.format` + `value.format`  
3. **主键定义**：添加 `PRIMARY KEY (id) NOT ENFORCED`
4. **移除配置**：删除 `sink.partitioner` (upsert-kafka自动处理)

## 🧪 验证方法

### 测试INSERT操作
```sql
-- 在MySQL中插入数据
INSERT INTO store_sales (id, ss_item_sk, ss_quantity) VALUES (1, 100, 5);
```

### 测试UPDATE操作
```sql
-- 在MySQL中更新数据
UPDATE store_sales SET ss_quantity = 10 WHERE id = 1;
```

### 检查Kafka结果
```bash
# 查看Kafka topic中的消息
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic tpcds.store_sales \
  --from-beginning \
  --property print.key=true
```

**预期结果：**
- INSERT：看到一条记录 `{"id":1} {"id":1,"ss_quantity":5,...}`
- UPDATE：看到覆盖记录 `{"id":1} {"id":1,"ss_quantity":10,...}`
- 最终只有一条记录，值为最新状态

## ⚠️ 注意事项

### 1. 主键选择
- 必须选择具有**唯一性**的字段作为主键
- 主键不能为 `NULL`
- 建议使用业务ID而非自增ID

### 2. Kafka Topic配置
```bash
# 为了支持upsert，建议开启日志压缩
docker exec kafka kafka-configs \
  --bootstrap-server localhost:9092 \
  --entity-type topics \
  --entity-name tpcds.store_sales \
  --alter --add-config cleanup.policy=compact
```

### 3. 下游消费者
- 下游消费者需要处理相同key的重复消息
- 推荐使用支持upsert语义的消费者（如Kafka Connect）

## 🎯 最佳实践总结

1. **CDC → Kafka**：始终使用 `upsert-kafka` 连接器
2. **主键定义**：明确定义PRIMARY KEY字段
3. **Topic配置**：启用日志压缩优化存储
4. **监控验证**：定期检查CDC操作的完整性
5. **文档记录**：明确标注upsert需求的重要性

---

**结论：** 这次修复解决了CDC数据流的关键问题，确保MySQL的所有变更操作（INSERT/UPDATE/DELETE）都能正确同步到Kafka，为下游实时分析提供准确的数据基础。 