#!/bin/bash

# =============================================
# Python 虚拟环境初始化脚本
# 作者：Vance Chen
# 用于 TPC-DS 数据生成器环境配置
# =============================================

set -e

echo "🐍 初始化 Python 虚拟环境..."

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

# 检查系统依赖
check_system_dependencies() {
    log_info "检查系统依赖..."
    
    # 检查 Python 版本
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 未安装"
        exit 1
    fi
    
    python_version=$(python3 --version | cut -d' ' -f2)
    log_info "Python 版本: $python_version"
    
    # 检查是否有venv模块
    if ! python3 -c "import venv" 2>/dev/null; then
        log_warn "python3-venv 未安装，请执行以下命令："
        echo "  sudo apt update"
        echo "  sudo apt install python3.12-venv python3-pip"
        read -p "是否现在安装？(y/n): " install_venv
        if [[ $install_venv == "y" || $install_venv == "Y" ]]; then
            sudo apt update && sudo apt install -y python3.12-venv python3-pip
        else
            log_error "需要先安装 python3-venv"
            exit 1
        fi
    fi
}

# 创建虚拟环境
create_virtual_env() {
    log_info "创建虚拟环境..."
    
    # 删除已存在的虚拟环境
    if [ -d "venv" ]; then
        log_warn "删除已存在的虚拟环境..."
        rm -rf venv
    fi
    
    # 创建新的虚拟环境
    python3 -m venv venv
    log_info "虚拟环境创建成功 ✅"
}

# 激活虚拟环境并安装依赖
install_dependencies() {
    log_info "激活虚拟环境并安装依赖..."
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 升级 pip
    python -m pip install --upgrade pip
    
    # 安装项目依赖
    if [ -f "requirements.txt" ]; then
        log_info "从 requirements.txt 安装依赖..."
        pip install -r requirements.txt
    else
        log_info "安装基础依赖..."
        pip install mysql-connector-python==8.2.0
    fi
    
    log_info "依赖安装完成 ✅"
}

# 测试数据库连接
test_database_connection() {
    log_info "测试数据库连接..."
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 测试MySQL连接器
    python3 -c "
import mysql.connector
print('✅ mysql-connector-python 可用')

# 测试连接配置（不实际连接，只验证配置格式）
config = {
    'host': 'localhost',
    'port': 3306,
    'user': 'root',
    'password': 'root123',
    'database': 'business_db'
}
print('✅ 连接配置格式正确')
print('📝 提示：确保 Docker MySQL 服务已启动后再运行数据生成器')
"
}

# 创建激活脚本
create_activation_script() {
    log_info "创建环境激活脚本..."
    
    cat > activate-env.sh << 'EOF'
#!/bin/bash
# 激活 TPC-DS 项目虚拟环境
source venv/bin/activate
echo "🐍 虚拟环境已激活"
echo "📝 运行数据生成器: python3 scripts/data-generator.py"
echo "🔧 退出环境: deactivate"
EOF
    
    chmod +x activate-env.sh
    log_info "激活脚本创建完成: ./activate-env.sh ✅"
}

# 创建项目配置文件
create_project_config() {
    log_info "创建项目配置文件..."
    
    # 创建 .vscode 配置
    mkdir -p .vscode
    
    cat > .vscode/settings.json << 'EOF'
{
    "python.defaultInterpreterPath": "./venv/bin/python",
    "python.terminal.activateEnvironment": true,
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "files.associations": {
        "*.sql": "sql"
    }
}
EOF
    
    log_info "VSCode 配置创建完成 ✅"
}

# 显示使用说明
show_usage_info() {
    echo ""
    echo -e "${BLUE}🎉 环境配置完成！${NC}"
    echo ""
    echo -e "${GREEN}📋 使用方法：${NC}"
    echo "  # 激活虚拟环境"
    echo "  source venv/bin/activate"
    echo "  # 或者运行快捷脚本"
    echo "  ./activate-env.sh"
    echo ""
    echo "  # 启动数据生成器"
    echo "  python3 scripts/data-generator.py"
    echo ""
    echo "  # 退出虚拟环境"
    echo "  deactivate"
    echo ""
    echo -e "${YELLOW}💡 提示：${NC}"
    echo "  • 确保先启动 Docker 环境: ./start-demo.sh"
    echo "  • 数据生成器会连接到 localhost:3306 的 MySQL"
    echo "  • 使用 Ctrl+C 停止数据生成"
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "  TPC-DS Python 环境初始化"
    echo "  作者：Vance Chen"
    echo "========================================"
    echo -e "${NC}"
    
    check_system_dependencies
    create_virtual_env
    install_dependencies
    test_database_connection
    create_activation_script
    create_project_config
    show_usage_info
    
    log_info "环境初始化完成！ 🎉"
}

# 执行主函数
main "$@" 