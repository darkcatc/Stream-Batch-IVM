# Python 环境配置指南

**作者：Vance Chen**

## 快速开始

### 1. 自动初始化（推荐）

```bash
# 运行环境初始化脚本
./setup-env.sh
```

### 2. 手动初始化

如果自动脚本失败，请按以下步骤手动配置：

#### 步骤 1: 安装系统依赖

```bash
# Ubuntu/Debian 系统
sudo apt update
sudo apt install python3.12-venv python3-pip

# 或者对于其他 Python 版本
sudo apt install python3-venv python3-pip
```

#### 步骤 2: 创建虚拟环境

```bash
# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate
```

#### 步骤 3: 安装 Python 依赖

```bash
# 升级 pip
python -m pip install --upgrade pip

# 安装项目依赖
pip install -r requirements.txt

# 或者手动安装核心依赖
pip install mysql-connector-python==8.2.0
```

#### 步骤 4: 测试环境

```bash
# 测试 MySQL 连接
python3 scripts/test-connection.py
```

## 使用方法

### 激活环境

```bash
# 方法1：直接激活
source venv/bin/activate

# 方法2：使用快捷脚本（如果已创建）
./activate-env.sh
```

### 运行数据生成器

```bash
# 基础运行
python3 scripts/data-generator.py

# 自定义参数
python3 scripts/data-generator.py --sales-interval 1 --return-probability 0.2
```

### 退出环境

```bash
deactivate
```

## 故障排除

### 问题 1: venv 模块不可用

**错误信息**: `The virtual environment was not created successfully because ensurepip is not available`

**解决方案**:
```bash
sudo apt install python3.12-venv python3-pip
```

### 问题 2: mysql.connector 导入失败

**错误信息**: `ModuleNotFoundError: No module named 'mysql.connector'`

**解决方案**:
```bash
# 确保虚拟环境已激活
source venv/bin/activate

# 安装 MySQL 连接器
pip install mysql-connector-python
```

### 问题 3: 数据库连接失败

**错误信息**: `mysql.connector.errors.DatabaseError: 2003 (HY000): Can't connect to MySQL server`

**解决方案**:
1. 确保 Docker MySQL 服务已启动：`./start-demo.sh`
2. 检查端口映射：`docker ps | grep mysql`
3. 测试连接：`python3 scripts/test-connection.py`

## 目录结构

```
├── venv/                    # Python 虚拟环境
├── scripts/                 # Python 脚本工具包
│   ├── __init__.py         # Python 包初始化
│   ├── config_loader.py     # 统一配置加载器
│   ├── data-generator.py    # TPC-DS 数据生成器
│   ├── test-connection.py   # 数据库连接测试
│   ├── manage-config.py     # 配置管理工具
│   └── generate-flink-configs.py # Flink 配置生成器
├── .env                     # 统一配置文件
├── requirements.txt         # Python 依赖
├── setup-env.sh            # 环境初始化脚本
├── activate-env.sh         # 环境激活脚本（自动生成）
└── .vscode/                # VSCode 配置（自动生成）
    └── settings.json
```

## VSCode 集成

如果使用 VSCode，项目会自动配置：

1. **Python 解释器**: `./venv/bin/python`
2. **自动激活**: 打开终端时自动激活虚拟环境
3. **语法检查**: 启用 Python linting

## 数据生成器参数

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `--host` | localhost | MySQL 主机地址 |
| `--port` | 3306 | MySQL 端口 |
| `--user` | root | MySQL 用户名 |
| `--password` | root123 | MySQL 密码 |
| `--database` | business_db | 数据库名称 |
| `--sales-interval` | 2 | 销售数据生成间隔（秒） |
| `--return-probability` | 0.1 | 退货概率（0-1） |

## 示例命令

```bash
# 快速生成大量数据
python3 scripts/data-generator.py --sales-interval 0.5 --return-probability 0.15

# 低频生成，适合演示
python3 scripts/data-generator.py --sales-interval 5 --return-probability 0.05

# 连接到自定义 MySQL 实例
python3 scripts/data-generator.py --host 192.168.1.100 --user myuser --password mypass
``` 