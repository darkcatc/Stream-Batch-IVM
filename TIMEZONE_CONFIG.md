# 时区配置完整指南

## 📅 项目时区统一配置

**作者：** Vance Chen  
**更新时间：** 2024年12月  
**适用项目：** Stream-Batch-IVM 流式-批处理增量视图维护系统

## 🎯 配置目标

确保整个分布式系统中所有组件使用统一的时区设置，避免时间不一致导致的数据处理问题。

## 📋 时区配置概览

### 1. 环境变量配置 (.env)

新增了以下时区相关环境变量：

```bash
# 时区配置
TIMEZONE=Asia/Shanghai          # 通用时区设置
TZ=Asia/Shanghai               # Docker容器时区
JAVA_TIMEZONE=Asia/Shanghai    # Java应用时区
MYSQL_TIMEZONE=Asia/Shanghai   # MySQL数据库时区
FLINK_TIMEZONE=Asia/Shanghai   # Flink本地时区
```

### 2. 所有服务时区配置

#### MySQL 数据库
- 环境变量：`TZ=${TZ}`
- 启动参数：`--default-time-zone=${TZ}`
- 健康检查：使用环境变量中的密码

#### Flink 集群
- JobManager和TaskManager：`TZ=${TZ}`
- Flink配置：`table.local-time-zone: ${FLINK_TIMEZONE}`
- 确保CDC时间处理正确

#### Kafka 集群
- Zookeeper：`TZ=${TZ}`
- Kafka Broker：`TZ=${TZ}`
- AKHQ管理界面：`TZ=${TZ}`

#### 其他服务
- Schema Registry：`TZ=${TZ}`
- Alpine初始化容器：`TZ=${TZ}`

## 🗂️ 文件更新清单

### 已更新的文件：

1. **主配置文件**
   - `/.env` - 添加了完整的时区环境变量
   - `/docker-compose.yml` - 所有服务添加时区配置

2. **调试阶段配置**
   - `/debug-stages/stage1-mysql/docker-compose.yml`
   - `/debug-stages/stage2-cdc-cloudberry/docker-compose.yml`
   - `/debug-stages/stage3-cdc-kafka/docker-compose.yml`

3. **验证工具**
   - `/scripts/verify-timezone.sh` - 时区配置验证脚本

## 🔧 验证方法

### 使用验证脚本
```bash
# 运行时区验证脚本
./scripts/verify-timezone.sh
```

### 手动验证

#### 1. 检查容器时区
```bash
# 检查所有容器的时区
docker ps --format "{{.Names}}" | xargs -I {} docker exec {} date '+%Z %z'
```

#### 2. 检查MySQL时区
```bash
# 连接MySQL检查时区设置
docker exec mysql mysql -uroot -proot123 -e "SELECT @@system_time_zone, @@time_zone;"
```

#### 3. 检查Flink时区
```bash
# 检查Flink JobManager的Java时区
docker exec flink-jobmanager java -XshowSettings:properties -version 2>&1 | grep timezone
```

## 🚀 部署建议

### 1. 重新部署步骤
```bash
# 停止现有服务
docker-compose down

# 重新构建并启动
docker-compose up -d

# 验证时区配置
./scripts/verify-timezone.sh
```

### 2. 阶段性部署
```bash
# Stage 1 - 仅MySQL
cd debug-stages/stage1-mysql
docker-compose down && docker-compose up -d

# Stage 2 - MySQL + Flink CDC
cd ../stage2-cdc-cloudberry
docker-compose down && docker-compose up -d

# Stage 3 - 完整的Kafka流处理
cd ../stage3-cdc-kafka
docker-compose down && docker-compose up -d
```

## ⚠️ 注意事项

### 1. 时区一致性
- 所有容器必须使用相同的时区设置
- CDC数据流中的时间戳处理依赖正确的时区
- Flink作业的窗口计算需要统一时区

### 2. 数据迁移考虑
- 如果已有数据，需要考虑时区变更对历史数据的影响
- CDC快照可能需要重新生成
- 建议在非生产环境先验证

### 3. 兼容性验证
- MySQL 8.0 支持动态时区设置
- Flink 1.20.1 完全支持本地时区配置
- Kafka 时间戳使用UTC，本地展示使用容器时区

## 🐛 故障排除

### 常见问题

#### 1. 容器时区不正确
```bash
# 检查容器是否正确加载环境变量
docker exec <container_name> env | grep TZ
```

#### 2. MySQL时区设置失败
```bash
# 检查MySQL启动日志
docker logs mysql

# 手动设置时区
docker exec mysql mysql -uroot -proot123 -e "SET GLOBAL time_zone = 'Asia/Shanghai';"
```

#### 3. Flink时区配置无效
```bash
# 检查Flink配置
docker exec flink-jobmanager cat /opt/flink/conf/flink-conf.yaml | grep timezone
```

## 📊 配置验证清单

- [ ] .env文件包含所有时区变量
- [ ] 所有docker-compose.yml文件使用环境变量
- [ ] MySQL启动命令包含时区参数
- [ ] Flink配置包含table.local-time-zone设置
- [ ] 验证脚本执行正常
- [ ] 所有容器显示正确时区
- [ ] MySQL数据库时区正确
- [ ] CDC数据流时间戳正确

## 🔮 后续优化

1. **监控集成**：添加时区同步监控
2. **自动化测试**：时区配置的自动化验证
3. **文档同步**：保持时区配置文档更新
4. **CloudBerry集成**：为CloudBerry数据仓库添加时区配置

---

**维护提醒：** 每次服务更新时，请确保时区配置的一致性！ 