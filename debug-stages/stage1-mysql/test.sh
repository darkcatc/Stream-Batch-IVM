#!/bin/bash

# ===================================
# 阶段 1: MySQL 环境测试脚本
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

# 检查测试环境
check_environment() {
    log_info "检查测试环境..."
    
    # 检查容器是否运行
    if ! docker ps --filter "name=mysql-stage1" --filter "status=running" | grep -q mysql-stage1; then
        log_error "MySQL 容器未运行，请先执行 ./start.sh"
        exit 1
    fi
    
    # 检查 Python 环境
    if [[ ! -d "../../venv" ]]; then
        log_warning "Python 虚拟环境不存在，请运行 ../../setup-env.sh"
    fi
    
    log_success "环境检查通过"
}

# 测试 MySQL 基础功能
test_mysql_basic() {
    log_info "测试 MySQL 基础功能..."
    
    # 测试连接
    if docker exec mysql-stage1 mysqladmin ping -h localhost -u root -proot123 >/dev/null 2>&1; then
        log_success "MySQL 连接测试通过"
    else
        log_error "MySQL 连接失败"
        return 1
    fi
    
    # 测试数据库
    local db_list=$(docker exec mysql-stage1 mysql -u root -proot123 -e "SHOW DATABASES;" --skip-column-names 2>/dev/null)
    if echo "$db_list" | grep -q "business_db"; then
        log_success "业务数据库存在"
    else
        log_error "业务数据库不存在"
        return 1
    fi
    
    # 测试表结构
    local table_count=$(docker exec mysql-stage1 mysql -u root -proot123 business_db -e "SHOW TABLES;" --skip-column-names 2>/dev/null | wc -l)
    if [[ $table_count -gt 0 ]]; then
        log_success "发现 $table_count 个数据表"
        
        # 显示表列表
        log_info "数据表列表："
        docker exec mysql-stage1 mysql -u root -proot123 business_db -e "SHOW TABLES;" 2>/dev/null
    else
        log_error "未发现数据表"
        return 1
    fi
    
    return 0
}

# 测试 CDC 配置
test_cdc_config() {
    log_info "测试 CDC 配置..."
    
    # 检查 binlog 配置
    local binlog_format=$(docker exec mysql-stage1 mysql -u root -proot123 -e "SHOW VARIABLES LIKE 'binlog_format';" --skip-column-names 2>/dev/null | awk '{print $2}')
    if [[ "$binlog_format" == "ROW" ]]; then
        log_success "binlog 格式配置正确: $binlog_format"
    else
        log_error "binlog 格式配置错误: $binlog_format (期望: ROW)"
        return 1
    fi
    
    # 检查 GTID 配置
    local gtid_mode=$(docker exec mysql-stage1 mysql -u root -proot123 -e "SHOW VARIABLES LIKE 'gtid_mode';" --skip-column-names 2>/dev/null | awk '{print $2}')
    if [[ "$gtid_mode" == "ON" ]]; then
        log_success "GTID 模式配置正确: $gtid_mode"
    else
        log_error "GTID 模式配置错误: $gtid_mode (期望: ON)"
        return 1
    fi
    
    # 检查 CDC 用户
    local cdc_user=$(docker exec mysql-stage1 mysql -u root -proot123 -e "SELECT User, Host FROM mysql.user WHERE User='flink_cdc';" --skip-column-names 2>/dev/null)
    if [[ -n "$cdc_user" ]]; then
        log_success "CDC 用户存在: $cdc_user"
    else
        log_error "CDC 用户不存在"
        return 1
    fi
    
    # 检查用户权限
    log_info "CDC 用户权限："
    docker exec mysql-stage1 mysql -u root -proot123 -e "SHOW GRANTS FOR 'flink_cdc'@'%';" 2>/dev/null
    
    return 0
}

# 测试数据库连接工具
test_connection_tool() {
    log_info "测试数据库连接工具..."
    
    cd ../..
    
    # 检查虚拟环境
    if [[ -f "venv/bin/activate" ]]; then
        source venv/bin/activate
        log_success "Python 虚拟环境激活成功"
    else
        log_warning "Python 虚拟环境不存在，使用系统 Python"
    fi
    
    # 测试连接脚本
    if python scripts/test-connection.py 2>/dev/null; then
        log_success "数据库连接工具测试通过"
    else
        log_warning "数据库连接工具测试失败，可能需要安装依赖"
        log_info "尝试安装依赖: pip install mysql-connector-python"
    fi
    
    cd debug-stages/stage1-mysql
    return 0
}

# 性能基准测试
test_performance() {
    log_info "执行性能基准测试..."
    
    # 测试简单插入性能
    local start_time=$(date +%s)
    
    docker exec mysql-stage1 mysql -u root -proot123 business_db -e "
    CREATE TEMPORARY TABLE perf_test (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        data VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    INSERT INTO perf_test (data) VALUES 
    ('test1'), ('test2'), ('test3'), ('test4'), ('test5'),
    ('test6'), ('test7'), ('test8'), ('test9'), ('test10');
    
    SELECT COUNT(*) as test_records FROM perf_test;
    " 2>/dev/null
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "性能测试完成，用时: ${duration}秒"
    
    return 0
}

# 数据生成器预备测试
test_data_generator_prep() {
    log_info "数据生成器预备测试..."
    
    cd ../..
    
    # 检查脚本存在
    if [[ -f "scripts/data-generator.py" ]]; then
        log_success "数据生成器脚本存在"
    else
        log_error "数据生成器脚本不存在"
        cd debug-stages/stage1-mysql
        return 1
    fi
    
    # 检查配置
    if python scripts/manage-config.py validate >/dev/null 2>&1; then
        log_success "配置验证通过"
    else
        log_warning "配置验证失败，可能影响数据生成器运行"
    fi
    
    cd debug-stages/stage1-mysql
    return 0
}

# 显示测试总结
show_test_summary() {
    echo
    log_info "======== 阶段 1 测试总结 ========"
    echo
    
    # 容器状态
    echo -e "${BLUE}容器状态:${NC}"
    docker ps --filter "name=mysql-stage1" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo
    
    # 数据库信息
    echo -e "${BLUE}数据库信息:${NC}"
    echo "• 版本: $(docker exec mysql-stage1 mysql -u root -proot123 -e "SELECT VERSION();" --skip-column-names 2>/dev/null)"
    echo "• 字符集: $(docker exec mysql-stage1 mysql -u root -proot123 -e "SHOW VARIABLES LIKE 'character_set_server';" --skip-column-names 2>/dev/null | awk '{print $2}')"
    echo "• 时区: $(docker exec mysql-stage1 mysql -u root -proot123 -e "SELECT @@time_zone;" --skip-column-names 2>/dev/null)"
    echo
    
    # binlog 状态
    echo -e "${BLUE}binlog 状态:${NC}"
    echo "• 格式: $(docker exec mysql-stage1 mysql -u root -proot123 -e "SHOW VARIABLES LIKE 'binlog_format';" --skip-column-names 2>/dev/null | awk '{print $2}')"
    echo "• GTID: $(docker exec mysql-stage1 mysql -u root -proot123 -e "SHOW VARIABLES LIKE 'gtid_mode';" --skip-column-names 2>/dev/null | awk '{print $2}')"
    echo
    
    # 推荐下一步
    echo -e "${GREEN}✅ 阶段 1 测试完成！${NC}"
    echo
    echo -e "${BLUE}🚀 推荐下一步操作:${NC}"
    echo "  1. 启动数据生成器测试数据写入："
    echo "     cd ../.."
    echo "     source venv/bin/activate"
    echo "     python scripts/data-generator.py --sales-interval 2"
    echo
    echo "  2. 观察数据变化："
    echo "     docker exec -it mysql-stage1 mysql -u root -proot123 business_db"
    echo "     mysql> SELECT COUNT(*) FROM store_sales;"
    echo
    echo "  3. 准备进入阶段 2："
    echo "     cd ../stage2-cdc-cloudberry"
    echo "     ./start.sh"
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "  阶段 1: MySQL 环境测试"
    echo "  作者：Vance Chen"
    echo "========================================"
    echo -e "${NC}"
    
    local test_passed=0
    local test_total=5
    
    if check_environment; then ((test_passed++)); fi
    if test_mysql_basic; then ((test_passed++)); fi
    if test_cdc_config; then ((test_passed++)); fi
    if test_connection_tool; then ((test_passed++)); fi
    if test_data_generator_prep; then ((test_passed++)); fi
    
    echo
    if [[ $test_passed -eq $test_total ]]; then
        log_success "所有测试通过 ($test_passed/$test_total)"
        show_test_summary
        exit 0
    else
        log_warning "部分测试失败 ($test_passed/$test_total)"
        show_test_summary
        exit 1
    fi
}

# 执行主函数
main "$@" 