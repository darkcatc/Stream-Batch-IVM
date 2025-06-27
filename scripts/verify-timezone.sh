#!/bin/bash

# =============================================
# 时区配置验证脚本
# 作者：Vance Chen
# 
# 功能：验证所有Docker容器的时区配置是否正确
# =============================================

set -e

# 颜色输出函数
print_success() {
    echo -e "\033[32m✓ $1\033[0m"
}

print_error() {
    echo -e "\033[31m✗ $1\033[0m"
}

print_info() {
    echo -e "\033[34mℹ $1\033[0m"
}

print_warning() {
    echo -e "\033[33m⚠ $1\033[0m"
}

echo "========================================"
echo "🕒 时区配置验证脚本"
echo "========================================"

# 检查.env文件中的时区配置
print_info "检查.env文件中的时区配置..."
if [ -f ".env" ]; then
    echo "环境变量配置："
    grep -E "(TIMEZONE|TZ|JAVA_TIMEZONE|MYSQL_TIMEZONE|FLINK_TIMEZONE)" .env || print_warning "未找到时区相关配置"
else
    print_error ".env文件不存在"
    exit 1
fi

echo ""

# 获取所有运行中的容器
print_info "检查运行中的容器时区设置..."
containers=$(docker ps --format "{{.Names}}" 2>/dev/null || true)

if [ -z "$containers" ]; then
    print_warning "没有找到运行中的容器"
    echo "请先启动相应的Docker服务"
    exit 0
fi

echo ""
echo "容器时区检查结果："
echo "----------------------------------------"

for container in $containers; do
    echo "🐳 检查容器: $container"
    
    # 检查容器时区
    timezone=$(docker exec "$container" date '+%Z %z' 2>/dev/null || echo "ERROR")
    
    if [ "$timezone" = "ERROR" ]; then
        print_error "  无法获取容器时区信息"
    else
        print_success "  时区: $timezone"
        
        # 显示当前时间
        current_time=$(docker exec "$container" date 2>/dev/null || echo "ERROR")
        if [ "$current_time" != "ERROR" ]; then
            echo "  当前时间: $current_time"
        fi
    fi
    
    echo ""
done

# 检查MySQL时区配置
mysql_containers=$(echo "$containers" | grep -i mysql || true)
if [ -n "$mysql_containers" ]; then
    print_info "检查MySQL数据库时区配置..."
    for mysql_container in $mysql_containers; do
        echo "🗄️  MySQL容器: $mysql_container"
        
        # 检查MySQL时区变量
        mysql_timezone=$(docker exec "$mysql_container" mysql -uroot -proot123 -e "SELECT @@system_time_zone, @@time_zone;" 2>/dev/null || echo "ERROR")
        
        if [ "$mysql_timezone" = "ERROR" ]; then
            print_warning "  无法连接到MySQL或获取时区信息"
        else
            echo "  MySQL时区配置:"
            echo "$mysql_timezone"
        fi
        echo ""
    done
fi

# 检查Flink时区配置
flink_containers=$(echo "$containers" | grep -i flink || true)
if [ -n "$flink_containers" ]; then
    print_info "检查Flink时区配置..."
    for flink_container in $flink_containers; do
        echo "⚡ Flink容器: $flink_container"
        
        # 检查Java时区
        java_timezone=$(docker exec "$flink_container" java -XshowSettings:properties -version 2>&1 | grep "user.timezone" || echo "未找到Java时区配置")
        print_success "  $java_timezone"
        echo ""
    done
fi

echo "========================================"
print_success "时区验证完成！"
echo "========================================"

# 给出建议
echo ""
print_info "时区配置建议："
echo "1. 确保所有容器使用相同的时区 (Asia/Shanghai)"
echo "2. MySQL数据库时区应与系统时区一致"
echo "3. Flink作业的本地时区设置应正确"
echo "4. 如有问题，请重新启动相关服务" 