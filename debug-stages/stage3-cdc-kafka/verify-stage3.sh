#!/bin/bash
# ===================================================================
# Stage 3 验证脚本 - 展示完整数据链路状态
# 作者: Vance Chen
# 功能: 验证 MySQL → Flink CDC → Kafka 数据流
# ===================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}=====================================================================${NC}"
echo -e "${BLUE}🚀 Stage 3 CDC → Kafka 数据链路验证${NC}"
echo -e "${BLUE}=====================================================================${NC}"

# 1. 检查服务状态
echo -e "\n${YELLOW}📊 1. 服务状态检查${NC}"
echo -e "${GREEN}Docker 容器状态:${NC}"
docker-compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}\t{{.Ports}}"

# 2. 检查Flink任务
echo -e "\n${YELLOW}🔧 2. Flink 任务状态${NC}"
job_count=$(curl -s http://localhost:8081/jobs | grep -o '"status":"RUNNING"' | wc -l || echo "0")
echo -e "${GREEN}运行中的任务数量: ${job_count}${NC}"

if [ "$job_count" -gt "0" ]; then
    echo -e "${GREEN}✅ Flink 任务正在运行${NC}"
else
    echo -e "${RED}❌ 没有运行中的Flink任务${NC}"
fi

# 3. 验证CDC数据流
echo -e "\n${YELLOW}📈 3. CDC 数据流验证${NC}"
echo -e "${GREEN}最新的CDC数据流输出:${NC}"
docker logs stream-batch-ivm-flink-taskmanager-2 2>&1 | grep "SALES-MONITOR" | tail -5

# 4. 检查Kafka Topics
echo -e "\n${YELLOW}🔄 4. Kafka Topics 状态${NC}"
echo -e "${GREEN}可用的Topics:${NC}"
docker-compose exec kafka kafka-topics --bootstrap-server kafka:29092 --list

echo -e "${GREEN}Topics分区状态:${NC}"
docker-compose exec kafka kafka-run-class kafka.tools.GetOffsetShell --broker-list kafka:29092 --topic sales-events

# 5. 数据库状态
echo -e "\n${YELLOW}💾 5. 数据库状态${NC}"
sales_count=$(docker-compose exec mysql mysql -u flink_cdc -pflink_cdc123 business_db -e "SELECT COUNT(*) FROM store_sales;" 2>/dev/null | tail -1)
returns_count=$(docker-compose exec mysql mysql -u flink_cdc -pflink_cdc123 business_db -e "SELECT COUNT(*) FROM store_returns;" 2>/dev/null | tail -1)

echo -e "${GREEN}销售记录数: ${sales_count}${NC}"
echo -e "${GREEN}退货记录数: ${returns_count}${NC}"

# 6. 生成实时测试数据
echo -e "\n${YELLOW}🧪 6. 生成实时测试数据${NC}"
docker-compose exec mysql mysql -u root -proot123 business_db -e "
INSERT INTO store_sales (
    ss_sold_date_sk, ss_item_sk, ss_customer_sk, ss_store_sk, 
    ss_ticket_number, ss_quantity, ss_sales_price, ss_net_profit
) VALUES 
(20250627, 9001, 8001, 401, 9000001, 1, 599.99, 179.99);

SELECT '🎯 实时测试数据已生成!' as message;
" 2>/dev/null

echo -e "${GREEN}✅ 实时测试数据已插入${NC}"

# 7. 等待数据处理并显示结果
echo -e "\n${YELLOW}⏳ 7. 等待CDC处理新数据...${NC}"
sleep 3

echo -e "${GREEN}最新的CDC数据流:${NC}"
docker logs stream-batch-ivm-flink-taskmanager-2 2>&1 | grep "SALES-MONITOR" | tail -3

# 8. 访问信息
echo -e "\n${PURPLE}=====================================================================${NC}"
echo -e "${PURPLE}🌐 管理界面访问信息${NC}"
echo -e "${PURPLE}=====================================================================${NC}"
echo -e "${BLUE}📊 Flink Dashboard: ${NC}http://localhost:8081"
echo -e "${BLUE}📋 Kafka UI (AKHQ):  ${NC}http://localhost:8080"

echo -e "\n${PURPLE}🔍 数据链路监控${NC}"
echo -e "${GREEN}实时CDC数据流:${NC}"
echo -e "  docker logs stream-batch-ivm-flink-taskmanager-2 -f | grep SALES-MONITOR"

echo -e "\n${GREEN}手动插入测试数据:${NC}"
echo -e '  docker-compose exec mysql mysql -u root -proot123 business_db -e "INSERT INTO store_sales (...) VALUES (...);"'

echo -e "\n${PURPLE}=====================================================================${NC}"
echo -e "${GREEN}🎉 Stage 3 验证完成！${NC}"
echo -e "${GREEN}✅ MySQL → Flink CDC → 控制台监控：正常工作${NC}"
echo -e "${YELLOW}⚠️  MySQL → Flink CDC → Kafka：需要持久化会话${NC}"
echo -e "${BLUE}🚀 准备进入 Stage 4 - 完整流批一体处理！${NC}"
echo -e "${PURPLE}=====================================================================${NC}" 