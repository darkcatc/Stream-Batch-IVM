#!/bin/bash

# 阶段2: Flink CDC → Cloudberry 清理脚本
# 作者: Vance Chen

set -e

echo "=========================================="
echo "阶段2: 清理 MySQL + Flink CDC 环境"
echo "=========================================="

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 切换到阶段2目录
cd "$SCRIPT_DIR"

echo "停止并移除容器..."
docker-compose down

echo "移除容器镜像缓存..."
docker-compose down --rmi local 2>/dev/null || true

echo "清理数据卷..."
docker volume rm mysql-data-stage2 2>/dev/null || echo "数据卷 mysql-data-stage2 不存在或已删除"
docker volume rm flink-data-stage2 2>/dev/null || echo "数据卷 flink-data-stage2 不存在或已删除"

echo "清理网络..."
docker network rm stream-batch-network-stage2 2>/dev/null || echo "网络 stream-batch-network-stage2 不存在或已删除"

echo "清理临时文件..."
rm -f /tmp/test-cdc.sql 2>/dev/null || true
rm -f /tmp/cdc-test-result.log 2>/dev/null || true

echo "显示剩余的相关容器..."
docker ps -a | grep -E "(mysql-stage2|flink.*stage2)" || echo "没有相关容器残留"

echo "显示剩余的相关数据卷..."
docker volume ls | grep stage2 || echo "没有相关数据卷残留"

echo "显示剩余的相关网络..."
docker network ls | grep stage2 || echo "没有相关网络残留"

echo ""
echo "=========================================="
echo "阶段2环境清理完成!"
echo "==========================================" 