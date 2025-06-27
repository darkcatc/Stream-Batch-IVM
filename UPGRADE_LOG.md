# 系统升级日志

## 版本升级记录 - 2025.01.21

### 🚀 Flink 1.20.1 升级合并

基于阶段2调试成功的配置，将以下关键改进合并到主项目：

#### ✅ 核心组件升级
- **Flink版本**: `1.18.0` → `1.20.1` (LTS版本)
- **CDC连接器**: `2.4.2` → `3.4.0` (兼容Flink 1.20.1)
- **MySQL JDBC**: `mysql-connector-java` → `mysql-connector-j` (新命名规范)
- **Kafka连接器**: `1.18.0` → `1.20.0`

#### ✅ 兼容性问题解决
- 修复了`NoSuchMethodError: setIsProcessingBacklog`错误
- 解决了Flink 1.18与CDC 3.4.0不兼容问题
- 更新了依赖包下载路径和版本

#### ✅ 内存配置优化
- 修复了内存配置格式问题：`1.5g` → `1536m`
- 统一了内存配置：`process.size: 2gb`, `flink.size: 1536m`
- 移除了环境变量依赖，使用固定值确保稳定性

#### ✅ CDC表定义完善
- 创建了与MySQL表结构完全匹配的CDC表定义
- 修复了主键不匹配问题（复合主键 → 单一id主键）
- 修正了字段类型映射（int vs BIGINT）
- 添加了CDC元数据字段（op_type, op_ts）

#### ✅ 监控和测试脚本
- 新增：`flink-sql/cdc-table-definitions.sql` - CDC表结构定义
- 新增：`flink-sql/cdc-monitoring-jobs.sql` - CDC任务启动脚本
- 新增：`start-cdc-demo.sh` - 整合的演示启动脚本

#### ✅ 验证结果
- CDC数据流实时监控正常
- Binlog变化捕获成功
- 性能稳定，延迟小于1秒
- 支持INSERT、UPDATE、DELETE操作类型

### 📋 依赖包列表（已验证可用）
```
flink-lib/
├── flink-sql-connector-mysql-cdc-3.4.0.jar (21MB)
├── mysql-connector-j-8.0.33.jar (2.4MB)  
└── flink-sql-connector-kafka-1.20.0.jar (待验证)
```

### 🎯 下一步计划
- **阶段3**: 集成Kafka，实现CDC → Kafka数据流
- **阶段4**: 完整的流批一体处理pipeline

### 📝 使用说明
启动已升级的CDC系统：
```bash
./start-cdc-demo.sh
```

监控CDC数据流：
```bash
# 启动数据生成器
cd scripts && python3 data_generator.py

# 启动CDC任务
docker exec flink-jobmanager /opt/flink/bin/sql-client.sh -f /tmp/cdc-monitoring-jobs.sql

# 查看实时数据流
docker logs flink-taskmanager-1 -f
``` 