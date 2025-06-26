#!/bin/bash

# ===================================
# 阶段 1: MySQL 基础环境启动脚本
# 作者：Vance Chen
# ===================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查是否在正确的目录
check_directory() {
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "未找到 docker-compose.yml 文件"
        log_info "请确保在 debug-stages/stage1-mysql 目录下运行此脚本"
        exit 1
    fi
    
    if [[ ! -f "../../.env" ]]; then
        log_error "未找到项目根目录的 .env 配置文件"
        log_info "请确保在项目根目录下有 .env 文件"
        exit 1
    fi
}

# 清理已存在的容器
cleanup_existing() {
    log_info "清理已存在的阶段1容器..."
    
    # 停止并删除容器
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # 删除可能存在的其他阶段容器
    docker rm -f mysql-stage1 2>/dev/null || true
    
    # 清理网络
    docker network rm stream-batch-network-stage1 2>/dev/null || true
    
    log_success "清理完成"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用情况..."
    
    local mysql_port=$(grep MYSQL_EXTERNAL_PORT ../../.env | cut -d'=' -f2 | tr -d '"' || echo "3306")
    
    if netstat -tlnp 2>/dev/null | grep ":${mysql_port} " > /dev/null; then
        log_warning "端口 ${mysql_port} 已被占用"
        log_info "如果是其他 MySQL 实例，请先停止或修改配置"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 启动 MySQL 服务
start_mysql() {
    log_info "启动 MySQL 服务..."
    
    # 复制环境配置
    cp ../../.env .env
    
    # 启动服务
    docker-compose up -d
    
    if [[ $? -eq 0 ]]; then
        log_success "MySQL 容器启动成功"
    else
        log_error "MySQL 容器启动失败"
        exit 1
    fi
}

# 等待 MySQL 就绪
wait_for_mysql() {
    log_info "等待 MySQL 服务就绪..."
    
    local max_attempts=60
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker exec mysql-stage1 mysqladmin ping -h localhost -u root -proot123 >/dev/null 2>&1; then
            log_success "MySQL 服务已就绪"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "MySQL 服务启动超时"
    docker logs mysql-stage1
    exit 1
}

# 验证数据库初始化
verify_database() {
    log_info "验证数据库初始化..."
    
    # 检查数据库是否创建
    local db_check=$(docker exec mysql-stage1 mysql -u root -proot123 -e "SHOW DATABASES LIKE 'business_db';" --skip-column-names 2>/dev/null)
    
    if [[ -n "$db_check" ]]; then
        log_success "业务数据库创建成功"
    else
        log_error "业务数据库未创建"
        return 1
    fi
    
    # 检查表是否创建
    local table_check=$(docker exec mysql-stage1 mysql -u root -proot123 business_db -e "SHOW TABLES;" --skip-column-names 2>/dev/null | wc -l)
    
    if [[ $table_check -gt 0 ]]; then
        log_success "数据表创建成功，共 $table_check 个表"
    else
        log_warning "未发现数据表，可能初始化脚本未执行"
        return 1
    fi
    
    # 检查 CDC 用户
    local user_check=$(docker exec mysql-stage1 mysql -u root -proot123 -e "SELECT User FROM mysql.user WHERE User='flink_cdc';" --skip-column-names 2>/dev/null)
    
    if [[ -n "$user_check" ]]; then
        log_success "CDC 用户创建成功"
    else
        log_warning "CDC 用户未创建"
        return 1
    fi
    
    return 0
}

# 显示服务状态
show_status() {
    echo
    log_info "======== 阶段 1 服务状态 ========"
    
    # 容器状态
    echo -e "${BLUE}容器状态:${NC}"
    docker ps --filter "name=mysql-stage1" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # 网络状态
    echo -e "\n${BLUE}网络状态:${NC}"
    docker network ls --filter "name=stage1"
    
    # 卷状态
    echo -e "\n${BLUE}数据卷:${NC}"
    docker volume ls --filter "name=mysql-data-stage1"
    
    # 日志最后几行
    echo -e "\n${BLUE}MySQL 日志 (最后10行):${NC}"
    docker logs mysql-stage1 --tail 10
}

# 显示下一步操作
show_next_steps() {
    echo
    log_success "==============================================="
    log_success "阶段 1: MySQL 基础环境启动完成！"
    log_success "==============================================="
    echo
    echo -e "${GREEN}✅ 完成项目:${NC}"
    echo "  • MySQL 8.0 容器运行正常"
    echo "  • 业务数据库和表结构初始化"
    echo "  • CDC 用户权限配置完成"
    echo "  • binlog 配置启用"
    echo
    echo -e "${BLUE}🔧 下一步操作:${NC}"
    echo "  1. 运行测试脚本："
    echo "     ./test.sh"
    echo
    echo "  2. 启动数据生成器："
    echo "     cd ../.."
    echo "     source venv/bin/activate"
    echo "     python scripts/data-generator.py"
    echo
    echo "  3. 进入下一阶段："
    echo "     cd ../stage2-cdc-cloudberry"
    echo
    echo -e "${YELLOW}💡 监控命令:${NC}"
    echo "  • 查看容器状态: docker ps"
    echo "  • 查看 MySQL 日志: docker logs mysql-stage1"
    echo "  • 连接 MySQL: docker exec -it mysql-stage1 mysql -u root -proot123"
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "  阶段 1: MySQL 基础环境启动"
    echo "  作者：Vance Chen"
    echo "========================================"
    echo -e "${NC}"
    
    check_directory
    cleanup_existing
    check_ports
    start_mysql
    wait_for_mysql
    
    if verify_database; then
        show_status
        show_next_steps
    else
        log_error "数据库验证失败，请检查初始化脚本"
        docker logs mysql-stage1
        exit 1
    fi
}

# 执行主函数
main "$@" 