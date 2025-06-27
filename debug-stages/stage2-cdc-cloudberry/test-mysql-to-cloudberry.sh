#!/bin/bash

# =============================================
# MySQL CDC → CloudBerry 测试脚本
# 作者：Vance Chen
# 功能：完整测试MySQL到CloudBerry的CDC数据流
# =============================================

set -e

# 颜色输出函数
print_success() { echo -e "\033[32m✅ $1\033[0m"; }
print_error() { echo -e "\033[31m❌ $1\033[0m"; }
print_info() { echo -e "\033[34mℹ️  $1\033[0m"; }
print_warning() { echo -e "\033[33m⚠️  $1\033[0m"; }

echo "=========================================="
print_info "MySQL CDC → CloudBerry 完整测试"
echo "=========================================="

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 步骤1: 下载依赖包
print_info "步骤1: 下载必要的依赖包..."
echo "----------------------------------------"
chmod +x "$SCRIPT_DIR/download-dependencies-1.20.sh"
if "$SCRIPT_DIR/download-dependencies-1.20.sh"; then
    print_success "依赖包下载完成"
else
    print_error "依赖包下载失败"
    exit 1
fi

# 步骤2: 启动服务
print_info "步骤2: 启动MySQL + Flink服务..."
echo "----------------------------------------"
cd "$SCRIPT_DIR"
if docker-compose up -d; then
    print_success "服务启动命令执行完成"
else
    print_error "服务启动失败"
    exit 1
fi

# 步骤3: 等待服务就绪
print_info "步骤3: 等待服务完全启动..."
echo "----------------------------------------"
echo "等待MySQL服务就绪..."
max_wait=60
wait_time=0
while [ $wait_time -lt $max_wait ]; do
    if docker exec mysql-stage2 mysqladmin ping -h localhost -u root -proot123 >/dev/null 2>&1; then
        print_success "MySQL服务已就绪"
        break
    fi
    echo "等待MySQL启动... ($wait_time/$max_wait 秒)"
    sleep 5
    wait_time=$((wait_time + 5))
done

if [ $wait_time -ge $max_wait ]; then
    print_error "MySQL服务启动超时"
    exit 1
fi

echo ""
echo "等待Flink JobManager就绪..."
wait_time=0
while [ $wait_time -lt $max_wait ]; do
    if curl -s -f http://localhost:8081/ >/dev/null 2>&1; then
        print_success "Flink JobManager已就绪"
        break
    fi
    echo "等待Flink启动... ($wait_time/$max_wait 秒)"
    sleep 5
    wait_time=$((wait_time + 5))
done

if [ $wait_time -ge $max_wait ]; then
    print_error "Flink服务启动超时"
    exit 1
fi

# 步骤4: 验证CloudBerry连接
print_info "步骤4: 验证CloudBerry数据库连接..."
echo "----------------------------------------"
echo "测试CloudBerry连接..."

# 尝试使用psql连接CloudBerry (如果可用)
if command -v psql >/dev/null 2>&1; then
    if PGPASSWORD=hashdata@123 psql -h 127.0.0.1 -p 15432 -U gpadmin -d gpadmin -c "SELECT version();" >/dev/null 2>&1; then
        print_success "CloudBerry连接测试成功"
    else
        print_warning "CloudBerry连接失败，请确保CloudBerry集群正在运行"
        print_info "请手动验证CloudBerry连接: psql -h 127.0.0.1 -p 15432 -U gpadmin -d gpadmin"
    fi
else
    print_warning "psql命令不可用，跳过CloudBerry连接测试"
    print_info "请确保CloudBerry集群在 127.0.0.1:15432 上运行"
fi

# 步骤5: 检查MySQL数据
print_info "步骤5: 检查MySQL源数据..."
echo "----------------------------------------"
sales_count=$(docker exec mysql-stage2 mysql -uroot -proot123 business_db -e "SELECT COUNT(*) as count FROM store_sales;" 2>/dev/null | tail -n 1)
returns_count=$(docker exec mysql-stage2 mysql -uroot -proot123 business_db -e "SELECT COUNT(*) as count FROM store_returns;" 2>/dev/null | tail -n 1)

print_info "MySQL数据统计:"
echo "  - store_sales: $sales_count 条记录"
echo "  - store_returns: $returns_count 条记录"

# 步骤6: 启动CDC作业
print_info "步骤6: 启动MySQL → CloudBerry CDC作业..."
echo "----------------------------------------"
echo "将CDC SQL脚本复制到Flink容器..."
docker cp "$SCRIPT_DIR/mysql-to-cloudberry-cdc.sql" flink-jobmanager-stage2:/tmp/mysql-to-cloudberry-cdc.sql

echo ""
print_info "启动Flink SQL作业 (后台运行)..."
docker exec -d flink-jobmanager-stage2 bash -c "
    cd /opt/flink/bin && 
    nohup ./sql-client.sh -f /tmp/mysql-to-cloudberry-cdc.sql > /tmp/cdc-job.log 2>&1 &
"

print_success "CDC作业已启动"

# 步骤7: 监控作业状态
print_info "步骤7: 监控作业状态..."
echo "----------------------------------------"
echo "等待10秒让作业启动..."
sleep 10

# 检查Flink作业状态
print_info "查看Flink Web UI中的作业状态:"
echo "  URL: http://localhost:8081"
echo ""

# 检查作业日志
print_info "查看CDC作业日志 (最近20行):"
echo "----------------------------------------"
docker exec flink-jobmanager-stage2 tail -20 /tmp/cdc-job.log 2>/dev/null || echo "日志暂时不可用"

echo ""
echo "=========================================="
print_success "测试准备完成！"
echo "=========================================="

echo ""
print_info "下一步操作建议:"
echo "1. 访问 Flink Web UI: http://localhost:8081"
echo "2. 检查作业运行状态和指标"
echo "3. 连接CloudBerry验证数据同步:"
echo "   psql -h 127.0.0.1 -p 15432 -U gpadmin -d gpadmin"
echo "   SELECT COUNT(*) FROM tpcds.store_sales_heap;"
echo "   SELECT COUNT(*) FROM tpcds.store_returns_heap;"
echo "4. 启动数据生成器观察实时同步:"
echo "   cd $PROJECT_ROOT && python scripts/data_generator.py"
echo ""

print_info "监控命令:"
echo "- 查看MySQL数据: docker exec mysql-stage2 mysql -uroot -proot123 business_db -e 'SELECT COUNT(*) FROM store_sales;'"
echo "- 查看Flink日志: docker exec flink-jobmanager-stage2 tail -f /tmp/cdc-job.log"
echo "- 停止测试: docker-compose down" 