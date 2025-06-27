#!/bin/bash

# ===================================================================
# Stream-Batch-IVM CDC 演示启动脚本
# 作者: Vance Chen
# 版本: 集成阶段2调试成功的配置  
# 适配: Flink 1.20.1 + CDC 3.4.0 + MySQL 8.0
# ===================================================================

set -e

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=================================================================="
echo "         Stream-Batch-IVM CDC 演示系统启动"
echo "=================================================================="
echo "版本信息:"
echo "  - Flink: 1.20.1"  
echo "  - CDC Connector: 3.4.0"
echo "  - MySQL: 8.0"
echo "=================================================================="

# 检查环境文件
if [ ! -f ".env" ]; then
    log_error ".env 文件不存在，请先运行 setup-env.sh"
    exit 1
fi

# 加载环境变量
source .env

log_info "1. 检查并下载依赖包..."
if [ ! -f "flink-lib/flink-sql-connector-mysql-cdc-3.4.0.jar" ] || 
   [ ! -f "flink-lib/mysql-connector-j-8.0.33.jar" ]; then
    log_warning "缺少必要的依赖包，启动下载进程..."
    docker-compose up flink-cdc-init --remove-orphans
    docker-compose rm -f flink-cdc-init
fi

log_info "2. 启动核心服务 (MySQL + Flink)..."
docker-compose up -d mysql flink-jobmanager flink-taskmanager

log_info "3. 等待服务启动完成..."
echo "   - 等待MySQL启动 (30秒)..."
sleep 30

echo "   - 等待Flink集群启动 (20秒)..."
sleep 20

# 健康检查
log_info "4. 执行健康检查..."

# 检查MySQL
log_info "   检查MySQL连接..."
if docker exec mysql mysqladmin ping -h localhost -u root -proot123 >/dev/null 2>&1; then
    log_success "   ✅ MySQL服务正常"
else
    log_error "   ❌ MySQL服务异常"
    exit 1
fi

# 检查Flink
log_info "   检查Flink集群..."
if curl -s http://localhost:8081 >/dev/null 2>&1; then
    log_success "   ✅ Flink集群正常"
    
    # 获取TaskManager信息
    TASK_MANAGERS=$(curl -s http://localhost:8081/taskmanagers | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'TaskManagers: {len(data[\"taskmanagers\"])}, 总slots: {sum(tm[\"slotsNumber\"] for tm in data[\"taskmanagers\"])}')
" 2>/dev/null || echo "信息获取失败")
    log_info "   Flink状态: $TASK_MANAGERS"
else
    log_error "   ❌ Flink集群异常"
    exit 1
fi

log_info "5. 创建CDC表结构..."
docker cp flink-sql/cdc-table-definitions.sql flink-jobmanager:/tmp/
docker exec flink-jobmanager /opt/flink/bin/sql-client.sh -f /tmp/cdc-table-definitions.sql

log_success "6. 系统启动完成!"
echo ""
echo "=================================================================="
echo "                    🎉 系统就绪 🎉"
echo "=================================================================="
echo "Flink Web UI: http://localhost:8081"
echo "MySQL连接: localhost:3306 (用户: root, 密码: root123)"
echo ""
echo "下一步操作:"
echo "1. 启动数据生成器:"
echo "   cd scripts && python3 data_generator.py"
echo ""
echo "2. 启动CDC监控任务:"  
echo "   docker cp flink-sql/cdc-monitoring-jobs.sql flink-jobmanager:/tmp/"
echo "   docker exec flink-jobmanager /opt/flink/bin/sql-client.sh -f /tmp/cdc-monitoring-jobs.sql"
echo ""
echo "3. 查看实时数据流:"
echo "   docker logs flink-taskmanager-1 -f"
echo "==================================================================" 