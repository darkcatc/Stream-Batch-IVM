#!/bin/bash

# 阶段2依赖包下载脚本 - 适配Flink 1.20.1 + CDC 3.4.0
# 作者: Vance Chen
# 创建时间: 2025-01-21

set -e

echo "=== 阶段2依赖包下载 (Flink 1.20.1 + CDC 3.4.0) ==="

# 创建目录
FLINK_LIB_DIR="../../flink-lib"
mkdir -p "$FLINK_LIB_DIR"
cd "$FLINK_LIB_DIR"

echo "当前目录: $(pwd)"

# Flink CDC 连接器 (适配Flink 1.20)
echo "1. 下载 Flink CDC MySQL 连接器..."
if [ ! -f "flink-cdc-connectors-mysql-3.4.0.jar" ]; then
    curl -L "https://repo1.maven.org/maven2/org/apache/flink/flink-cdc-connectors-mysql/3.4.0/flink-cdc-connectors-mysql-3.4.0.jar" \
         -o "flink-cdc-connectors-mysql-3.4.0.jar"
    echo "✅ MySQL CDC连接器下载完成"
else
    echo "✅ MySQL CDC连接器已存在"
fi

# MySQL JDBC驱动
echo "2. 下载 MySQL JDBC 驱动..."
if [ ! -f "mysql-connector-j-8.0.33.jar" ]; then
    curl -L "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/mysql-connector-j-8.0.33.jar" \
         -o "mysql-connector-j-8.0.33.jar"
    echo "✅ MySQL JDBC驱动下载完成"
else
    echo "✅ MySQL JDBC驱动已存在"
fi

# 验证下载的文件
echo ""
echo "=== 下载完成的依赖包 ==="
ls -la *.jar | grep -E "(flink-cdc|mysql-connector)"

echo ""
echo "=== 依赖包下载完成 ==="
echo "Flink 版本: 1.20.1"
echo "CDC 版本: 3.4.0"
echo "依赖包位置: $(pwd)"
echo ""
echo "下一步: 重新启动Flink容器"
echo "命令: cd debug-stages/stage2-cdc-cloudberry && ./restart.sh" 