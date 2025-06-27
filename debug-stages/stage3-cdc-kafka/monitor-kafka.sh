#!/bin/bash

# ===================================================================
# Kafka消息监控脚本
# 作者: Vance Chen
# ===================================================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}[INFO]${NC} Kafka消息监控工具"
echo "=================================================================="
echo "可用的Kafka主题监控选项:"
echo "1. sales-events (销售事件)"
echo "2. returns-events (退货事件)"  
echo "3. business-events (综合业务事件)"
echo "4. 查看所有主题"
echo "5. 全部主题并行监控"
echo "=================================================================="

read -p "请选择监控主题 [1-5]: " choice

case $choice in
    1)
        echo -e "${GREEN}[INFO]${NC} 监控销售事件主题 (Ctrl+C退出)..."
        docker exec kafka-stage3 kafka-console-consumer \
            --bootstrap-server localhost:9092 \
            --topic sales-events \
            --from-beginning \
            --property print.timestamp=true \
            --property print.key=true
        ;;
    2)
        echo -e "${GREEN}[INFO]${NC} 监控退货事件主题 (Ctrl+C退出)..."
        docker exec kafka-stage3 kafka-console-consumer \
            --bootstrap-server localhost:9092 \
            --topic returns-events \
            --from-beginning \
            --property print.timestamp=true \
            --property print.key=true
        ;;
    3)
        echo -e "${GREEN}[INFO]${NC} 监控综合业务事件主题 (Ctrl+C退出)..."
        docker exec kafka-stage3 kafka-console-consumer \
            --bootstrap-server localhost:9092 \
            --topic business-events \
            --from-beginning \
            --property print.timestamp=true \
            --property print.key=true
        ;;
    4)
        echo -e "${GREEN}[INFO]${NC} 查看所有Kafka主题:"
        docker exec kafka-stage3 kafka-topics \
            --bootstrap-server localhost:9092 \
            --list
        ;;
    5)
        echo -e "${GREEN}[INFO]${NC} 启动全部主题并行监控..."
        echo -e "${YELLOW}[提示]${NC} 将在后台启动多个监控进程，查看 monitor-*.log 文件"
        
        # 启动并行监控
        nohup docker exec kafka-stage3 kafka-console-consumer \
            --bootstrap-server localhost:9092 \
            --topic sales-events \
            --from-beginning \
            --property print.timestamp=true > monitor-sales.log 2>&1 &
            
        nohup docker exec kafka-stage3 kafka-console-consumer \
            --bootstrap-server localhost:9092 \
            --topic returns-events \
            --from-beginning \
            --property print.timestamp=true > monitor-returns.log 2>&1 &
            
        nohup docker exec kafka-stage3 kafka-console-consumer \
            --bootstrap-server localhost:9092 \
            --topic business-events \
            --from-beginning \
            --property print.timestamp=true > monitor-business.log 2>&1 &
            
        echo "并行监控已启动，日志文件:"
        echo "  📝 销售事件: monitor-sales.log"
        echo "  📝 退货事件: monitor-returns.log"
        echo "  📝 业务事件: monitor-business.log"
        echo ""
        echo "实时查看日志: tail -f monitor-*.log"
        ;;
    *)
        echo -e "${YELLOW}[WARNING]${NC} 无效选择，请重新运行脚本"
        ;;
esac 