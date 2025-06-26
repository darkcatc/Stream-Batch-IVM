#!/bin/bash

# ===================================
# 阶段 1: 清理脚本
# 作者：Vance Chen
# ===================================

# 颜色定义
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

# 主清理函数
cleanup_stage1() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "  阶段 1: 环境清理"
    echo "  作者：Vance Chen"
    echo "========================================"
    echo -e "${NC}"
    
    log_info "开始清理阶段 1 环境..."
    
    # 停止并删除容器
    log_info "停止并删除容器..."
    docker-compose down --remove-orphans 2>/dev/null || true
    docker rm -f mysql-stage1 2>/dev/null || true
    
    # 清理网络
    log_info "清理网络..."
    docker network rm stream-batch-network-stage1 2>/dev/null || true
    
    # 是否清理数据卷
    echo
    log_warning "是否删除数据卷？这将删除所有 MySQL 数据！"
    read -p "删除数据卷？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "删除数据卷..."
        docker volume rm mysql-data-stage1 2>/dev/null || true
        log_success "数据卷已删除"
    else
        log_info "保留数据卷"
    fi
    
    # 清理配置文件
    log_info "清理本地配置文件..."
    rm -f .env 2>/dev/null || true
    
    # 显示清理结果
    echo
    log_success "阶段 1 环境清理完成"
    
    # 验证清理结果
    local remaining_containers=$(docker ps -a --filter "name=mysql-stage1" --format "{{.Names}}" | wc -l)
    local remaining_networks=$(docker network ls --filter "name=stage1" --format "{{.Name}}" | wc -l)
    
    if [[ $remaining_containers -eq 0 && $remaining_networks -eq 0 ]]; then
        log_success "所有资源已清理完毕"
    else
        log_warning "可能还有残留资源，请手动检查"
        echo "• 容器: docker ps -a | grep stage1"
        echo "• 网络: docker network ls | grep stage1"
        echo "• 数据卷: docker volume ls | grep stage1"
    fi
}

# 执行清理
cleanup_stage1 "$@" 