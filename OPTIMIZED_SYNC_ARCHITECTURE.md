# 优化的数据同步架构设计

**作者：** Vance Chen  
**设计原则：** 基于 Flink 作业隔离限制的最佳实践架构  
**架构类型：** 按业务域拆分 + 单源多sink合并

## 🎯 设计目标

### 核心问题解决
1. **Flink 作业隔离**：不同作业中的表无法共享，需要独立定义
2. **避免重复 CDC 连接**：同一MySQL表不应被多个作业重复读取
3. **业务域隔离**：sales 和 returns 应独立管理，便于运维
4. **多目标同步**：同时支持实时流（Kafka）和批处理（Cloudberry）

## 🏗️ 新架构设计

### 📊 架构图示
```
MySQL business_db
├── store_sales ──┐
│                 ├─→ [Flink Job 1: Sales CDC Sync]
│                 │   ├─→ Kafka: tpcds.store_sales
│                 │   └─→ Cloudberry: tpcds.store_sales_heap
│                 
└── store_returns ─┐
                   ├─→ [Flink Job 2: Returns CDC Sync]
                   │   ├─→ Kafka: tpcds.store_returns
                   │   └─→ Cloudberry: tpcds.store_returns_heap
```

### 🎯 作业拆分策略

#### Job 1: Sales 数据同步 (`01-sales-cdc-sync.sql`)
- **输入**：MySQL `store_sales` 表 (CDC)
- **输出**：
  - Kafka Topic: `tpcds.store_sales`
  - Cloudberry Table: `tpcds.store_sales_heap`
- **特点**：
  - Server ID 范围: 5001-5010
  - 独立的 CDC 连接
  - 双写到实时和批处理存储

#### Job 2: Returns 数据同步 (`02-returns-cdc-sync.sql`)
- **输入**：MySQL `store_returns` 表 (CDC)
- **输出**：
  - Kafka Topic: `tpcds.store_returns`
  - Cloudberry Table: `tpcds.store_returns_heap`
- **特点**：
  - Server ID 范围: 5011-5020
  - 独立的 CDC 连接
  - 双写到实时和批处理存储

## ✅ 架构优势

### 1. 资源效率优化
- **避免重复连接**：每个MySQL表只有一个CDC连接
- **减少网络开销**：单次读取，多目标写入
- **并行处理**：不同业务域可独立扩展

### 2. 运维管理简化
- **作业隔离**：Sales 和 Returns 故障互不影响
- **独立扩展**：可以根据数据量调整每个作业的资源
- **监控清晰**：每个作业有独立的指标和状态

### 3. 数据一致性保障
- **事务边界**：每个作业内部保证数据一致性
- **故障恢复**：独立的检查点和重启策略
- **重复处理防护**：CDC 的幂等性保证

## 🔧 技术配置要点

### CDC 配置优化
```sql
-- 每个作业使用不同的 server-id 范围避免冲突
'server-id' = '5001-5010'  -- Sales 作业
'server-id' = '5011-5020'  -- Returns 作业

-- 增量快照优化
'scan.incremental.snapshot.enabled' = 'true'
'scan.incremental.snapshot.chunk.size' = '8192'
'debezium.snapshot.mode' = 'initial'
```

### ⚠️ Kafka Upsert 配置（关键）
**重要：CDC 数据流必须使用 `upsert-kafka` 连接器！**

```sql
-- ❌ 错误：普通 kafka 连接器（只支持追加）
'connector' = 'kafka'

-- ✅ 正确：upsert-kafka 连接器（支持 CDC 变更）
'connector' = 'upsert-kafka'
'key.format' = 'json'      -- 主键序列化
'value.format' = 'json'    -- 值序列化
PRIMARY KEY (id) NOT ENFORCED  -- 必须定义主键
```

**为什么需要 upsert-kafka？**
- CDC 会产生 **INSERT**、**UPDATE**、**DELETE** 操作
- 普通 `kafka` 连接器只支持 **追加模式**，无法处理更新和删除
- `upsert-kafka` 根据主键进行 **覆盖写入**，正确处理 CDC 变更事件
- 支持数据的 **最终一致性**，确保下游消费者看到最新状态

### Sink 配置优化
```sql
-- Kafka 配置
'sink.partitioner' = 'round-robin'         -- 负载均衡
'json.ignore-parse-errors' = 'true'        -- 容错处理

-- Cloudberry 配置  
'sink.buffer-flush.max-rows' = '1000'      -- 批量写入
'sink.buffer-flush.interval' = '2s'        -- 定时刷新
'sink.parallelism' = '2'                   -- 并行度控制
```

## 🚀 部署和使用

### 启动顺序
```bash
# 1. 启动基础环境
./start-demo.sh

# 2. 提交 Sales 同步作业
docker exec -it flink-jobmanager ./bin/sql-client.sh -f /opt/flink/sql/01-sales-cdc-sync.sql

# 3. 提交 Returns 同步作业  
docker exec -it flink-jobmanager ./bin/sql-client.sh -f /opt/flink/sql/02-returns-cdc-sync.sql
```

### 监控验证
```bash
# 检查作业状态
curl http://localhost:8081/jobs

# 查看 Kafka Topics
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

# 验证数据流
# 在 AKHQ UI: http://localhost:8080
```

## 📈 扩展性考虑

### 水平扩展
- **增加表**：新增其他 TPC-DS 表时，创建新的独立作业
- **提高吞吐量**：调整每个作业的并行度和资源配置
- **地理分布**：可以部署到不同的 Flink 集群

### 垂直扩展  
- **增加 Sink**：在现有作业中添加新的目标存储
- **数据转换**：在作业中增加实时计算逻辑
- **告警监控**：集成异常检测和告警机制

## ⚠️ 注意事项

### 1. Server ID 管理
- 确保不同作业使用不同的 server-id 范围
- 避免与其他 CDC 消费者冲突

### 2. 资源监控
- 监控每个作业的内存和CPU使用
- 调整检查点间隔避免背压

### 3. 故障处理
- 单个作业失败不影响其他作业
- 重启策略应考虑数据一致性

## 🔄 与旧架构对比

| 方面 | 旧架构 | 新架构 |
|------|--------|--------|
| CDC 连接数 | 4个 (重复连接) | 2个 (每表一个) |
| 作业数量 | 2个 (按目标分) | 2个 (按业务域分) |
| 资源利用 | 浪费 (重复读取) | 高效 (单读多写) |
| 运维复杂度 | 高 (配置重复) | 低 (独立清晰) |
| 扩展性 | 差 (耦合严重) | 好 (独立扩展) |

---

**结论：** 新架构通过按业务域拆分作业，在每个作业内合并多个sink的方式，既解决了Flink作业隔离的限制，又避免了重复CDC连接的资源浪费，是当前场景下的最佳实践方案。 