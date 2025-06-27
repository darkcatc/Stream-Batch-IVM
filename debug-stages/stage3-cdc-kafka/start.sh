#!/bin/bash

# ===================================================================
# Stage 3: MySQL CDC 到 Kafka 数据流启动脚本
# 作者: Vance Chen
# 功能: 启动完整的 MySQL → Flink CDC → Kafka 数据管道
# ===================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Stage 3: 启动MySQL CDC到Kafka数据流"
echo "=========================================="

# 1. 检查必要文件
echo "📋 检查必要文件..."
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ 错误: docker-compose.yml 文件未找到"
    exit 1
fi

if [ ! -f "cdc-to-kafka.sql" ]; then
    echo "❌ 错误: cdc-to-kafka.sql 文件未找到"
    exit 1
fi

# 2. 启动基础设施
echo "🐳 启动Docker容器..."
docker-compose up -d

# 3. 等待服务就绪
echo "⏳ 等待服务启动..."
sleep 30

echo "📊 检查服务状态..."
docker-compose ps

# 4. 检查Kafka连接器
echo "🔧 验证Kafka连接器..."
KAFKA_CONNECTOR_SIZE=$(docker exec flink-jobmanager-stage3 ls -la /opt/flink/lib/flink-sql-connector-kafka*.jar 2>/dev/null | awk '{print $5}' || echo "0")
if [ "$KAFKA_CONNECTOR_SIZE" -gt 1000000 ]; then
    echo "✅ Kafka连接器正常 (${KAFKA_CONNECTOR_SIZE} bytes)"
else
    echo "❌ Kafka连接器异常，请检查flink-lib目录"
    exit 1
fi

# 5. 启动CDC到Kafka作业
echo "🔄 启动CDC到Kafka数据流作业..."
docker cp cdc-to-kafka.sql flink-jobmanager-stage3:/tmp/
docker-compose exec -d flink-jobmanager bash -c "nohup /opt/flink/bin/sql-client.sh -f /tmp/cdc-to-kafka.sql > /tmp/cdc-kafka.log 2>&1 &"

# 6. 等待作业启动
echo "⏳ 等待作业启动..."
sleep 15

# 7. 验证作业状态
echo "📈 验证Flink作业状态..."
JOBS_COUNT=$(curl -s http://localhost:8081/jobs | grep -o '"status":"RUNNING"' | wc -l)
echo "运行中的作业数量: $JOBS_COUNT"

if [ "$JOBS_COUNT" -gt 0 ]; then
    echo "✅ Flink作业启动成功"
else
    echo "⚠️  Flink作业可能未启动，请检查日志"
fi

# 8. 测试Kafka数据
echo "🔍 测试Kafka数据流..."
timeout 5 docker-compose exec kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic sales-events \
    --from-beginning \
    --max-messages 1 > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Kafka数据流正常"
else
    echo "⚠️  Kafka中暂无数据，可能需要触发CDC事件"
fi

echo ""
echo "🎉 Stage 3 启动完成！"
echo "=========================================="
echo "📊 访问地址:"
echo "   • Flink Dashboard: http://localhost:8081"
echo "   • Kafka UI (AKHQ):  http://localhost:8080"
echo "   • MySQL:            localhost:3306 (flink_cdc/flink_cdc123)"
echo ""
echo "🔧 管理命令:"
echo "   • 监控Kafka: ./monitor-kafka.sh"
echo "   • 验证状态: ./verify-stage3.sh"
echo "   • 停止服务: docker-compose down"
echo "" 