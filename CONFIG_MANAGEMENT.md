# 配置管理系统

## 概述

为了解决硬编码配置问题，项目采用了统一的配置管理系统。所有组件的配置信息都通过环境变量文件进行管理，支持配置验证、模板生成和动态加载。

## 配置文件结构

```
config/
├── application.env      # 应用程序通用配置
├── database.env         # 数据库配置（MySQL、Cloudberry）
├── kafka.env           # 消息队列配置（Kafka、Zookeeper）
├── flink.env           # Flink流处理引擎配置
└── config-loader.py    # 配置加载器
```

## 配置文件说明

### 1. application.env - 应用程序配置
```bash
# 项目基础配置
COMPOSE_PROJECT_NAME=stream-batch-ivm
NETWORK_NAME=stream-batch-network

# 数据生成器配置
DATA_GENERATOR_BATCH_SIZE=1000
DATA_GENERATOR_INTERVAL=5
DATA_GENERATOR_MAX_RECORDS=0
DATA_GENERATOR_THREADS=2

# 日志和监控配置
LOG_LEVEL=INFO
HEALTH_CHECK_INTERVAL=30
MAX_RETRY_ATTEMPTS=3
```

### 2. database.env - 数据库配置
```bash
# MySQL 配置
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_CDC_USER=flink_cdc
MYSQL_CDC_PASSWORD=flink_cdc123
MYSQL_DATABASE=business_db

# Cloudberry 配置
CLOUDBERRY_HOST=cloudberry-host
CLOUDBERRY_PORT=15432
CLOUDBERRY_USER=gpadmin
CLOUDBERRY_PASSWORD=gpadmin
CLOUDBERRY_DATABASE=tpcds_db
CLOUDBERRY_SCHEMA=tpcds
```

### 3. kafka.env - 消息队列配置
```bash
# Kafka 配置
KAFKA_HOST=kafka
KAFKA_INTERNAL_PORT=29092
KAFKA_EXTERNAL_PORT=9092
KAFKA_BROKER_ID=1

# Zookeeper 配置  
ZOOKEEPER_HOST=zookeeper
ZOOKEEPER_PORT=2181

# Schema Registry 配置
SCHEMA_REGISTRY_HOST=schema-registry
SCHEMA_REGISTRY_PORT=8081
```

### 4. flink.env - Flink配置
```bash
# Flink JobManager 配置
FLINK_JOBMANAGER_HOST=flink-jobmanager
FLINK_JOBMANAGER_WEB_PORT=8081

# Flink 运行时配置
FLINK_PARALLELISM_DEFAULT=2
FLINK_TASKMANAGER_SLOTS=4
FLINK_CHECKPOINT_INTERVAL=60000

# Flink CDC 配置
FLINK_CDC_SNAPSHOT_MODE=initial
FLINK_CDC_INCREMENTAL_SNAPSHOT_ENABLED=true
FLINK_CDC_SNAPSHOT_CHUNK_SIZE=8096
```

## 配置管理工具

### 1. 配置管理脚本

**重要：使用配置管理脚本前请激活虚拟环境**

```bash
# 激活虚拟环境
source venv/bin/activate

# 显示所有配置摘要
python scripts/manage-config.py show

# 显示指定服务配置
python scripts/manage-config.py show --service mysql
python scripts/manage-config.py show --service cloudberry

# 验证配置完整性
python scripts/manage-config.py validate

# 生成Flink SQL配置文件
python scripts/manage-config.py generate

# 测试服务连接（需要mysql-connector-python）
python scripts/test-connection.py

# 列出配置文件
python scripts/manage-config.py list

# 编辑配置文件
python scripts/manage-config.py edit database.env
```

### 2. 配置加载器API
```python
from config_loader import ConfigLoader

# 初始化配置加载器
loader = ConfigLoader()

# 加载所有配置
config = loader.load_all_configs()

# 获取特定服务配置
mysql_config = loader.get_connection_params('mysql')
cloudberry_config = loader.get_connection_params('cloudberry')

# 生成SQL配置文件
loader.generate_sql_config(
    template_path='templates/example.template.sql',
    output_path='output/example.sql'
)
```

## 配置优先级

配置加载遵循以下优先级（从高到低）：

1. **环境变量** - 系统环境变量
2. **配置文件** - .env文件中的配置
3. **默认值** - 代码中的默认值

## 环境变量替换

配置支持变量引用和默认值：

```bash
# 变量引用
CLOUDBERRY_JDBC_URL=jdbc:postgresql://${CLOUDBERRY_HOST}:${CLOUDBERRY_PORT}/${CLOUDBERRY_DATABASE}

# 带默认值的变量引用
KAFKA_EXTERNAL_PORT=${KAFKA_PORT:-9092}
```

## Docker Compose集成

Docker Compose文件已经更新为使用配置变量：

```yaml
services:
  mysql:
    hostname: ${MYSQL_HOST:-mysql}
    ports:
      - "${MYSQL_EXTERNAL_PORT:-3306}:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-root123}
    env_file:
      - ./config/database.env
      - ./config/application.env
```

## 安全最佳实践

### 1. 密码管理
- **开发环境**: 使用配置文件中的密码
- **生产环境**: 使用环境变量覆盖配置文件中的密码
- **永远不要**将生产密码提交到版本控制

### 2. 配置文件权限
```bash
# 设置合适的文件权限
chmod 600 config/*.env
```

### 3. 环境变量
```bash
# 生产环境设置敏感信息
export MYSQL_CDC_PASSWORD="your-secure-password"
export CLOUDBERRY_PASSWORD="your-secure-password"
```

## 模板系统

### Flink SQL模板
项目支持Flink SQL模板，可以生成配置化的SQL文件：

```sql
-- 模板文件: flink-sql/templates/mysql-cdc-to-cloudberry.template.sql
CREATE TABLE mysql_source (
  ...
) WITH (
  'connector' = 'mysql-cdc',
  'hostname' = '${MYSQL_HOST}',
  'port' = '${MYSQL_PORT}',
  'username' = '${MYSQL_CDC_USER}',
  'password' = '${MYSQL_CDC_PASSWORD}'
);
```

生成的文件会替换所有变量：
```sql
-- 生成文件: flink-sql/mysql-cdc-to-cloudberry.sql
CREATE TABLE mysql_source (
  ...
) WITH (
  'connector' = 'mysql-cdc',
  'hostname' = 'mysql',
  'port' = '3306',
  'username' = 'flink_cdc',
  'password' = 'flink_cdc123'
);
```

## 使用场景

### 1. 开发环境配置
```bash
# 直接使用默认配置启动
docker-compose up -d

# 查看当前配置
python scripts/manage-config.py show
```

### 2. 测试环境配置
```bash
# 修改配置文件
python scripts/manage-config.py edit database.env

# 验证配置
python scripts/manage-config.py validate

# 重新生成SQL文件
python scripts/manage-config.py generate

# 重启服务
docker-compose down && docker-compose up -d
```

### 3. 生产环境配置
```bash
# 通过环境变量覆盖敏感配置
export MYSQL_CDC_PASSWORD="prod-password"
export CLOUDBERRY_PASSWORD="prod-password"

# 验证配置
python scripts/manage-config.py validate

# 启动服务
docker-compose up -d
```

## 故障排除

### 1. 配置验证失败
```bash
# 检查缺少的配置项
python scripts/manage-config.py validate

# 检查配置文件语法
python scripts/manage-config.py list
```

### 2. 模板生成失败
```bash
# 检查模板文件是否存在
ls -la flink-sql/templates/

# 查看详细错误信息
python scripts/manage-config.py generate
```

### 3. 连接测试失败
```bash
# 测试数据库连接
python scripts/manage-config.py test

# 检查网络配置
docker network ls
docker network inspect stream-batch-network
```

## 扩展配置

### 添加新服务配置
1. 在相应的.env文件中添加配置项
2. 更新`config_loader.py`中的`get_connection_params`方法
3. 更新`manage-config.py`中的验证规则
4. 更新`docker-compose.yml`中的环境变量引用

### 添加新模板
1. 在`flink-sql/templates/`目录创建模板文件
2. 更新`scripts/manage-config.py`中的模板映射
3. 使用`${VARIABLE_NAME}`格式定义变量

## 总结

通过这个配置管理系统，你可以：

✅ **统一管理**所有组件配置  
✅ **轻松切换**不同环境的配置  
✅ **安全处理**敏感信息  
✅ **验证配置**完整性  
✅ **自动生成**配置化文件  
✅ **支持模板**系统

这解决了你提到的硬编码问题，现在Cloudberry的IP、端口、用户等信息都可以通过配置文件统一管理。 