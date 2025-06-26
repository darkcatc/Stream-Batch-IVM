#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
配置管理脚本
作者：Vance Chen
提供统一的配置管理功能：查看、验证、生成SQL文件等
"""

import os
import sys
import argparse
from pathlib import Path

# 添加config目录到Python路径
project_root = Path(__file__).parent.parent
config_dir = project_root / "config"
sys.path.append(str(config_dir))

try:
    from config_loader import ConfigLoader
except ImportError:
    print("错误：无法导入配置加载器，请确保config目录下有config_loader.py文件")
    sys.exit(1)


def show_config(service=None):
    """显示配置信息"""
    loader = ConfigLoader()
    
    if service:
        print(f"=== {service.upper()} 配置 ===")
        params = loader.get_connection_params(service)
        if not params:
            print(f"未找到服务 '{service}' 的配置")
            return
            
        for key, value in params.items():
            # 隐藏密码
            if 'password' in key.lower():
                display_value = '*' * len(str(value)) if value else '(未设置)'
            else:
                display_value = value
            print(f"  {key}: {display_value}")
    else:
        print("=== 所有配置摘要 ===")
        services = ['mysql', 'cloudberry', 'kafka', 'flink']
        
        for svc in services:
            print(f"\n{svc.upper()} 配置:")
            params = loader.get_connection_params(svc)
            for key, value in params.items():
                # 隐藏密码
                if 'password' in key.lower():
                    display_value = '*' * len(str(value)) if value else '(未设置)'
                else:
                    display_value = value
                print(f"  {key}: {display_value}")


def validate_config():
    """验证配置完整性"""
    loader = ConfigLoader()
    
    print("=== 配置验证 ===")
    
    try:
        config = loader.load_all_configs()
        
        # 必需的配置项
        required_configs = {
            'MySQL': [
                'MYSQL_HOST', 'MYSQL_PORT', 'MYSQL_CDC_USER', 
                'MYSQL_CDC_PASSWORD', 'MYSQL_DATABASE'
            ],
            'Cloudberry': [
                'CLOUDBERRY_HOST', 'CLOUDBERRY_PORT', 'CLOUDBERRY_USER', 
                'CLOUDBERRY_PASSWORD', 'CLOUDBERRY_DATABASE'
            ],
            'Kafka': [
                'KAFKA_HOST', 'KAFKA_INTERNAL_PORT', 'KAFKA_EXTERNAL_PORT'
            ],
            'Flink': [
                'FLINK_JOBMANAGER_HOST', 'FLINK_PARALLELISM_DEFAULT',
                'FLINK_CHECKPOINT_INTERVAL'
            ]
        }
        
        all_valid = True
        
        for service, configs in required_configs.items():
            print(f"\n{service}:")
            missing_configs = []
            
            for req_config in configs:
                if req_config not in config or not config[req_config]:
                    missing_configs.append(req_config)
                    
            if missing_configs:
                print(f"  ✗ 缺少配置: {missing_configs}")
                all_valid = False
            else:
                print(f"  ✓ 所有必需配置都已设置")
                
        if all_valid:
            print(f"\n✓ 所有服务配置验证通过")
            return True
        else:
            print(f"\n✗ 配置验证失败，请检查缺少的配置项")
            return False
            
    except Exception as e:
        print(f"✗ 配置验证失败: {e}")
        return False


def generate_sql_configs():
    """生成SQL配置文件"""
    loader = ConfigLoader()
    
    print("=== 生成Flink SQL配置文件 ===")
    
    # 模板映射
    templates = [
        {
            'template': 'flink-sql/templates/mysql-cdc-to-cloudberry.template.sql',
            'output': 'flink-sql/mysql-cdc-to-cloudberry.sql',
            'name': 'MySQL CDC 到 Cloudberry 同步'
        }
    ]
    
    success_count = 0
    for template_info in templates:
        template_path = project_root / template_info['template']
        output_path = project_root / template_info['output']
        
        print(f"\n处理: {template_info['name']}")
        
        try:
            if not template_path.exists():
                print(f"  ✗ 模板文件不存在: {template_path}")
                continue
                
            # 加载配置
            config = loader.load_all_configs()
            
            # 读取模板
            with open(template_path, 'r', encoding='utf-8') as f:
                template_content = f.read()
                
            # 替换变量
            generated_content = template_content
            for key, value in config.items():
                placeholder = f'${{{key}}}'
                if placeholder in generated_content:
                    generated_content = generated_content.replace(placeholder, str(value))
                    
            # 检查未解析的变量
            import re
            unresolved_vars = re.findall(r'\$\{([^}]+)\}', generated_content)
            if unresolved_vars:
                print(f"  ⚠️  警告：未解析的变量: {unresolved_vars}")
                
            # 创建输出目录
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # 写入文件
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(generated_content)
                
            print(f"  ✓ 生成成功: {output_path}")
            success_count += 1
            
        except Exception as e:
            print(f"  ✗ 生成失败: {e}")
            
    print(f"\n生成完成: {success_count}/{len(templates)} 个文件")
    return success_count == len(templates)


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='配置管理工具')
    subparsers = parser.add_subparsers(dest='command', help='可用命令')
    
    # show命令
    show_parser = subparsers.add_parser('show', help='显示配置')
    show_parser.add_argument('--service', choices=['mysql', 'cloudberry', 'kafka', 'flink'], 
                           help='指定服务')
    
    # validate命令
    subparsers.add_parser('validate', help='验证配置')
    
    # generate命令
    subparsers.add_parser('generate', help='生成SQL配置文件')
    
    args = parser.parse_args()
    
    if args.command == 'show':
        show_config(args.service)
    elif args.command == 'validate':
        success = validate_config()
        sys.exit(0 if success else 1)
    elif args.command == 'generate':
        success = generate_sql_configs()
        sys.exit(0 if success else 1)
    else:
        parser.print_help()


if __name__ == "__main__":
    main() 