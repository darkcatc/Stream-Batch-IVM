# Cloudberry CDC数据生成器

作者：Vance Chen

## 概述

这是一个用于向Cloudberry数据库生成TPC-DS模型模拟数据的Python脚本，专门设计用于模拟MySQL CDC（Change Data Capture）数据流。支持生成`store_sales_heap`和`store_returns_heap`表的测试数据，包括INSERT、UPDATE、DELETE操作。

## 特性

- **CDC模式**：模拟MySQL CDC数据流，支持INSERT、UPDATE、DELETE操作
- **微批量处理**：默认200条记录为一个微批量，模拟实时流式处理
- **智能操作分布**：每800条操作中包含1-2条UPDATE/DELETE操作
- **实时流式模拟**：支持批次间隔时间配置，模拟真实的数据流
- **持续生成模式**：支持无限循环生成数据
- **完整的错误处理和日志记录**
- **基于TPC-DS数据模型生成真实的业务数据**

## 环境要求

- Python 3.7+
- Cloudberry数据库（基于PostgreSQL 14.4）
- 已创建的目标表结构

## 安装依赖

```bash
pip install -r requirements.txt
```

## 数据库配置

脚本会自动从项目根目录的`.env`文件中读取以下配置：

```
CLOUDBERRY_HOST=127.0.0.1
CLOUDBERRY_PORT=15432
CLOUDBERRY_DATABASE=gpadmin
CLOUDBERRY_USER=gpadmin
CLOUDBERRY_PASSWORD=hashdata@123
CLOUDBERRY_SCHEMA=tpcds
```

## 使用方法

### 基本用法

```bash
# 生成50个批次的CDC数据，每批次200条记录，间隔2秒
python mock-data.py

# 自定义批次数量和大小
python mock-data.py --total-batches 100 --batch-size 150

# 持续生成模式（无限循环）
python mock-data.py --continuous --batch-interval 1.0

# 只生成销售数据
python mock-data.py --tables sales --total-batches 30

# 只生成退货数据  
python mock-data.py --tables returns --batch-size 100

# 快速模式（较小间隔）
python mock-data.py --batch-interval 0.5 --batch-size 300
```

### 参数说明

- `--total-batches`: 要生成的批次总数（默认：50）
- `--batch-size`: 微批次大小（默认：200）
- `--batch-interval`: 批次间隔时间，单位秒（默认：2.0）
- `--tables`: 要生成数据的表，可选值：`sales`、`returns`、`both`（默认：both）
- `--continuous`: 持续生成模式（无限循环）

## CDC操作模式

### 操作类型分布

- **INSERT操作**：占绝大多数（约99.75%）
- **UPDATE操作**：每800条操作中约1-2条
- **DELETE操作**：每800条操作中约1-2条

### 操作逻辑

1. **INSERT**：生成全新的记录并插入到数据库
2. **UPDATE**：随机选择已存在的记录进行字段更新
3. **DELETE**：随机选择已存在的记录进行删除

### 微批量处理

- 每个微批量包含指定数量的CDC操作
- 所有操作在一个事务中提交
- 支持批次间的时间间隔配置
- 实时显示操作统计信息

## 数据模型

### store_sales_heap 表

包含商店销售事务数据，字段包括：
- 销售维度键（日期、时间、商品、客户、商店等）
- 人口统计学维度（客户、家庭、地址）
- 销售金额（价格、成本、税费、优惠券等）
- 计算字段（净利润、扩展金额等）

**UPDATE操作特点**：
- 随机更新数量字段(`ss_quantity`)
- 随机更新优惠券金额(`ss_coupon_amt`)
- 自动重新计算相关的金额字段

### store_returns_heap 表

包含商店退货事务数据，字段包括：
- 退货维度键（日期、时间、商品、客户、商店、原因等）
- 人口统计学维度
- 退货金额（退货费、运费、税费等）
- 退款方式（现金、逆转收费、商店积分）

**UPDATE操作特点**：
- 随机更新退货数量(`sr_return_quantity`)
- 随机更新手续费(`sr_fee`)

## 日志记录

脚本会生成`mock-data.log`日志文件，记录：
- 数据库连接状态
- 批次执行进度和统计
- 操作类型分布（INSERT/UPDATE/DELETE计数）
- 执行时间和性能信息
- 错误信息和异常处理

### 日志示例

```
2024-01-15 10:30:15 - INFO - 成功连接到Cloudberry数据库: 127.0.0.1:15432
2024-01-15 10:30:15 - INFO - 加载已存在记录: 销售表 1250 条, 退货表 320 条
2024-01-15 10:30:15 - INFO - 开始CDC数据生成: 批次大小=200, 间隔=2.0秒
2024-01-15 10:30:17 - INFO - 批次操作完成: INSERT=398, UPDATE=1, DELETE=1
2024-01-15 10:30:17 - INFO - 批次 1 完成: 400 个操作, 耗时 1.85秒, 累计 400 个操作
```

## 性能调优

### 批次大小优化

- **小批次（50-100）**：适用于实时性要求高的场景
- **中批次（200-500）**：平衡性能和实时性
- **大批次（1000+）**：适用于高吞吐量场景

### 间隔时间设置

- **实时模拟（0.1-0.5秒）**：模拟高频数据变更
- **常规模拟（1-3秒）**：平衡系统负载
- **慢速模拟（5秒+）**：适用于系统资源受限场景

## 注意事项

1. **表依赖**：请确保目标表已存在且结构正确
2. **资源监控**：持续模式会不断生成数据，注意监控系统资源
3. **数据一致性**：UPDATE/DELETE操作基于已存在的记录ID
4. **事务管理**：每个微批量作为一个事务执行
5. **测试用途**：生成的数据仅用于测试和演示

## 故障排除

### 常见问题

**连接失败**
- 检查Cloudberry服务是否运行
- 验证`.env`文件中的连接配置
- 确认网络连通性和防火墙设置

**表不存在错误**
- 确保目标表已在指定schema中创建
- 检查表名和schema名称是否正确
- 验证数据库用户权限

**UPDATE/DELETE操作失败**
- 脚本会自动加载现有记录ID
- 如果没有现有记录，UPDATE/DELETE会退化为INSERT
- 检查表中是否有数据

**性能问题**
- 适当调整批次大小和间隔时间
- 监控数据库连接池和锁等待
- 考虑在数据生成期间调整索引策略

**内存使用**
- 监控Python进程内存使用
- 持续模式下注意ID集合的内存占用
- 定期重启长时间运行的进程

## 使用场景

1. **流处理测试**：模拟Flink CDC数据源
2. **数据仓库ETL测试**：测试增量数据处理逻辑
3. **实时计算验证**：验证流批一体化架构
4. **性能压测**：测试系统在持续数据变更下的表现
5. **监控告警测试**：验证数据变更监控机制 