#!/bin/bash

# =============================================
# TPC-DS 流批一体处理 Demo 启动脚本
# 作者：Vance Chen
# 基于 Flink CDC + Cloudberry 架构
# =============================================

set -e

echo "🚀 启动 TPC-DS 流批一体处理演示环境..."

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

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    log_info "依赖检查完成 ✅"
}

# 准备 Flink 依赖
prepare_flink_libs() {
    log_info "准备 Flink CDC 连接器..."
    
    mkdir -p ./flink-lib
    
    # 检查是否已存在必要的 JAR 文件
    if [ ! -f "./flink-lib/flink-sql-connector-mysql-cdc-2.4.2.jar" ]; then
        log_warn "未找到 MySQL CDC 连接器，请手动下载："
        echo "  wget -O ./flink-lib/flink-sql-connector-mysql-cdc-2.4.2.jar https://repo1.maven.org/maven2/com/ververica/flink-sql-connector-mysql-cdc/2.4.2/flink-sql-connector-mysql-cdc-2.4.2.jar"
    fi
    
    if [ ! -f "./flink-lib/flink-sql-connector-kafka-1.18.0.jar" ]; then
        log_warn "未找到 Kafka 连接器，请手动下载："
        echo "  wget -O ./flink-lib/flink-sql-connector-kafka-1.18.0.jar https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.18.0/flink-sql-connector-kafka-1.18.0.jar"
    fi
    
    if [ ! -f "./flink-lib/mysql-connector-java-8.0.33.jar" ]; then
        log_warn "未找到 MySQL JDBC 驱动，请手动下载："
        echo "  wget -O ./flink-lib/mysql-connector-java-8.0.33.jar https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.33/mysql-connector-java-8.0.33.jar"
    fi
    
    if [ ! -f "./flink-lib/postgresql-42.6.0.jar" ]; then
        log_warn "未找到 PostgreSQL JDBC 驱动（用于连接 Cloudberry），请手动下载："
        echo "  wget -O ./flink-lib/postgresql-42.6.0.jar https://repo1.maven.org/maven2/org/postgresql/postgresql/42.6.0/postgresql-42.6.0.jar"
    fi
}

# 启动 Docker 服务
start_services() {
    log_info "启动 Docker 服务..."
    
    # 清理可能存在的旧容器
    log_info "清理旧容器..."
    docker-compose down -v 2>/dev/null || true
    
    # 启动所有服务
    log_info "启动服务栈..."
    docker-compose up -d
    
    log_info "等待服务初始化..."
    sleep 30
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    # 检查各个服务的健康状态
    services=("zookeeper" "kafka" "mysql" "flink-jobmanager" "flink-taskmanager" "akhq" "schema-registry")
    
    for service in "${services[@]}"; do
        if docker ps --filter "name=${service}" --filter "status=running" --quiet | grep -q .; then
            log_info "${service} 运行正常 ✅"
        else
            log_warn "${service} 可能存在问题 ⚠️"
        fi
    done
}

# 等待 MySQL 就绪
wait_for_mysql() {
    log_info "等待 MySQL 就绪..."
    
    max_attempts=30
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec mysql mysql -uroot -proot123 -e "SELECT 1" &>/dev/null; then
            log_info "MySQL 已就绪 ✅"
            return 0
        fi
        
        log_info "等待 MySQL... (尝试 $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    log_error "MySQL 启动失败"
    return 1
}

# 等待 Flink 就绪
wait_for_flink() {
    log_info "等待 Flink 就绪..."
    
    max_attempts=30
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8081/overview &>/dev/null; then
            log_info "Flink 已就绪 ✅"
            return 0
        fi
        
        log_info "等待 Flink... (尝试 $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    log_error "Flink 启动失败"
    return 1
}

# 创建 Kafka Topics
create_kafka_topics() {
    log_info "创建 Kafka Topics..."
    
    # 等待 Kafka 就绪
    sleep 10
    
    topics=("tpcds.store_sales" "tpcds.store_returns" "tpcds.sales_metrics" "tpcds.return_metrics" "tpcds.alerts" "tpcds.item_trends")
    
    for topic in "${topics[@]}"; do
        docker exec kafka kafka-topics --create --bootstrap-server localhost:9092 --topic "$topic" --partitions 3 --replication-factor 1 --if-not-exists 2>/dev/null || true
        log_info "Topic $topic 已创建 ✅"
    done
}

# 显示访问信息
show_access_info() {
    log_info "环境启动完成！以下是各服务的访问信息："
    
    echo ""
    echo -e "${BLUE}📊 服务访问地址：${NC}"
    echo "  • AKHQ (Kafka UI):     http://localhost:8080"
    echo "  • Flink Dashboard:     http://localhost:8081"
    echo "  • Schema Registry:     http://localhost:8082"
    echo ""
    echo -e "${BLUE}🗄️ 数据库连接信息：${NC}"
    echo "  • MySQL Host:          localhost:3306"
    echo "  • Database:            business_db"
    echo "  • Username:            root / flink_cdc"
    echo "  • Password:            root123 / flink_cdc123"
    echo ""
    echo -e "${BLUE}📡 Kafka 信息：${NC}"
    echo "  • Bootstrap Servers:   localhost:9092"
    echo "  • TPC-DS Topics:"
    echo "    - tpcds.store_sales        (源数据)"
    echo "    - tpcds.store_returns      (源数据)"
    echo "    - tpcds.sales_metrics      (实时统计)"
    echo "    - tpcds.return_metrics     (退货分析)"
    echo "    - tpcds.alerts             (实时告警)"
    echo "    - tpcds.item_trends        (商品趋势)"
    echo ""
    echo -e "${BLUE}🔧 Flink CDC 配置：${NC}"
    echo "  • SQL 脚本目录: ./flink-sql/"
    echo "  • MySQL → Kafka:    mysql-cdc-to-kafka.sql"
    echo "  • MySQL → Cloudberry: mysql-cdc-to-cloudberry.sql"
    echo "  • 流式分析:         streaming-analytics.sql"
    echo ""
    echo -e "${BLUE}🔧 数据生成器：${NC}"
    echo "  • 安装依赖: pip install -r requirements.txt"
    echo "  • 启动命令: python3 scripts/data-generator.py"
    echo ""
    echo -e "${GREEN}✨ 快速验证：${NC}"
    echo "  1. 访问 Flink Dashboard: http://localhost:8081"
    echo "  2. 执行 Flink SQL 脚本："
    echo "     • 在 Flink SQL Client 中执行 CDC 同步任务"
    echo "     • 或使用 Flink Web UI 提交作业"
    echo "  3. 启动数据生成器模拟实时数据"
    echo "  4. 在 AKHQ 中观察 Topic 数据变化: http://localhost:8080"
    echo "  5. 查看流式分析结果和实时告警"
    echo ""
    echo -e "${YELLOW}📝 操作步骤：${NC}"
    echo "  # 1. 进入 Flink SQL Client"
    echo "  docker exec -it flink-jobmanager ./bin/sql-client.sh"
    echo ""
    echo "  # 2. 在 SQL Client 中执行："
    echo "  Flink SQL> SOURCE './flink-sql/mysql-cdc-to-kafka.sql';"
    echo "  Flink SQL> SOURCE './flink-sql/streaming-analytics.sql';"
    echo ""
    echo "  # 3. 启动数据生成器（另一个终端）"
    echo "  python3 scripts/data-generator.py"
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "  TPC-DS 流批一体处理演示环境"
    echo "  基于 Flink CDC + Cloudberry 架构"
    echo "  作者：Vance Chen"
    echo "========================================"
    echo -e "${NC}"
    
    check_dependencies
    prepare_flink_libs
    start_services
    
    if wait_for_mysql && wait_for_flink; then
        check_services
        create_kafka_topics
        show_access_info
        
        log_info "环境启动完成！按 Ctrl+C 停止所有服务"
        
        # 捕获 Ctrl+C 信号，优雅关闭
        trap 'log_info "正在停止服务..."; docker-compose down; exit 0' INT
        
        # 保持脚本运行
        while true; do
            sleep 1
        done
    else
        log_error "环境启动失败"
        exit 1
    fi
}

# 执行主函数
main "$@" 