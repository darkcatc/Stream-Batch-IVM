#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
配置管理工具 - 简化版
作者：Vance Chen

管理项目配置，统一使用 .env 文件
"""

import argparse
import sys
from pathlib import Path

# 添加 config 包到路径
current_dir = Path(__file__).parent
project_root = current_dir.parent
sys.path.insert(0, str(project_root))

from config_loader import ConfigLoader

def show_config():
    """显示所有配置信息"""
    try:
        config_loader = ConfigLoader()
        
        print("=== 所有配置摘要 ===")
        print()
        
        # MySQL 配置
        mysql_config = config_loader.get_connection_params('mysql')
        print("MYSQL 配置:")
        print(f"  host: {mysql_config['host']}")
        print(f"  port: {mysql_config['port']}")
        print(f"  database: {mysql_config['database']}")
        print(f"  username: {mysql_config['username']}")
        print(f"  password: {'*' * 12}")
        print(f"  timezone: {mysql_config['timezone']}")
        print()
        
        # Cloudberry 配置
        cloudberry_config = config_loader.get_connection_params('cloudberry')
        print("CLOUDBERRY 配置:")
        print(f"  host: {cloudberry_config['host']}")
        print(f"  port: {cloudberry_config['port']}")
        print(f"  database: {cloudberry_config['database']}")
        print(f"  schema: {cloudberry_config['schema']}")
        print(f"  username: {cloudberry_config['username']}")
        print(f"  password: {'*' * 12}")
        print(f"  jdbc_url: {cloudberry_config['jdbc_url']}")
        print()
        
        # Kafka 配置
        kafka_config = config_loader.get_connection_params('kafka')
        print("KAFKA 配置:")
        print(f"  host: {kafka_config['host']}")
        print(f"  internal_port: {kafka_config['internal_port']}")
        print(f"  external_port: {kafka_config['external_port']}")
        print(f"  bootstrap_servers: {kafka_config['bootstrap_servers']}")
        print()
        
        # Flink 配置
        flink_config = config_loader.get_connection_params('flink')
        print("FLINK 配置:")
        print(f"  jobmanager_host: {flink_config['jobmanager_host']}")
        print(f"  web_port: {flink_config['web_port']}")
        print(f"  parallelism: {flink_config['parallelism']}")
        print(f"  checkpoint_interval: {flink_config['checkpoint_interval']}")
        
    except Exception as e:
        print(f"❌ 显示配置失败: {e}")
        return False
    
    return True

def validate_config():
    """验证配置完整性"""
    try:
        config_loader = ConfigLoader()
        
        print("🔍 验证配置完整性...")
        
        # 检查 .env 文件是否存在
        env_file = project_root / '.env'
        if not env_file.exists():
            print("❌ .env 文件不存在")
            return False
        
        # 加载配置
        all_config = config_loader.load_all_configs()
        
        # 检查必要的配置项
        required_configs = [
            'MYSQL_HOST', 'MYSQL_DATABASE', 'MYSQL_CDC_USER',
            'CLOUDBERRY_HOST', 'CLOUDBERRY_PORT', 'CLOUDBERRY_USER',
            'KAFKA_HOST', 'KAFKA_EXTERNAL_PORT',
            'FLINK_JOBMANAGER_HOST', 'FLINK_JOBMANAGER_WEB_PORT'
        ]
        
        missing_configs = []
        for config_key in required_configs:
            if config_key not in all_config or not all_config[config_key]:
                missing_configs.append(config_key)
        
        if missing_configs:
            print(f"❌ 缺少必要配置: {', '.join(missing_configs)}")
            return False
        
        print("✅ 配置验证通过")
        return True
        
    except Exception as e:
        print(f"❌ 配置验证失败: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description='配置管理工具 - 管理项目 .env 配置',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
  python scripts/manage-config.py show        # 显示所有配置
  python scripts/manage-config.py validate    # 验证配置完整性
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='可用命令')
    
    # show 命令
    show_parser = subparsers.add_parser('show', help='显示配置信息')
    
    # validate 命令
    validate_parser = subparsers.add_parser('validate', help='验证配置完整性')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # 切换到项目根目录
    import os
    os.chdir(project_root)
    
    if args.command == 'show':
        success = show_config()
        sys.exit(0 if success else 1)
        
    elif args.command == 'validate':
        success = validate_config()
        sys.exit(0 if success else 1)

if __name__ == '__main__':
    main() 