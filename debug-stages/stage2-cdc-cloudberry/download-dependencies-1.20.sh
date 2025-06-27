#!/bin/bash

# 阶段2依赖包下载脚本 - 适配Flink 1.20.1 + CDC 3.4.0 + CloudBerry
# 作者: Vance Chen
# 创建时间: 2025-01-21

set -e

echo "=== 阶段2依赖包下载 (Flink 1.20.1 + CDC 3.4.0 + CloudBerry) ==="

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

# Flink JDBC 连接器 (适配Flink 1.20 + CloudBerry)
echo "2. 下载 Flink JDBC 连接器..."
if [ ! -f "flink-connector-jdbc-3.3.0-1.20.jar" ]; then
    curl -L "https://repo.maven.apache.org/maven2/org/apache/flink/flink-connector-jdbc/3.3.0-1.20/flink-connector-jdbc-3.3.0-1.20.jar" \
         -o "flink-connector-jdbc-3.3.0-1.20.jar"
    echo "✅ Flink JDBC连接器下载完成"
else
    echo "✅ Flink JDBC连接器已存在"
fi

# PostgreSQL JDBC驱动 (CloudBerry基于PostgreSQL)
echo "3. 下载 PostgreSQL JDBC 驱动..."
if [ ! -f "postgresql-42.7.1.jar" ]; then
    curl -L "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.1/postgresql-42.7.1.jar" \
         -o "postgresql-42.7.1.jar"
    echo "✅ PostgreSQL JDBC驱动下载完成"
else
    echo "✅ PostgreSQL JDBC驱动已存在"
fi

# MySQL JDBC驱动
echo "4. 下载 MySQL JDBC 驱动..."
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
ls -la *.jar | grep -E "(flink-cdc|flink-connector-jdbc|postgresql|mysql-connector)"

echo ""
echo "=== 依赖包下载完成 ==="
echo "Flink 版本: 1.20.1"
echo "CDC 版本: 3.4.0"
echo "JDBC 连接器版本: 3.3.0-1.20"
echo "PostgreSQL 驱动版本: 42.7.1"
echo "依赖包位置: $(pwd)"
echo ""
echo "下一步: 重新启动Flink容器"
echo "命令: cd debug-stages/stage2-cdc-cloudberry && ./start.sh" 