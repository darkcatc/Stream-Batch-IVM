#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
配置加载器
作者：Vance Chen
用于解析和合并配置文件，支持环境变量替换
"""

import os
import re
from typing import Dict, Any, Optional
from pathlib import Path


class ConfigLoader:
    """配置加载器，支持多文件合并和环境变量替换"""
    
    def __init__(self, config_dir: str = "config"):
        """
        初始化配置加载器
        
        Args:
            config_dir: 配置文件目录
        """
        self.config_dir = Path(config_dir)
        self.config_data: Dict[str, Any] = {}
        
    def load_env_file(self, file_path: str) -> Dict[str, str]:
        """
        加载单个.env文件
        
        Args:
            file_path: 配置文件路径
            
        Returns:
            配置字典
        """
        config = {}
        env_path = self.config_dir / file_path
        
        if not env_path.exists():
            print(f"警告：配置文件 {env_path} 不存在")
            return config
            
        try:
            with open(env_path, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    
                    # 跳过注释和空行
                    if not line or line.startswith('#'):
                        continue
                        
                    # 解析键值对
                    if '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip()
                        
                        # 移除引号
                        if value.startswith('"') and value.endswith('"'):
                            value = value[1:-1]
                        elif value.startswith("'") and value.endswith("'"):
                            value = value[1:-1]
                            
                        config[key] = value
                    else:
                        print(f"警告：配置文件 {file_path} 第 {line_num} 行格式不正确：{line}")
                        
        except Exception as e:
            print(f"错误：读取配置文件 {file_path} 失败：{e}")
            
        return config
    
    def load_all_configs(self) -> Dict[str, str]:
        """
        加载所有配置文件
        
        Returns:
            合并后的配置字典
        """
        config_files = [
            "application.env",
            "database.env", 
            "kafka.env",
            "flink.env"
        ]
        
        merged_config = {}
        
        for config_file in config_files:
            file_config = self.load_env_file(config_file)
            merged_config.update(file_config)
            
        # 应用环境变量替换
        merged_config = self._resolve_variables(merged_config)
        
        return merged_config
    
    def _resolve_variables(self, config: Dict[str, str]) -> Dict[str, str]:
        """
        解析配置中的变量引用
        
        Args:
            config: 原始配置字典
            
        Returns:
            解析后的配置字典
        """
        resolved = config.copy()
        max_iterations = 10  # 防止循环引用
        
        for _ in range(max_iterations):
            changed = False
            for key, value in resolved.items():
                if isinstance(value, str):
                    # 查找 ${VAR} 模式
                    pattern = r'\$\{([^}]+)\}'
                    matches = re.findall(pattern, value)
                    
                    for match in matches:
                        # 支持默认值：${VAR:-default}
                        if ':-' in match:
                            var_name, default_value = match.split(':-', 1)
                        else:
                            var_name = match
                            default_value = ''
                            
                        # 优先使用环境变量，然后是配置文件中的值
                        replacement = os.environ.get(var_name) or resolved.get(var_name, default_value)
                        
                        old_value = value
                        value = value.replace(f'${{{match}}}', replacement)
                        
                        if old_value != value:
                            changed = True
                            
                    resolved[key] = value
                    
            if not changed:
                break
                
        return resolved
    
    def get_connection_params(self, service: str) -> Dict[str, str]:
        """
        获取指定服务的连接参数
        
        Args:
            service: 服务名称 (mysql, cloudberry, kafka, flink)
            
        Returns:
            连接参数字典
        """
        all_config = self.load_all_configs()
        
        service_configs = {
            'mysql': {
                'host': all_config.get('MYSQL_HOST', 'mysql'),
                'port': all_config.get('MYSQL_PORT', '3306'),
                'database': all_config.get('MYSQL_DATABASE', 'business_db'),
                'username': all_config.get('MYSQL_CDC_USER', 'flink_cdc'),
                'password': all_config.get('MYSQL_CDC_PASSWORD', 'flink_cdc123'),
                'timezone': all_config.get('TIMEZONE', 'Asia/Shanghai')
            },
            'cloudberry': {
                'host': all_config.get('CLOUDBERRY_HOST', 'cloudberry-host'),
                'port': all_config.get('CLOUDBERRY_PORT', '15432'),
                'database': all_config.get('CLOUDBERRY_DATABASE', 'tpcds_db'),
                'schema': all_config.get('CLOUDBERRY_SCHEMA', 'tpcds'),
                'username': all_config.get('CLOUDBERRY_USER', 'gpadmin'),
                'password': all_config.get('CLOUDBERRY_PASSWORD', 'gpadmin'),
                'jdbc_url': all_config.get('CLOUDBERRY_JDBC_URL', 
                    f"jdbc:postgresql://{all_config.get('CLOUDBERRY_HOST', 'cloudberry-host')}:{all_config.get('CLOUDBERRY_PORT', '15432')}/{all_config.get('CLOUDBERRY_DATABASE', 'tpcds_db')}")
            },
            'kafka': {
                'host': all_config.get('KAFKA_HOST', 'kafka'),
                'internal_port': all_config.get('KAFKA_INTERNAL_PORT', '29092'),
                'external_port': all_config.get('KAFKA_EXTERNAL_PORT', '9092'),
                'bootstrap_servers': f"{all_config.get('KAFKA_HOST', 'kafka')}:{all_config.get('KAFKA_INTERNAL_PORT', '29092')}"
            },
            'flink': {
                'jobmanager_host': all_config.get('FLINK_JOBMANAGER_HOST', 'flink-jobmanager'),
                'web_port': all_config.get('FLINK_JOBMANAGER_WEB_PORT', '8081'),
                'parallelism': all_config.get('FLINK_PARALLELISM_DEFAULT', '2'),
                'checkpoint_interval': all_config.get('FLINK_CHECKPOINT_INTERVAL', '60000')
            }
        }
        
        return service_configs.get(service, {})
    
    def generate_sql_config(self, template_path: str, output_path: str, **kwargs) -> None:
        """
        生成配置化的SQL文件
        
        Args:
            template_path: 模板文件路径
            output_path: 输出文件路径
            **kwargs: 额外的模板变量
        """
        config = self.load_all_configs()
        config.update(kwargs)
        
        try:
            with open(template_path, 'r', encoding='utf-8') as f:
                template_content = f.read()
                
            # 替换模板变量
            for key, value in config.items():
                template_content = template_content.replace(f'${{{key}}}', str(value))
                
            # 确保输出目录存在
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(template_content)
                
            print(f"已生成配置化SQL文件：{output_path}")
            
        except Exception as e:
            print(f"错误：生成SQL配置文件失败：{e}")


if __name__ == "__main__":
    # 测试配置加载器
    loader = ConfigLoader()
    
    print("=== 所有配置 ===")
    all_config = loader.load_all_configs()
    for key, value in sorted(all_config.items()):
        print(f"{key}={value}")
        
    print("\n=== MySQL 连接参数 ===")
    mysql_params = loader.get_connection_params('mysql')
    for key, value in mysql_params.items():
        print(f"{key}: {value}")
        
    print("\n=== Cloudberry 连接参数 ===")
    cloudberry_params = loader.get_connection_params('cloudberry')
    for key, value in cloudberry_params.items():
        print(f"{key}: {value}") 