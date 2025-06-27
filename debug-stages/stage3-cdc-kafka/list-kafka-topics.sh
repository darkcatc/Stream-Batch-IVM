#!/bin/bash

# ===================================================================
# Kafka主题信息查看脚本
# 作者: Vance Chen
# ===================================================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}[INFO]${NC} Kafka主题信息"
echo "=================================================================="

# 列出所有主题
echo -e "${GREEN}📋 所有Kafka主题:${NC}"
docker exec kafka-stage3 kafka-topics \
    --bootstrap-server localhost:9092 \
    --list

echo ""
echo "=================================================================="

# 获取主题详细信息
TOPICS=(sales-events returns-events business-events)

for topic in "${TOPICS[@]}"; do
    echo -e "${GREEN}📊 主题详细信息: $topic${NC}"
    docker exec kafka-stage3 kafka-topics \
        --bootstrap-server localhost:9092 \
        --describe \
        --topic "$topic" 2>/dev/null || echo "主题 $topic 不存在或未创建"
    echo ""
done

echo "=================================================================="
echo -e "${BLUE}💡 提示:${NC}"
echo "- 主题会在第一次发送消息时自动创建"
echo "- 如果主题不存在，启动CDC任务后会自动创建"
echo "- 使用 ./monitor-kafka.sh 监控消息流" 