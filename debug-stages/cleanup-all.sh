#!/bin/bash

# ===================================
# 全局清理脚本 - 清理所有阶段资源
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

# 清理所有阶段
cleanup_all_stages() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "  全局清理 - 所有调试阶段"
    echo "  作者：Vance Chen"
    echo "========================================"
    echo -e "${NC}"
    
    log_warning "这将清理所有调试阶段的 Docker 资源！"
    log_warning "包括容器、网络和可选的数据卷。"
    echo
    read -p "确定要继续吗？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "取消清理操作"
        exit 0
    fi
    
    log_info "开始全局清理..."
    
    # 停止所有相关容器
    log_info "停止所有调试阶段容器..."
    docker stop $(docker ps -q --filter "name=stage") 2>/dev/null || true
    docker stop $(docker ps -q --filter "name=mysql-stage") 2>/dev/null || true
    docker stop $(docker ps -q --filter "name=flink-stage") 2>/dev/null || true
    docker stop $(docker ps -q --filter "name=kafka-stage") 2>/dev/null || true
    
    # 删除所有相关容器
    log_info "删除所有调试阶段容器..."
    docker rm -f $(docker ps -aq --filter "name=stage") 2>/dev/null || true
    docker rm -f mysql-stage1 mysql-stage2 mysql-stage3 mysql-stage4 2>/dev/null || true
    docker rm -f flink-jobmanager-stage2 flink-taskmanager-stage2 2>/dev/null || true
    docker rm -f kafka-stage3 zookeeper-stage3 akhq-stage3 2>/dev/null || true
    
    # 清理网络
    log_info "清理调试阶段网络..."
    docker network rm stream-batch-network-stage1 2>/dev/null || true
    docker network rm stream-batch-network-stage2 2>/dev/null || true
    docker network rm stream-batch-network-stage3 2>/dev/null || true
    docker network rm stream-batch-network-stage4 2>/dev/null || true
    
    # 询问是否删除数据卷
    echo
    log_warning "是否删除所有数据卷？这将删除所有持久化数据！"
    read -p "删除数据卷？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "删除调试阶段数据卷..."
        docker volume rm mysql-data-stage1 2>/dev/null || true
        docker volume rm mysql-data-stage2 2>/dev/null || true
        docker volume rm mysql-data-stage3 2>/dev/null || true
        docker volume rm mysql-data-stage4 2>/dev/null || true
        docker volume rm kafka-data-stage3 2>/dev/null || true
        docker volume rm zookeeper-data-stage3 2>/dev/null || true
        log_success "数据卷已删除"
    else
        log_info "保留所有数据卷"
    fi
    
    # 清理本地配置文件
    log_info "清理本地配置文件..."
    find . -name ".env" -not -path "../.env" -delete 2>/dev/null || true
    
    # 清理 Docker 系统（可选）
    echo
    log_info "是否执行 Docker 系统清理？（清理未使用的镜像、网络等）"
    read -p "执行系统清理？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "执行 Docker 系统清理..."
        docker system prune -f
        log_success "系统清理完成"
    fi
}

# 显示清理结果
show_cleanup_result() {
    echo
    log_info "======== 清理结果检查 ========"
    
    # 检查残留容器
    local stage_containers=$(docker ps -a --filter "name=stage" --format "{{.Names}}" | wc -l)
    echo -e "${BLUE}残留容器:${NC} $stage_containers 个"
    if [[ $stage_containers -gt 0 ]]; then
        docker ps -a --filter "name=stage" --format "table {{.Names}}\t{{.Status}}"
    fi
    
    # 检查残留网络
    local stage_networks=$(docker network ls --filter "name=stage" --format "{{.Name}}" | wc -l)
    echo -e "${BLUE}残留网络:${NC} $stage_networks 个"
    if [[ $stage_networks -gt 0 ]]; then
        docker network ls --filter "name=stage"
    fi
    
    # 检查残留数据卷
    local stage_volumes=$(docker volume ls --filter "name=stage" --format "{{.Name}}" | wc -l)
    echo -e "${BLUE}残留数据卷:${NC} $stage_volumes 个"
    if [[ $stage_volumes -gt 0 ]]; then
        docker volume ls --filter "name=stage"
    fi
    
    echo
    if [[ $stage_containers -eq 0 && $stage_networks -eq 0 ]]; then
        log_success "✅ 所有调试阶段资源已清理完毕"
    else
        log_warning "⚠️  仍有残留资源，可能需要手动清理"
    fi
    
    echo
    log_info "🔄 重新开始调试："
    echo "  cd stage1-mysql && ./start.sh"
}

# 主函数
main() {
    cleanup_all_stages
    show_cleanup_result
    
    echo
    log_success "全局清理完成！"
}

# 执行主函数
main "$@" 