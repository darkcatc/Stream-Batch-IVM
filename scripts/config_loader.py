#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
配置加载器 - 简化版
作者：Vance Chen
统一从 .env 文件读取配置
"""

import os
from typing import Dict, Any
from pathlib import Path


class ConfigLoader:
    """简化的配置加载器，直接读取 .env 文件"""
    
    def __init__(self, env_file: str = ".env"):
        """
        初始化配置加载器
        
        Args:
            env_file: .env 文件路径
        """
        self.project_root = Path(__file__).parent.parent
        self.env_file = self.project_root / env_file
        self.config_data: Dict[str, str] = {}
        
    def load_env_file(self) -> Dict[str, str]:
        """
        加载 .env 文件
        
        Returns:
            配置字典
        """
        config = {}
        
        if not self.env_file.exists():
            print(f"警告：配置文件 {self.env_file} 不存在")
            return config
            
        try:
            with open(self.env_file, 'r', encoding='utf-8') as f:
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
                        print(f"警告：配置文件第 {line_num} 行格式不正确：{line}")
                        
        except Exception as e:
            print(f"错误：读取配置文件 {self.env_file} 失败：{e}")
            
        return config
    
    def load_all_configs(self) -> Dict[str, str]:
        """
        加载所有配置
        
        Returns:
            合并后的配置字典
        """
        config = self.load_env_file()
        
        # 合并环境变量（环境变量优先级更高）
        for key, value in config.items():
            if key in os.environ:
                config[key] = os.environ[key]
                
        return config
    
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
                'host': all_config.get('CLOUDBERRY_HOST', '127.0.0.1'),
                'port': all_config.get('CLOUDBERRY_PORT', '15432'),
                'database': all_config.get('CLOUDBERRY_DATABASE', 'gpadmin'),
                'schema': all_config.get('CLOUDBERRY_SCHEMA', 'tpcds'),
                'username': all_config.get('CLOUDBERRY_USER', 'gpadmin'),
                'password': all_config.get('CLOUDBERRY_PASSWORD', 'hashdata@123'),
                'jdbc_url': all_config.get('CLOUDBERRY_JDBC_URL', 
                    f"jdbc:postgresql://{all_config.get('CLOUDBERRY_HOST', '127.0.0.1')}:{all_config.get('CLOUDBERRY_PORT', '15432')}/{all_config.get('CLOUDBERRY_DATABASE', 'gpadmin')}")
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
    
    def get_config(self, key: str, default: str = "") -> str:
        """
        获取指定配置项
        
        Args:
            key: 配置键
            default: 默认值
            
        Returns:
            配置值
        """
        all_config = self.load_all_configs()
        return all_config.get(key, default)
    
    def get_data_generator_config(self) -> Dict[str, Any]:
        """
        获取数据生成器配置
        
        Returns:
            数据生成器配置字典
        """
        all_config = self.load_all_configs()
        
        return {
            'batch_size': int(all_config.get('DATA_GENERATOR_BATCH_SIZE', '1000')),
            'interval': int(all_config.get('DATA_GENERATOR_INTERVAL', '5')),
            'max_records': int(all_config.get('DATA_GENERATOR_MAX_RECORDS', '0')),
            'threads': int(all_config.get('DATA_GENERATOR_THREADS', '2'))
        }


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