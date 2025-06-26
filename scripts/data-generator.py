#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TPC-DS 数据生成器
作者：Vance Chen
用于模拟实时的销售和退货数据，测试流式处理能力
"""

import mysql.connector
import random
import time
import datetime
from decimal import Decimal
import threading
import argparse
import json
import os
import sys
from pathlib import Path

# 加载配置
def load_db_config():
    """加载数据库配置"""
    # 添加config目录到Python路径
    config_dir = Path(__file__).parent.parent / "config"
    sys.path.append(str(config_dir))
    
    try:
        from config_loader import ConfigLoader
        loader = ConfigLoader()
        mysql_config = loader.get_connection_params('mysql')
        app_config = loader.load_all_configs()
        
        return {
            'db': {
                'host': mysql_config.get('host', 'localhost'),
                'port': int(mysql_config.get('port', 3306)),
                'user': mysql_config.get('username', 'flink_cdc'),
                'password': mysql_config.get('password', 'flink_cdc123'),
                'database': mysql_config.get('database', 'business_db')
            },
            'generator': {
                'batch_size': int(app_config.get('DATA_GENERATOR_BATCH_SIZE', 1000)),
                'interval': int(app_config.get('DATA_GENERATOR_INTERVAL', 5)),
                'max_records': int(app_config.get('DATA_GENERATOR_MAX_RECORDS', 0)),
                'threads': int(app_config.get('DATA_GENERATOR_THREADS', 2))
            }
        }
    except ImportError:
        # 如果配置加载器不可用，使用环境变量或默认配置
        print("警告：无法加载配置文件，使用环境变量或默认配置")
        return {
            'db': {
                'host': os.getenv('MYSQL_HOST', 'localhost'),
                'port': int(os.getenv('MYSQL_PORT', 3306)),
                'user': os.getenv('MYSQL_CDC_USER', 'flink_cdc'),
                'password': os.getenv('MYSQL_CDC_PASSWORD', 'flink_cdc123'),
                'database': os.getenv('MYSQL_DATABASE', 'business_db')
            },
            'generator': {
                'batch_size': int(os.getenv('DATA_GENERATOR_BATCH_SIZE', 1000)),
                'interval': int(os.getenv('DATA_GENERATOR_INTERVAL', 5)),
                'max_records': int(os.getenv('DATA_GENERATOR_MAX_RECORDS', 0)),
                'threads': int(os.getenv('DATA_GENERATOR_THREADS', 2))
            }
        }

class TPCDSDataGenerator:
    def __init__(self, host='localhost', port=3306, user='root', password='root123', database='business_db'):
        """初始化数据生成器"""
        self.config = {
            'host': host,
            'port': port,
            'user': user,
            'password': password,
            'database': database
        }
        self.connection = None
        self.running = False
        
    def connect(self):
        """连接到MySQL数据库"""
        try:
            self.connection = mysql.connector.connect(**self.config)
            print(f"✅ 成功连接到MySQL数据库: {self.config['host']}:{self.config['port']}")
            return True
        except mysql.connector.Error as err:
            print(f"❌ 数据库连接失败: {err}")
            return False
    
    def disconnect(self):
        """断开数据库连接"""
        if self.connection and self.connection.is_connected():
            self.connection.close()
            print("🔌 数据库连接已断开")
    
    def generate_random_sales_record(self):
        """生成随机销售记录"""
        current_date = datetime.datetime.now()
        date_sk = int(current_date.strftime('%Y%m%d'))
        time_sk = current_date.hour * 3600 + current_date.minute * 60 + current_date.second
        
        # 随机生成业务字段
        item_sk = random.randint(1000, 9999)
        customer_sk = random.randint(10000, 99999)
        store_sk = random.randint(100, 999)
        ticket_number = random.randint(1000000, 9999999)
        quantity = random.randint(1, 10)
        
        # 价格相关字段
        wholesale_cost = round(random.uniform(10.0, 200.0), 2)
        list_price = round(wholesale_cost * random.uniform(1.5, 3.0), 2)
        sales_price = round(list_price * random.uniform(0.7, 0.95), 2)
        ext_sales_price = round(sales_price * quantity, 2)
        tax_rate = 0.08
        ext_tax = round(ext_sales_price * tax_rate, 2)
        net_paid = ext_sales_price
        net_paid_inc_tax = round(net_paid + ext_tax, 2)
        net_profit = round(ext_sales_price - (wholesale_cost * quantity), 2)
        
        return {
            'ss_sold_date_sk': date_sk,
            'ss_sold_time_sk': time_sk,
            'ss_item_sk': item_sk,
            'ss_customer_sk': customer_sk,
            'ss_store_sk': store_sk,
            'ss_ticket_number': ticket_number,
            'ss_quantity': quantity,
            'ss_wholesale_cost': wholesale_cost,
            'ss_list_price': list_price,
            'ss_sales_price': sales_price,
            'ss_ext_sales_price': ext_sales_price,
            'ss_ext_tax': ext_tax,
            'ss_net_paid': net_paid,
            'ss_net_paid_inc_tax': net_paid_inc_tax,
            'ss_net_profit': net_profit
        }
    
    def generate_random_return_record(self, sales_ticket=None):
        """生成随机退货记录"""
        current_date = datetime.datetime.now()
        date_sk = int(current_date.strftime('%Y%m%d'))
        time_sk = current_date.hour * 3600 + current_date.minute * 60 + current_date.second
        
        # 基于现有销售或随机生成
        if sales_ticket:
            item_sk = sales_ticket['ss_item_sk']
            customer_sk = sales_ticket['ss_customer_sk']
            store_sk = sales_ticket['ss_store_sk']
            ticket_number = sales_ticket['ss_ticket_number']
            return_quantity = min(random.randint(1, 3), sales_ticket['ss_quantity'])
        else:
            item_sk = random.randint(1000, 9999)
            customer_sk = random.randint(10000, 99999)
            store_sk = random.randint(100, 999)
            ticket_number = random.randint(1000000, 9999999)
            return_quantity = random.randint(1, 5)
        
        # 退货金额
        return_amt = round(random.uniform(20.0, 500.0), 2)
        return_tax = round(return_amt * 0.08, 2)
        return_amt_inc_tax = round(return_amt + return_tax, 2)
        refunded_cash = return_amt_inc_tax
        net_loss = round(random.uniform(10.0, 100.0), 2)
        
        return {
            'sr_returned_date_sk': date_sk,
            'sr_return_time_sk': time_sk,
            'sr_item_sk': item_sk,
            'sr_customer_sk': customer_sk,
            'sr_store_sk': store_sk,
            'sr_ticket_number': ticket_number,
            'sr_return_quantity': return_quantity,
            'sr_return_amt': return_amt,
            'sr_return_tax': return_tax,
            'sr_return_amt_inc_tax': return_amt_inc_tax,
            'sr_refunded_cash': refunded_cash,
            'sr_net_loss': net_loss
        }
    
    def insert_sales_record(self, record):
        """插入销售记录"""
        sql = """
        INSERT INTO store_sales (
            ss_sold_date_sk, ss_sold_time_sk, ss_item_sk, ss_customer_sk,
            ss_store_sk, ss_ticket_number, ss_quantity, ss_wholesale_cost,
            ss_list_price, ss_sales_price, ss_ext_sales_price, ss_ext_tax,
            ss_net_paid, ss_net_paid_inc_tax, ss_net_profit
        ) VALUES (
            %(ss_sold_date_sk)s, %(ss_sold_time_sk)s, %(ss_item_sk)s, %(ss_customer_sk)s,
            %(ss_store_sk)s, %(ss_ticket_number)s, %(ss_quantity)s, %(ss_wholesale_cost)s,
            %(ss_list_price)s, %(ss_sales_price)s, %(ss_ext_sales_price)s, %(ss_ext_tax)s,
            %(ss_net_paid)s, %(ss_net_paid_inc_tax)s, %(ss_net_profit)s
        )
        """
        cursor = self.connection.cursor()
        cursor.execute(sql, record)
        self.connection.commit()
        cursor.close()
        return cursor.lastrowid
    
    def insert_return_record(self, record):
        """插入退货记录"""
        sql = """
        INSERT INTO store_returns (
            sr_returned_date_sk, sr_return_time_sk, sr_item_sk, sr_customer_sk,
            sr_store_sk, sr_ticket_number, sr_return_quantity, sr_return_amt,
            sr_return_tax, sr_return_amt_inc_tax, sr_refunded_cash, sr_net_loss
        ) VALUES (
            %(sr_returned_date_sk)s, %(sr_return_time_sk)s, %(sr_item_sk)s, %(sr_customer_sk)s,
            %(sr_store_sk)s, %(sr_ticket_number)s, %(sr_return_quantity)s, %(sr_return_amt)s,
            %(sr_return_tax)s, %(sr_return_amt_inc_tax)s, %(sr_refunded_cash)s, %(sr_net_loss)s
        )
        """
        cursor = self.connection.cursor()
        cursor.execute(sql, record)
        self.connection.commit()
        cursor.close()
        return cursor.lastrowid
    
    def start_continuous_generation(self, sales_interval=2, return_interval=10, return_probability=0.1):
        """开始连续数据生成"""
        self.running = True
        print(f"🚀 开始连续数据生成...")
        print(f"   销售数据间隔: {sales_interval}秒")
        print(f"   退货数据间隔: {return_interval}秒")
        print(f"   退货概率: {return_probability * 100}%")
        
        sales_count = 0
        return_count = 0
        
        try:
            while self.running:
                # 生成销售数据
                sales_record = self.generate_random_sales_record()
                record_id = self.insert_sales_record(sales_record)
                sales_count += 1
                print(f"📊 生成销售记录 #{sales_count}: 票据号 {sales_record['ss_ticket_number']}, "
                      f"商品 {sales_record['ss_item_sk']}, 金额 {sales_record['ss_ext_sales_price']}")
                
                # 随机生成退货数据
                if random.random() < return_probability:
                    return_record = self.generate_random_return_record(sales_record)
                    self.insert_return_record(return_record)
                    return_count += 1
                    print(f"🔄 生成退货记录 #{return_count}: 票据号 {return_record['sr_ticket_number']}, "
                          f"退货金额 {return_record['sr_return_amt']}")
                
                time.sleep(sales_interval)
                
        except KeyboardInterrupt:
            print(f"\n⏹️  数据生成已停止")
            print(f"📈 总计生成: 销售记录 {sales_count} 条, 退货记录 {return_count} 条")
        except Exception as e:
            print(f"❌ 数据生成错误: {e}")
        finally:
            self.running = False
    
    def stop_generation(self):
        """停止数据生成"""
        self.running = False

def main():
    parser = argparse.ArgumentParser(description='TPC-DS 数据生成器')
    parser.add_argument('--host', default='localhost', help='MySQL主机地址')
    parser.add_argument('--port', type=int, default=3306, help='MySQL端口')
    parser.add_argument('--user', default='root', help='MySQL用户名')
    parser.add_argument('--password', default='root123', help='MySQL密码')
    parser.add_argument('--database', default='business_db', help='数据库名')
    parser.add_argument('--sales-interval', type=int, default=2, help='销售数据生成间隔(秒)')
    parser.add_argument('--return-interval', type=int, default=10, help='退货数据生成间隔(秒)')
    parser.add_argument('--return-probability', type=float, default=0.1, help='退货概率(0-1)')
    
    args = parser.parse_args()
    
    # 创建数据生成器
    generator = TPCDSDataGenerator(
        host=args.host,
        port=args.port,
        user=args.user,
        password=args.password,
        database=args.database
    )
    
    # 连接数据库
    if not generator.connect():
        return
    
    try:
        # 开始生成数据
        generator.start_continuous_generation(
            sales_interval=args.sales_interval,
            return_interval=args.return_interval,
            return_probability=args.return_probability
        )
    finally:
        generator.disconnect()

if __name__ == '__main__':
    main() 