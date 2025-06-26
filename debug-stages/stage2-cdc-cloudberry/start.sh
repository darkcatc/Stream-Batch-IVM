#!/bin/bash

# 阶段2: Flink CDC → Cloudberry 调试启动脚本
# 作者: Vance Chen

set -e

echo "=========================================="
echo "阶段2: 启动 MySQL + Flink CDC 调试环境"
echo "=========================================="

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "项目根目录: $PROJECT_ROOT"

# 切换到阶段2目录
cd "$SCRIPT_DIR"

# 加载环境变量
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "加载环境变量: $PROJECT_ROOT/.env"
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "警告: 未找到 .env 文件，使用默认配置"
fi

# 首先清理阶段1（如果在运行）
echo "清理阶段1环境..."
cd "$PROJECT_ROOT/debug-stages/stage1-mysql"
./cleanup.sh || true

# 返回到阶段2目录
cd "$SCRIPT_DIR"

# 检查必要的目录
echo "检查必要的目录..."
if [ ! -d "$PROJECT_ROOT/mysql-init" ]; then
    echo "错误: mysql-init 目录不存在!"
    exit 1
fi

if [ ! -d "$PROJECT_ROOT/flink-lib" ]; then
    echo "创建 flink-lib 目录..."
    mkdir -p "$PROJECT_ROOT/flink-lib"
fi

# 下载必要的 Flink CDC 依赖包
echo "检查 Flink CDC 依赖包..."
cd "$PROJECT_ROOT/flink-lib"

FLINK_CDC_VERSION="3.0.1"
MYSQL_CONNECTOR_VERSION="3.0.1"

if [ ! -f "flink-cdc-connectors-mysql-${MYSQL_CONNECTOR_VERSION}.jar" ]; then
    echo "下载 Flink CDC MySQL 连接器..."
    wget -O "flink-cdc-connectors-mysql-${MYSQL_CONNECTOR_VERSION}.jar" \
        "https://repo1.maven.org/maven2/org/apache/flink/flink-connector-cdc-mysql/${MYSQL_CONNECTOR_VERSION}/flink-connector-cdc-mysql-${MYSQL_CONNECTOR_VERSION}.jar" || {
        echo "错误: 无法下载 Flink CDC MySQL 连接器"
        echo "请手动下载并放置到 flink-lib/ 目录"
        exit 1
    }
fi

if [ ! -f "mysql-connector-java-8.0.33.jar" ]; then
    echo "下载 MySQL JDBC 驱动..."
    wget -O "mysql-connector-java-8.0.33.jar" \
        "https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.33/mysql-connector-java-8.0.33.jar" || {
        echo "错误: 无法下载 MySQL JDBC 驱动"
        echo "请手动下载并放置到 flink-lib/ 目录"
        exit 1
    }
fi

# 返回到阶段2目录
cd "$SCRIPT_DIR"

echo "启动阶段2服务..."
docker-compose up -d

echo ""
echo "等待服务启动..."
sleep 10

echo ""
echo "=========================================="
echo "阶段2服务状态检查"
echo "=========================================="

# 检查容器状态
echo "1. 容器状态:"
docker-compose ps

echo ""
echo "2. MySQL 连接测试:"
sleep 5
docker exec mysql-stage2 mysql -uroot -proot123 -e "SHOW DATABASES;" 2>/dev/null || echo "MySQL 连接失败"

echo ""
echo "3. Flink JobManager 状态:"
curl -s http://localhost:8081/ > /dev/null && echo "Flink JobManager 正常运行" || echo "Flink JobManager 连接失败"

echo ""
echo "4. Flink 集群概览:"
curl -s http://localhost:8081/overview 2>/dev/null | jq -r '.flink-version // "无法获取版本信息"' || echo "无法获取 Flink 集群信息"

echo ""
echo "=========================================="
echo "阶段2环境启动完成!"
echo "=========================================="
echo "访问地址:"
echo "- Flink Web UI: http://localhost:8081"
echo "- MySQL: localhost:3306"
echo ""
echo "下一步:"
echo "1. 运行 ./test.sh 验证 CDC 功能"
echo "2. 检查 Flink Web UI 中的任务管理器状态"
echo "3. 使用 ./cleanup.sh 清理环境"
echo "==========================================" 