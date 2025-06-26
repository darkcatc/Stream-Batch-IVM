# TPC-DS 流批一体处理 Demo

**作者：Vance Chen**

## 项目概述

本项目构建了一个完整的流批一体数据处理演示环境，基于 TPC-DS 标准数据模型，展示从 MySQL 业务数据库到 Kafka 消息队列，再到 Flink 流处理的完整数据链路。

## 架构设计

![alt text](arch.png)
```
# 双路径架构：
路径1: MySQL → Flink CDC → Kafka → Flink 流式计算 → Cloudberry
路径2: MySQL → Flink CDC → Cloudberry（直接同步）
```

### 核心组件

1. **MySQL 8.0** - 业务交易数据库
   - 基于 TPC-DS 标准的 `store_sales` 和 `store_returns` 表
   - 启用 binlog 支持 CDC
   - 包含自增主键和时间戳字段

2. **Apache Kafka** - 事件总线
   - 高可用消息队列
   - 自动创建 Topic
   - JMX 监控支持

3. **Flink CDC** - 变更数据捕获
   - 基于 flink-sql-connector-mysql-cdc
   - 支持增量快照和全量同步
   - 直接转换为 PostgreSQL 兼容语句

4. **Apache Flink** - 流处理引擎
   - JobManager + TaskManager 架构
   - 支持流批一体处理
   - Web UI 监控

5. **AKHQ** - Kafka 管理界面
   - Topic 可视化管理
   - 消息实时查看
   - Connect 状态监控

6. **Cloudberry 数据仓库** - 目标存储
   - 基于 PostgreSQL 14.4 内核
   - 兼容 Greenplum 生态
   - 支持实时和批量数据写入

## 数据模型

### store_sales 表（商店销售）
- 基于 TPC-DS 标准
- 包含销售维度键、价格、数量、利润等字段
- 支持实时数据生成

### store_returns 表（商店退货）
- 退货业务数据
- 关联原始销售票据
- 支持退货金额、税费计算

## ⚡ 5分钟快速启动

```bash
# 1. 启动 Docker 环境
./start-demo.sh

# 2. 配置 Python 环境
./setup-env.sh

# 3. 激活虚拟环境
source venv/bin/activate

# 4. 测试连接
python scripts/test-connection.py

# 5. 启动数据生成器
python scripts/data-generator.py
```

🎉 **完成！** 现在可以访问：
- **Flink Dashboard**: http://localhost:8081
- **Kafka UI (AKHQ)**: http://localhost:8080

## 详细配置

### 1. 环境要求
- Docker & Docker Compose
- Python 3.8+ (用于数据生成)
- 8GB+ 内存推荐
- Ubuntu/Debian 系统 (推荐)

### 2. 启动环境
```bash
# 一键启动所有服务
./start-demo.sh
```

### 3. 配置 Python 环境
```bash
# 自动初始化 Python 环境（推荐）
./setup-env.sh

# 或手动配置
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 4. 验证环境
- **AKHQ UI**: http://localhost:8080
- **Flink Dashboard**: http://localhost:8081
- **Schema Registry**: http://localhost:8082

### 5. 测试数据库连接
```bash
# 激活Python环境
source venv/bin/activate

# 测试MySQL连接
python scripts/test-connection.py
```

### 6. 配置 Flink CDC 作业
```bash
# 进入 Flink SQL Client
docker exec -it flink-jobmanager ./bin/sql-client.sh

# 执行 CDC 同步作业
SOURCE './flink-sql/mysql-cdc-to-kafka.sql';
SOURCE './flink-sql/streaming-analytics.sql';
```

### 7. 启动数据生成器
```bash
# 激活环境并启动数据生成器
source venv/bin/activate
python3 scripts/data-generator.py

# 自定义参数示例
python3 scripts/data-generator.py --sales-interval 1 --return-probability 0.2
```

## 🚀 下一步操作

### 配置 Flink CDC 同步
```bash
# 1. 进入 Flink SQL Client
docker exec -it flink-jobmanager ./bin/sql-client.sh

# 2. 执行 SQL 脚本创建 CDC 任务
Flink SQL> SOURCE './flink-sql/mysql-cdc-to-kafka.sql';

# 3. 启动流式分析任务
Flink SQL> SOURCE './flink-sql/streaming-analytics.sql';
```

### 验证数据流
1. **查看 Flink 作业**: http://localhost:8081 确认作业运行状态
2. **监控 Kafka Topics**: http://localhost:8080 查看数据流
3. **观察实时指标**: 查看 `tpcds.sales_metrics`、`tpcds.alerts` 等 Topic

## 使用场景

### 1. Flink CDC 数据同步验证
观察 MySQL 数据变更如何通过 Flink CDC 同步：
- **路径1**: MySQL → Flink CDC → Kafka Topics
  - `tpcds.store_sales`
  - `tpcds.store_returns`
- **路径2**: MySQL → Flink CDC → Cloudberry（直接写入）

### 2. 流处理开发测试
- 基于真实业务数据模型
- 支持复杂的流式计算场景
- 易于扩展到批处理

### 3. 性能基准测试
- TPC-DS 标准数据模型
- 可配置数据生成速率
- 支持大规模数据测试

## 核心特性

✅ **生产级架构** - 基于成熟开源组件  
✅ **标准数据模型** - TPC-DS 业界标准  
✅ **实时同步** - 毫秒级 CDC 延迟  
✅ **可视化监控** - 完整的 UI 界面  
✅ **容器化部署** - 一键启动环境  
✅ **双路径设计** - 支持直接同步和流式计算  
✅ **Python 环境** - 自动化配置和依赖管理  
✅ **可扩展设计** - 支持 Cloudberry 直接集成  
✅ **配置管理** - 统一的 .env 配置系统  
✅ **工具集成** - 完整的脚本工具包  

## 技术亮点

1. **数据类型映射优化**
   - PostgreSQL → MySQL 类型转换
   - 保持 TPC-DS 语义一致性

2. **Flink CDC 性能优化**
   - 增量快照 + 实时 binlog 读取
   - 并行处理和 Checkpoint 机制
   - 支持背压和故障恢复

3. **索引策略**
   - 基于查询模式的复合索引
   - CDC 友好的主键设计

4. **监控体系**
   - Flink 作业监控和指标
   - Kafka Topic 实时监控
   - 端到端数据流可视化

5. **双路径设计**
   - 直接同步路径：适用于数据仓库 ETL
   - 流式计算路径：适用于实时分析

## 后续规划

- [x] Flink CDC 配置和 SQL 作业示例
- [ ] Cloudberry 容器化集成
- [ ] 实时 OLAP 查询示例
- [ ] 数据质量监控和告警
- [ ] 性能基准测试报告
- [ ] 增量视图物化实现

## 项目文件结构

```
├── docker-compose.yml           # Docker 服务编排
├── start-demo.sh               # 一键启动脚本
├── setup-env.sh                # Python 环境初始化
├── requirements.txt            # Python 依赖
├── PYTHON_ENV_SETUP.md         # Python 环境配置指南
├── scripts/                    # Python 脚本目录
│   ├── data-generator.py       # TPC-DS 数据生成器
│   └── test-connection.py      # MySQL 连接测试
├── flink-sql/                  # Flink SQL 脚本
│   ├── mysql-cdc-to-kafka.sql  # MySQL CDC 到 Kafka
│   ├── mysql-cdc-to-cloudberry.sql # MySQL CDC 到 Cloudberry
│   └── streaming-analytics.sql # 实时流式分析
├── mysql-init/                 # MySQL 初始化脚本
│   └── 01-init-tpcds-tables.sql
└── flink-lib/                  # Flink 连接器 JAR 包（自动下载）
```

## 数据生成器参数

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `--host` | localhost | MySQL 主机地址 |
| `--port` | 3306 | MySQL 端口 |
| `--user` | root | MySQL 用户名 |
| `--password` | root123 | MySQL 密码 |
| `--database` | business_db | 数据库名称 |
| `--sales-interval` | 2 | 销售数据生成间隔（秒） |
| `--return-probability` | 0.1 | 退货概率（0-1） |

### 使用示例

```bash
# 快速生成大量数据
python3 scripts/data-generator.py --sales-interval 0.5 --return-probability 0.15

# 低频生成，适合演示
python3 scripts/data-generator.py --sales-interval 5 --return-probability 0.05
```

## 故障排除

### 常见问题

#### 1. Python 环境问题
**错误**: `The virtual environment was not created successfully`
```bash
# 解决方案
sudo apt install python3.12-venv python3-pip
```

#### 2. MySQL 连接失败
**错误**: `Can't connect to MySQL server`
```bash
# 检查步骤
./start-demo.sh                    # 确保 Docker 服务已启动
python3 scripts/test-connection.py # 测试连接
docker ps | grep mysql             # 检查 MySQL 容器状态
```

#### 3. Flink CDC 作业失败
**错误**: 作业提交失败或数据不同步
- 验证 binlog 配置和用户权限
- 检查 ./flink-lib/ 目录中的连接器文件
- 确认 Flink CDC 作业运行状态

#### 4. Kafka Topic 无数据
- 确认 Flink CDC 作业已正确提交
- 在 AKHQ 中检查 Topic 创建情况
- 验证数据生成器是否正常运行

### 日志查看
```bash
# 查看 Flink JobManager 日志
docker logs flink-jobmanager

# 查看 Flink TaskManager 日志
docker logs flink-taskmanager

# 查看 MySQL 日志
docker logs mysql

# 查看所有服务状态
docker-compose ps

# 进入 Flink SQL Client
docker exec -it flink-jobmanager ./bin/sql-client.sh
```

## 性能调优建议

### Flink 配置优化
- 调整 TaskManager 内存：`taskmanager.memory.process.size`
- 优化并行度：`parallelism.default`
- 配置检查点间隔：`execution.checkpointing.interval`

### 数据生成器优化
- 高吞吐量：减少 `--sales-interval` 到 0.1-0.5 秒
- 低延迟测试：增加 `--return-probability` 到 0.3-0.5
- 批量数据：运行多个数据生成器实例

## 贡献指南

欢迎提交 Issue 和 Pull Request！

请确保：
- 遵循现有代码风格
- 添加必要的中文注释
- 更新相关文档

---

**联系方式**: Vance Chen  
**项目地址**: 流批一体增量视图物化系统 