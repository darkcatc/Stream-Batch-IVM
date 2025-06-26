#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Flink SQL 配置生成器
作者：Vance Chen
从模板生成配置化的 Flink SQL 文件
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


def generate_flink_configs():
    """生成所有Flink SQL配置文件"""
    
    # 获取项目根目录
    project_root = Path(__file__).parent.parent
    
    # 初始化配置加载器
    loader = ConfigLoader(str(project_root / "config"))
    
    # 定义模板和输出映射
    template_mappings = [
        {
            'template': 'flink-sql/templates/mysql-cdc-to-cloudberry.template.sql',
            'output': 'flink-sql/mysql-cdc-to-cloudberry.sql',
            'description': 'MySQL CDC 到 Cloudberry 直接同步'
        },
        # 可以添加更多模板映射
    ]
    
    print("=== Flink SQL 配置文件生成器 ===")
    print(f"项目根目录: {project_root}")
    
    # 加载配置
    try:
        config = loader.load_all_configs()
        print(f"已加载配置项: {len(config)} 个")
    except Exception as e:
        print(f"错误：加载配置失败 - {e}")
        return False
    
    # 生成配置文件
    success_count = 0
    for mapping in template_mappings:
        template_path = project_root / mapping['template']
        output_path = project_root / mapping['output']
        
        print(f"\n正在处理: {mapping['description']}")
        print(f"模板文件: {template_path}")
        print(f"输出文件: {output_path}")
        
        try:
            # 检查模板文件是否存在
            if not template_path.exists():
                print(f"警告：模板文件不存在 - {template_path}")
                continue
                
            # 读取模板内容
            with open(template_path, 'r', encoding='utf-8') as f:
                template_content = f.read()
            
            # 替换配置变量
            generated_content = template_content
            for key, value in config.items():
                placeholder = f'${{{key}}}'
                if placeholder in generated_content:
                    generated_content = generated_content.replace(placeholder, str(value))
                    
            # 检查是否还有未替换的变量
            import re
            unresolved_vars = re.findall(r'\$\{([^}]+)\}', generated_content)
            if unresolved_vars:
                print(f"警告：发现未解析的变量: {unresolved_vars}")
                
            # 确保输出目录存在
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # 写入生成的文件
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(generated_content)
                
            print(f"✓ 成功生成: {output_path}")
            success_count += 1
            
        except Exception as e:
            print(f"✗ 生成失败: {e}")
            
    print(f"\n=== 生成完成 ===")
    print(f"成功生成: {success_count}/{len(template_mappings)} 个文件")
    
    return success_count == len(template_mappings)


def show_config_summary():
    """显示配置摘要"""
    project_root = Path(__file__).parent.parent
    loader = ConfigLoader(str(project_root / "config"))
    
    print("=== 当前配置摘要 ===")
    
    # 显示各服务的连接参数
    services = ['mysql', 'cloudberry', 'kafka', 'flink']
    
    for service in services:
        print(f"\n{service.upper()} 配置:")
        params = loader.get_connection_params(service)
        for key, value in params.items():
            # 隐藏密码
            if 'password' in key.lower():
                display_value = '*' * len(str(value)) if value else '(未设置)'
            else:
                display_value = value
            print(f"  {key}: {display_value}")


def validate_configs():
    """验证配置的完整性"""
    project_root = Path(__file__).parent.parent
    loader = ConfigLoader(str(project_root / "config"))
    
    print("=== 配置验证 ===")
    
    try:
        config = loader.load_all_configs()
        
        # 必需的配置项
        required_configs = [
            'MYSQL_HOST', 'MYSQL_PORT', 'MYSQL_CDC_USER', 'MYSQL_CDC_PASSWORD',
            'CLOUDBERRY_HOST', 'CLOUDBERRY_PORT', 'CLOUDBERRY_USER', 'CLOUDBERRY_PASSWORD',
            'KAFKA_HOST', 'KAFKA_INTERNAL_PORT',
            'FLINK_JOBMANAGER_HOST', 'FLINK_PARALLELISM_DEFAULT'
        ]
        
        missing_configs = []
        for req_config in required_configs:
            if req_config not in config or not config[req_config]:
                missing_configs.append(req_config)
                
        if missing_configs:
            print(f"✗ 缺少必需配置: {missing_configs}")
            return False
        else:
            print("✓ 所有必需配置项都已设置")
            return True
            
    except Exception as e:
        print(f"✗ 配置验证失败: {e}")
        return False


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='Flink SQL 配置生成器')
    parser.add_argument('action', choices=['generate', 'validate', 'show'], 
                       help='操作类型: generate(生成配置), validate(验证配置), show(显示配置)')
    
    args = parser.parse_args()
    
    if args.action == 'generate':
        success = generate_flink_configs()
        sys.exit(0 if success else 1)
    elif args.action == 'validate':
        success = validate_configs()
        sys.exit(0 if success else 1)
    elif args.action == 'show':
        show_config_summary()
        sys.exit(0)


if __name__ == "__main__":
    main() 