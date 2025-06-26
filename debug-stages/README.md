# 分阶段调试指南

**作者：Vance Chen**

本目录包含分阶段调试所需的所有文件，避免一次性启动所有服务导致问题叠加。

## 🎯 调试策略

### 为什么分阶段调试？
1. **问题隔离** - 每个阶段只关注特定功能，便于定位问题
2. **资源节约** - 避免启动不必要的服务
3. **状态保存** - 每个阶段调试通过后保存状态
4. **渐进验证** - 确保底层服务稳定后再添加上层服务

## 📋 调试阶段

### 🔧 阶段 1: MySQL 基础环境
**目标**: 验证 MySQL 服务和数据生成器
- ✅ MySQL 容器启动
- ✅ 数据库初始化脚本执行
- ✅ CDC 用户权限设置
- ✅ 数据生成器稳定运行

**文件**:
- `stage1-mysql/docker-compose.yml` - MySQL 服务定义
- `stage1-mysql/start.sh` - 启动脚本
- `stage1-mysql/test.sh` - 测试脚本

### 🔄 阶段 2: Flink CDC → Cloudberry
**目标**: 验证 CDC 数据捕获和直接同步
- ✅ Flink 集群启动
- ✅ CDC 连接器配置
- ✅ Cloudberry 连接测试
- ✅ 数据同步验证

**文件**:
- `stage2-cdc-cloudberry/docker-compose.yml` - 添加 Flink 服务
- `stage2-cdc-cloudberry/start.sh` - 启动脚本
- `stage2-cdc-cloudberry/test.sh` - 测试脚本

### 📨 阶段 3: Flink CDC → Kafka
**目标**: 验证 CDC 数据发送到 Kafka
- ✅ Kafka 集群启动  
- ✅ CDC 到 Kafka 的数据流
- ✅ Topic 数据验证
- ✅ AKHQ 监控界面

**文件**:
- `stage3-cdc-kafka/docker-compose.yml` - 添加 Kafka 服务
- `stage3-cdc-kafka/start.sh` - 启动脚本
- `stage3-cdc-kafka/test.sh` - 测试脚本

### 🌊 阶段 4: 完整流式处理
**目标**: 端到端流式处理和分析
- ✅ 流式分析作业
- ✅ 实时指标计算
- ✅ 告警规则
- ✅ 完整监控体系

**文件**:
- `stage4-streaming/docker-compose.yml` - 完整服务栈
- `stage4-streaming/start.sh` - 启动脚本
- `stage4-streaming/test.sh` - 测试脚本

## 🚀 使用方法

### 准备工作
```bash
# 确保在项目根目录
cd /mnt/d/Projects/Stream-Batch-IVM

# 激活 Python 环境
source venv/bin/activate
```

### 阶段式调试
```bash
# 阶段 1: 启动 MySQL
cd debug-stages/stage1-mysql
./start.sh
./test.sh

# 阶段 2: 添加 Flink CDC → Cloudberry
cd ../stage2-cdc-cloudberry  
./start.sh
./test.sh

# 阶段 3: 添加 Kafka
cd ../stage3-cdc-kafka
./start.sh
./test.sh

# 阶段 4: 完整流式处理
cd ../stage4-streaming
./start.sh
./test.sh
```

### 清理和重置
```bash
# 清理当前阶段
./cleanup.sh

# 重置所有阶段
cd debug-stages
./cleanup-all.sh
```

## 📊 调试检查清单

### 阶段 1 检查项
- [ ] MySQL 容器健康检查通过
- [ ] 数据库初始化脚本执行成功
- [ ] CDC 用户创建和权限设置正确
- [ ] 数据生成器能正常连接和写入
- [ ] binlog 配置正确

### 阶段 2 检查项
- [ ] Flink JobManager 和 TaskManager 启动正常
- [ ] MySQL CDC 连接器加载成功
- [ ] Cloudberry 连接测试通过
- [ ] CDC 作业提交成功
- [ ] 数据同步到 Cloudberry 验证

### 阶段 3 检查项
- [ ] Kafka 和 Zookeeper 启动正常
- [ ] Topic 自动创建成功
- [ ] CDC 数据发送到 Kafka
- [ ] AKHQ 界面可访问
- [ ] Topic 数据格式正确

### 阶段 4 检查项
- [ ] 流式分析作业运行正常
- [ ] 实时指标计算正确
- [ ] 告警规则触发测试
- [ ] 所有监控界面正常

## 🛠️ 故障排除

### 常见问题
1. **容器启动失败** - 检查端口冲突和资源占用
2. **连接失败** - 验证网络配置和服务发现
3. **权限错误** - 检查数据库用户权限和文件权限
4. **数据不同步** - 验证 binlog 配置和 CDC 作业状态

### 调试命令
```bash
# 查看容器日志
docker logs <container_name>

# 检查容器状态
docker ps -a

# 查看网络连接
docker network ls
docker network inspect <network_name>

# 进入容器调试
docker exec -it <container_name> bash
```

## 📝 注意事项

1. **每个阶段独立** - 不同阶段使用不同的网络和卷名
2. **状态保存** - 成功的阶段可以保存快照
3. **资源清理** - 调试完成后及时清理资源
4. **配置隔离** - 每个阶段有独立的配置文件

---

💡 **提示**: 建议按顺序逐个阶段调试，确保每个阶段完全稳定后再进入下一阶段。 