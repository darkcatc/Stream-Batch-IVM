#!/bin/bash

# =============================================
# 优化的 CDC 同步架构启动脚本
# 作者：Vance Chen
# 功能：按业务域拆分的 Flink CDC 同步作业
# 架构：单源多sink合并，避免重复CDC连接
# =============================================

set -e

echo "🚀 启动优化的 CDC 数据同步架构..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查环境
check_environment() {
    log_step "检查环境状态..."
    
    # 检查 Docker 容器状态
    if ! docker ps --filter "name=flink-jobmanager" --filter "status=running" --quiet | grep -q .; then
        log_error "Flink JobManager 未运行，请先执行 ./start-demo.sh"
        exit 1
    fi
    
    if ! docker ps --filter "name=mysql" --filter "status=running" --quiet | grep -q .; then
        log_error "MySQL 未运行，请先执行 ./start-demo.sh"
        exit 1
    fi
    
    if ! docker ps --filter "name=kafka" --filter "status=running" --quiet | grep -q .; then
        log_error "Kafka 未运行，请先执行 ./start-demo.sh"
        exit 1
    fi
    
    log_info "环境检查通过 ✅"
}

# 等待服务就绪
wait_for_services() {
    log_step "等待服务就绪..."
    
    # 等待 Flink
    max_attempts=30
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8081/overview &>/dev/null; then
            log_info "Flink 已就绪 ✅"
            break
        fi
        
        log_info "等待 Flink... (尝试 $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
        
        if [ $attempt -gt $max_attempts ]; then
            log_error "Flink 启动超时"
            exit 1
        fi
    done
    
    # 等待 MySQL CDC 用户就绪
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker exec mysql mysql -uflink_cdc -pflink_cdc123 -e "SELECT 1" &>/dev/null; then
            log_info "MySQL CDC 用户已就绪 ✅"
            break
        fi
        
        log_info "等待 MySQL CDC 用户... (尝试 $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
        
        if [ $attempt -gt $max_attempts ]; then
            log_error "MySQL CDC 用户配置超时"
            exit 1
        fi
    done
}

# 复制 SQL 文件到容器
copy_sql_files() {
    log_step "复制 SQL 文件到 Flink 容器..."
    
    # 创建容器内目录
    docker exec flink-jobmanager mkdir -p /opt/flink/sql
    
    # 复制优化后的 SQL 文件
    docker cp flink-sql/01-sales-cdc-sync.sql flink-jobmanager:/opt/flink/sql/
    docker cp flink-sql/02-returns-cdc-sync.sql flink-jobmanager:/opt/flink/sql/
    
    log_info "SQL 文件复制完成 ✅"
}

# 提交 Sales 同步作业
submit_sales_job() {
    log_step "提交 Sales 数据同步作业..."
    
    # 提交作业
    docker exec flink-jobmanager /opt/flink/bin/sql-client.sh \
        -f /opt/flink/sql/01-sales-cdc-sync.sql &
    
    sales_job_pid=$!
    
    # 等待作业启动
    sleep 10
    
    # 检查作业状态
    if docker exec flink-jobmanager /opt/flink/bin/flink list 2>/dev/null | grep -q "RUNNING"; then
        log_info "Sales 同步作业提交成功 ✅"
    else
        log_warn "Sales 同步作业可能需要更多时间启动"
    fi
}

# 提交 Returns 同步作业  
submit_returns_job() {
    log_step "提交 Returns 数据同步作业..."
    
    # 提交作业
    docker exec flink-jobmanager /opt/flink/bin/sql-client.sh \
        -f /opt/flink/sql/02-returns-cdc-sync.sql &
    
    returns_job_pid=$!
    
    # 等待作业启动
    sleep 10
    
    # 检查作业状态
    if docker exec flink-jobmanager /opt/flink/bin/flink list 2>/dev/null | grep -q "RUNNING"; then
        log_info "Returns 同步作业提交成功 ✅"
    else
        log_warn "Returns 同步作业可能需要更多时间启动"
    fi
}

# 验证作业状态
verify_jobs() {
    log_step "验证作业运行状态..."
    
    sleep 20  # 等待作业完全启动
    
    # 获取作业列表
    jobs=$(docker exec flink-jobmanager /opt/flink/bin/flink list 2>/dev/null || echo "")
    
    if echo "$jobs" | grep -q "RUNNING"; then
        running_count=$(echo "$jobs" | grep -c "RUNNING" || echo "0")
        log_info "发现 $running_count 个运行中的作业 ✅"
        
        echo ""
        echo -e "${BLUE}📋 运行中的作业：${NC}"
        echo "$jobs" | grep "RUNNING" || echo "无运行中的作业"
    else
        log_warn "暂未发现运行中的作业，请检查作业日志"
    fi
    
    echo ""
    echo -e "${BLUE}📊 Flink Dashboard: ${NC}http://localhost:8081"
}

# 检查数据流
check_data_flow() {
    log_step "检查数据流状态..."
    
    # 检查 Kafka Topics
    log_info "检查 Kafka Topics..."
    topics=$(docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null || echo "")
    
    if echo "$topics" | grep -q "tpcds.store_sales"; then
        log_info "✅ tpcds.store_sales Topic 已创建"
    else
        log_warn "⚠️ tpcds.store_sales Topic 未发现"
    fi
    
    if echo "$topics" | grep -q "tpcds.store_returns"; then
        log_info "✅ tpcds.store_returns Topic 已创建"
    else
        log_warn "⚠️ tpcds.store_returns Topic 未发现"
    fi
    
    echo ""
    echo -e "${BLUE}📡 AKHQ (Kafka UI): ${NC}http://localhost:8080"
}

# 显示使用指南
show_usage_guide() {
    log_step "显示使用指南..."
    
    echo ""
    echo -e "${GREEN}🎉 优化的 CDC 同步架构启动完成！${NC}"
    echo ""
    echo -e "${BLUE}📋 架构特点：${NC}"
    echo "  • 按业务域拆分：Sales 和 Returns 独立作业"
    echo "  • 单源多sink：每个作业同时写入 Kafka 和 Cloudberry"
    echo "  • 避免重复连接：每个 MySQL 表只有一个 CDC 连接"
    echo "  • 独立管理：作业故障互不影响"
    echo ""
    echo -e "${BLUE}📊 监控地址：${NC}"
    echo "  • Flink Dashboard:  http://localhost:8081"
    echo "  • AKHQ (Kafka UI):  http://localhost:8080"
    echo "  • Schema Registry:  http://localhost:8082"
    echo ""
    echo -e "${BLUE}🔧 手动操作：${NC}"
    echo "  # 查看作业状态"
    echo "  docker exec flink-jobmanager /opt/flink/bin/flink list"
    echo ""
    echo "  # 进入 Flink SQL Client"
    echo "  docker exec -it flink-jobmanager ./bin/sql-client.sh"
    echo ""
    echo "  # 查看 Kafka Topics 数据"
    echo "  docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic tpcds.store_sales --from-beginning"
    echo ""
    echo -e "${YELLOW}💡 提示：${NC}"
    echo "  • 启动数据生成器开始产生测试数据：python3 scripts/data-generator.py"
    echo "  • 使用 Ctrl+C 停止脚本监控，但不会停止 Flink 作业"
    echo "  • 要停止所有服务：docker-compose down"
}

# 监控模式
monitor_jobs() {
    log_step "进入监控模式（按 Ctrl+C 退出监控）..."
    
    # 捕获 Ctrl+C 信号
    trap 'log_info "退出监控模式..."; exit 0' INT
    
    while true; do
        # 每30秒检查一次作业状态
        sleep 30
        
        jobs=$(docker exec flink-jobmanager /opt/flink/bin/flink list 2>/dev/null || echo "")
        running_count=$(echo "$jobs" | grep -c "RUNNING" || echo "0")
        
        current_time=$(date '+%H:%M:%S')
        log_info "[$current_time] 运行中的作业数: $running_count"
        
        # 检查是否有失败的作业
        if echo "$jobs" | grep -q "FAILED"; then
            log_warn "发现失败的作业！"
            echo "$jobs" | grep "FAILED"
        fi
    done
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "  优化的 CDC 数据同步架构"
    echo "  按业务域拆分 + 单源多sink合并"
    echo "  作者：Vance Chen"
    echo "========================================"
    echo -e "${NC}"
    
    check_environment
    wait_for_services
    copy_sql_files
    
    # 并行提交作业
    submit_sales_job
    submit_returns_job
    
    verify_jobs
    check_data_flow
    show_usage_guide
    
    # 进入监控模式
    monitor_jobs
}

# 执行主函数
main "$@" 