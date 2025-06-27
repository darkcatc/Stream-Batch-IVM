#!/bin/bash

# =============================================
# Stage2 启动脚本 - MySQL CDC to CloudBerry
# 作者：Vance Chen
# =============================================

set -e

echo "=========================================="
echo "🚀 启动 Stage2: MySQL CDC → CloudBerry"
echo "=========================================="

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 步骤1: 下载依赖
echo "📦 下载Flink连接器依赖..."
chmod +x "$SCRIPT_DIR/download-dependencies-1.20.sh"
"$SCRIPT_DIR/download-dependencies-1.20.sh"

echo ""

# 步骤2: 启动服务
echo "🛠️  启动Docker服务..."
cd "$SCRIPT_DIR"
docker-compose up -d

echo ""
echo "⏳ 等待服务启动..."
sleep 15

# 步骤3: 验证服务状态
echo "🔍 验证服务状态..."

# 检查MySQL
if docker exec mysql-stage2 mysqladmin ping -h localhost -u root -proot123 >/dev/null 2>&1; then
    echo "✅ MySQL服务正常"
else
    echo "❌ MySQL服务异常"
fi

# 检查Flink
if curl -s -f http://localhost:8081/ >/dev/null 2>&1; then
    echo "✅ Flink JobManager正常"
else
    echo "❌ Flink JobManager异常"
fi

echo ""
echo "=========================================="
echo "🎉 Stage2 启动完成！"
echo "=========================================="

echo ""
echo "📋 下一步操作："
echo "1. 运行完整测试："
echo "   ./test-mysql-to-cloudberry.sh"
echo ""
echo "2. 手动启动CDC作业："
echo "   docker cp mysql-to-cloudberry-cdc.sql flink-jobmanager-stage2:/tmp/"
echo "   docker exec flink-jobmanager-stage2 /opt/flink/bin/sql-client.sh -f /tmp/mysql-to-cloudberry-cdc.sql"
echo ""
echo "3. 验证CloudBerry同步："
echo "   psql -h 127.0.0.1 -p 15432 -U gpadmin -d gpadmin -f verify-cloudberry-sync.sql"
echo ""
echo "4. 访问监控界面："
echo "   Flink Web UI: http://localhost:8081"
echo ""
echo "5. 停止服务："
echo "   docker-compose down" 