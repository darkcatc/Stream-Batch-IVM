# Scripts 工具包

**作者：Vance Chen**

本目录包含项目的所有 Python 脚本工具，统一管理配置、数据生成、连接测试等功能。

## 工具列表

### 🔧 核心工具

#### `config_loader.py` - 配置加载器
统一的配置管理工具，从 `.env` 文件读取所有配置项。

```python
from scripts.config_loader import ConfigLoader

# 创建配置加载器
loader = ConfigLoader()

# 获取 MySQL 连接参数
mysql_config = loader.get_connection_params('mysql')

# 获取数据生成器配置
generator_config = loader.get_data_generator_config()
```

#### `manage-config.py` - 配置管理工具
命令行工具，用于显示、验证和管理项目配置。

```bash
# 显示所有配置摘要
python scripts/manage-config.py show

# 验证配置完整性
python scripts/manage-config.py validate
```

### 🚀 数据工具

#### `data-generator.py` - TPC-DS 数据生成器
模拟实时销售和退货数据，支持自定义生成速率和并发度。

```bash
# 基础运行
python scripts/data-generator.py

# 自定义参数
python scripts/data-generator.py --sales-interval 1 --return-probability 0.2
```

#### `test-connection.py` - 连接测试工具
测试 MySQL 和 Cloudberry 数据库的连接状态。

```bash
python scripts/test-connection.py
```

### ⚙️ 配置工具

#### `generate-flink-configs.py` - Flink 配置生成器
生成 Flink SQL 配置文件，支持模板替换。

```bash
# 生成所有配置文件
python scripts/generate-flink-configs.py generate

# 验证配置
python scripts/generate-flink-configs.py validate

# 显示配置摘要
python scripts/generate-flink-configs.py show
```

## 使用方法

### 1. 激活虚拟环境

```bash
# 激活虚拟环境
source venv/bin/activate

# 或使用快捷脚本
./activate-env.sh
```

### 2. 运行工具

所有脚本都可以直接运行，会自动加载 `.env` 配置文件：

```bash
# 查看配置状态
python scripts/manage-config.py show

# 测试数据库连接
python scripts/test-connection.py

# 启动数据生成器
python scripts/data-generator.py
```

### 3. 作为模块导入

脚本也可以作为 Python 模块导入使用：

```python
# 导入配置加载器
from scripts.config_loader import ConfigLoader

# 使用配置
loader = ConfigLoader()
mysql_config = loader.get_connection_params('mysql')
```

## 配置系统

### 配置文件位置
所有配置都在项目根目录的 `.env` 文件中：

```
Stream-Batch-IVM/
├── .env                 # 统一配置文件
├── scripts/            # 工具包目录
│   ├── __init__.py     # Python 包初始化
│   └── ...             # 各种工具脚本
└── docker-compose.yml  # Docker 编排文件
```

### 配置优先级

1. **环境变量** - 最高优先级
2. **`.env` 文件** - 中等优先级  
3. **默认值** - 最低优先级

### 配置示例

```bash
# MySQL 配置
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_CDC_USER=flink_cdc
MYSQL_CDC_PASSWORD=flink_cdc123

# Cloudberry 配置
CLOUDBERRY_HOST=127.0.0.1
CLOUDBERRY_PORT=15432
CLOUDBERRY_USER=gpadmin

# 数据生成器配置
DATA_GENERATOR_BATCH_SIZE=1000
DATA_GENERATOR_INTERVAL=5
```

## 常见问题

### Q: 脚本无法找到配置文件
**A**: 确保在项目根目录运行脚本，或检查 `.env` 文件是否存在：

```bash
# 确认当前位置
pwd

# 检查 .env 文件
ls -la .env

# 验证配置
python scripts/manage-config.py validate
```

### Q: 导入模块失败
**A**: 确保已激活虚拟环境并安装依赖：

```bash
# 激活环境
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt
```

### Q: 数据库连接失败
**A**: 确保 Docker 服务已启动：

```bash
# 启动 Docker 环境
./start-demo.sh

# 测试连接
python scripts/test-connection.py
```

## 开发指南

### 添加新工具

1. 在 `scripts/` 目录创建新的 Python 文件
2. 使用 `ConfigLoader` 类加载配置
3. 添加适当的命令行参数解析
4. 更新本 README 文档

### 配置管理

- 新增配置项在 `.env` 文件中添加
- 在 `config_loader.py` 中添加对应的加载逻辑
- 更新 `manage-config.py` 的验证规则

### 代码规范

- 使用中文注释
- 遵循 PEP 8 代码风格
- 包含错误处理和用户友好的提示信息
- 支持命令行参数和配置文件两种配置方式

---

📝 **提示**: 所有工具都支持 `--help` 参数查看使用说明 