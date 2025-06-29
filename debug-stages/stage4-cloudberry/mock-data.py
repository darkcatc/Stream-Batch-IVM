#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Stream-Batch-IVM Cloudberry数据生成器 (CDC模式)
作者：Vance Chen

用于向Cloudberry数据库生成TPC-DS模型的模拟数据
模拟MySQL CDC数据流，支持INSERT、UPDATE、DELETE操作
支持store_returns_heap和store_sales_heap表的数据生成
"""

import os
import sys
import random
import psycopg2
import logging
import time
from datetime import datetime, timedelta
from decimal import Decimal
from typing import List, Tuple, Optional, Dict, Set
from dataclasses import dataclass
import argparse
from enum import Enum

# 设置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mock-data.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class OperationType(Enum):
    """CDC操作类型"""
    INSERT = "INSERT"
    UPDATE = "UPDATE" 
    DELETE = "DELETE"

@dataclass
class CloudberryConfig:
    """Cloudberry数据库连接配置"""
    host: str
    port: int
    database: str
    user: str
    password: str
    schema: str

@dataclass
class CDCOperation:
    """CDC操作数据结构"""
    operation_type: OperationType
    table_name: str
    data: Tuple
    old_data: Optional[Tuple] = None  # 用于UPDATE操作的旧数据

class CDCDataGenerator:
    """TPC-DS CDC数据生成器"""
    
    def __init__(self, config: CloudberryConfig):
        self.config = config
        self.conn = None
        self.cursor = None
        
        # TPC-DS维度数据范围配置
        # 动态获取当天的日期作为销售/退货日期
        today_julian = self._get_today_julian()
        self.date_sk_range = (today_julian, today_julian)  # 使用当天日期
        self.time_sk_range = (0, 86399)  # 一天的秒数
        self.item_sk_range = (1, 18000)  # 商品范围
        self.customer_sk_range = (1, 100000)  # 客户范围
        self.store_sk_range = (1, 12)  # 商店范围
        self.promo_sk_range = (1, 300)  # 促销范围
        self.reason_sk_range = (1, 35)  # 退货原因范围
        
        # 人口统计学维度范围
        self.cdemo_sk_range = (1, 1920800)  # 客户人口统计
        self.hdemo_sk_range = (1, 7200)  # 家庭人口统计
        self.addr_sk_range = (1, 50000)  # 地址范围
        
        # CDC相关配置
        self.micro_batch_size = 200  # 微批量大小
        self.update_delete_frequency = 800  # 每800条中有1-2条UPDATE/DELETE
        self.batch_interval = 2  # 批次间隔（秒）
        
        # 跟踪已存在的记录ID，用于UPDATE/DELETE操作
        self.existing_sales_ids: Set[int] = set()
        self.existing_returns_ids: Set[int] = set()
        
        # 操作计数器
        self.operation_counter = 0
    
    def _get_today_julian(self) -> int:
        """获取当天日期对应的儒略日"""
        today = datetime.now().date()
        # 转换日期为儒略日
        a = (14 - today.month) // 12
        y = today.year + 4800 - a
        m = today.month + 12 * a - 3
        julian_day = today.day + (153 * m + 2) // 5 + 365 * y + y // 4 - y // 100 + y // 400 - 32045
        return julian_day
    
    def connect(self) -> bool:
        """连接到Cloudberry数据库"""
        try:
            self.conn = psycopg2.connect(
                host=self.config.host,
                port=self.config.port,
                database=self.config.database,
                user=self.config.user,
                password=self.config.password
            )
            self.cursor = self.conn.cursor()
            logger.info(f"成功连接到Cloudberry数据库: {self.config.host}:{self.config.port}")
            return True
        except Exception as e:
            logger.error(f"连接Cloudberry数据库失败: {e}")
            return False
    
    def disconnect(self):
        """断开数据库连接"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        logger.info("数据库连接已关闭")
    
    def load_existing_ids(self):
        """加载数据库中已存在的记录ID"""
        if not self.cursor:
            return
            
        try:
            # 加载销售表的ID
            self.cursor.execute(f"SELECT ss_id FROM {self.config.schema}.store_sales_heap LIMIT 10000")
            sales_results = self.cursor.fetchall()
            self.existing_sales_ids = {row[0] for row in sales_results}
            
            # 加载退货表的ID
            self.cursor.execute(f"SELECT sr_id FROM {self.config.schema}.store_returns_heap LIMIT 10000")
            returns_results = self.cursor.fetchall()
            self.existing_returns_ids = {row[0] for row in returns_results}
            
            logger.info(f"加载已存在记录: 销售表 {len(self.existing_sales_ids)} 条, 退货表 {len(self.existing_returns_ids)} 条")
        except Exception as e:
            logger.warning(f"加载已存在记录ID失败: {e}")
    
    def determine_operation_type(self, table_name: str) -> OperationType:
        """根据频率确定操作类型"""
        self.operation_counter += 1
        
        # 每800条操作中有1-2条UPDATE/DELETE
        if self.operation_counter % self.update_delete_frequency == 0:
            # 确保有数据可以UPDATE/DELETE
            existing_ids = (self.existing_sales_ids if table_name == 'store_sales_heap' 
                          else self.existing_returns_ids)
            
            if existing_ids:
                # 随机选择UPDATE或DELETE
                return random.choice([OperationType.UPDATE, OperationType.DELETE])
        
        return OperationType.INSERT
    
    def generate_store_sales_data(self, batch_size: int = 200) -> List[CDCOperation]:
        """生成store_sales_heap表的CDC操作数据"""
        operations = []
        
        for i in range(batch_size):
            operation_type = self.determine_operation_type('store_sales_heap')
            
            if operation_type == OperationType.INSERT:
                # 生成新的销售记录
                data = self._create_sales_record(i)
                self.existing_sales_ids.add(data[0])  # 添加新ID到跟踪集合
                operations.append(CDCOperation(
                    operation_type=operation_type,
                    table_name='store_sales_heap',
                    data=data
                ))
                
            elif operation_type == OperationType.UPDATE and self.existing_sales_ids:
                # 更新现有记录
                old_id = random.choice(list(self.existing_sales_ids))
                old_data = self._get_sales_record_by_id(old_id)
                if old_data:
                    new_data = self._update_sales_record(old_data)
                    operations.append(CDCOperation(
                        operation_type=operation_type,
                        table_name='store_sales_heap',
                        data=new_data,
                        old_data=old_data
                    ))
                    
            elif operation_type == OperationType.DELETE and self.existing_sales_ids:
                # 删除现有记录
                delete_id = random.choice(list(self.existing_sales_ids))
                delete_data = self._get_sales_record_by_id(delete_id)
                if delete_data:
                    self.existing_sales_ids.remove(delete_id)
                    operations.append(CDCOperation(
                        operation_type=operation_type,
                        table_name='store_sales_heap',
                        data=delete_data
                    ))
            
            # 如果UPDATE/DELETE失败，生成INSERT操作作为备选
            if not operations or operations[-1].operation_type != operation_type:
                data = self._create_sales_record(i)
                self.existing_sales_ids.add(data[0])
                operations.append(CDCOperation(
                    operation_type=OperationType.INSERT,
                    table_name='store_sales_heap',
                    data=data
                ))
        
        return operations
    
    def generate_store_returns_data(self, batch_size: int = 200) -> List[CDCOperation]:
        """生成store_returns_heap表的CDC操作数据"""
        operations = []
        
        for i in range(batch_size):
            operation_type = self.determine_operation_type('store_returns_heap')
            
            if operation_type == OperationType.INSERT:
                # 生成新的退货记录
                data = self._create_returns_record(i)
                self.existing_returns_ids.add(data[0])
                operations.append(CDCOperation(
                    operation_type=operation_type,
                    table_name='store_returns_heap',
                    data=data
                ))
                
            elif operation_type == OperationType.UPDATE and self.existing_returns_ids:
                # 更新现有记录
                old_id = random.choice(list(self.existing_returns_ids))
                old_data = self._get_returns_record_by_id(old_id)
                if old_data:
                    new_data = self._update_returns_record(old_data)
                    operations.append(CDCOperation(
                        operation_type=operation_type,
                        table_name='store_returns_heap',
                        data=new_data,
                        old_data=old_data
                    ))
                    
            elif operation_type == OperationType.DELETE and self.existing_returns_ids:
                # 删除现有记录
                delete_id = random.choice(list(self.existing_returns_ids))
                delete_data = self._get_returns_record_by_id(delete_id)
                if delete_data:
                    self.existing_returns_ids.remove(delete_id)
                    operations.append(CDCOperation(
                        operation_type=operation_type,
                        table_name='store_returns_heap',
                        data=delete_data
                    ))
            
            # 如果UPDATE/DELETE失败，生成INSERT操作作为备选
            if not operations or operations[-1].operation_type != operation_type:
                data = self._create_returns_record(i)
                self.existing_returns_ids.add(data[0])
                operations.append(CDCOperation(
                    operation_type=OperationType.INSERT,
                    table_name='store_returns_heap',
                    data=data
                ))
        
        return operations
    
    def _create_sales_record(self, sequence: int) -> Tuple:
        """创建销售记录"""
        # 基础维度键
        sold_date_sk = random.randint(*self.date_sk_range)
        sold_time_sk = random.randint(*self.time_sk_range)
        item_sk = random.randint(*self.item_sk_range)
        customer_sk = random.randint(*self.customer_sk_range)
        store_sk = random.randint(*self.store_sk_range)
        
        # 人口统计学维度
        cdemo_sk = random.randint(*self.cdemo_sk_range)
        hdemo_sk = random.randint(*self.hdemo_sk_range)
        addr_sk = random.randint(*self.addr_sk_range)
        
        # 促销和票据
        promo_sk = random.randint(*self.promo_sk_range) if random.random() > 0.3 else None
        ticket_number = random.randint(1, 999999999)
        
        # 销售数量和价格
        quantity = random.randint(1, 100)
        list_price = Decimal(str(round(random.uniform(1.0, 500.0), 2)))
        wholesale_cost = list_price * Decimal(str(round(random.uniform(0.4, 0.8), 2)))
        sales_price = list_price * Decimal(str(round(random.uniform(0.5, 1.0), 2)))
        
        # 计算扩展金额
        ext_discount_amt = (list_price - sales_price) * quantity
        ext_sales_price = sales_price * quantity
        ext_wholesale_cost = wholesale_cost * quantity
        ext_list_price = list_price * quantity
        
        # 税费和优惠券
        ext_tax = ext_sales_price * Decimal(str(round(random.uniform(0.05, 0.15), 3)))
        coupon_amt = Decimal(str(round(random.uniform(0.0, 50.0), 2))) if random.random() > 0.7 else Decimal('0.00')
        
        # 净支付金额
        net_paid = ext_sales_price - coupon_amt
        net_paid_inc_tax = net_paid + ext_tax
        net_profit = net_paid - ext_wholesale_cost
        
        # 生成唯一ID
        ss_id = int(datetime.now().timestamp() * 1000000) + sequence
        
        return (
            ss_id, sold_date_sk, sold_time_sk, item_sk, customer_sk,
            cdemo_sk, hdemo_sk, addr_sk, store_sk, promo_sk,
            ticket_number, quantity, wholesale_cost, list_price,
            sales_price, ext_discount_amt, ext_sales_price,
            ext_wholesale_cost, ext_list_price, ext_tax,
            coupon_amt, net_paid, net_paid_inc_tax, net_profit
        )
    
    def _create_returns_record(self, sequence: int) -> Tuple:
        """创建退货记录"""
        # 基础维度键
        returned_date_sk = random.randint(*self.date_sk_range)
        return_time_sk = random.randint(*self.time_sk_range)
        item_sk = random.randint(*self.item_sk_range)
        customer_sk = random.randint(*self.customer_sk_range)
        store_sk = random.randint(*self.store_sk_range)
        
        # 人口统计学维度
        cdemo_sk = random.randint(*self.cdemo_sk_range)
        hdemo_sk = random.randint(*self.hdemo_sk_range)
        addr_sk = random.randint(*self.addr_sk_range)
        
        # 退货原因和票据
        reason_sk = random.randint(*self.reason_sk_range)
        ticket_number = random.randint(1, 999999999)
        
        # 退货数量和金额
        return_quantity = random.randint(1, 20)
        return_amt = Decimal(str(round(random.uniform(10.0, 200.0), 2)))
        return_tax = return_amt * Decimal(str(round(random.uniform(0.05, 0.15), 3)))
        return_amt_inc_tax = return_amt + return_tax
        
        # 费用和成本
        fee = Decimal(str(round(random.uniform(1.0, 15.0), 2)))
        return_ship_cost = Decimal(str(round(random.uniform(5.0, 25.0), 2)))
        
        # 退款方式（随机分配）
        total_refund = return_amt_inc_tax
        refunded_cash = total_refund * Decimal(str(round(random.uniform(0.0, 0.8), 2)))
        reversed_charge = (total_refund - refunded_cash) * Decimal(str(round(random.uniform(0.0, 0.7), 2)))
        store_credit = total_refund - refunded_cash - reversed_charge
        
        # 净损失
        net_loss = return_amt + fee + return_ship_cost
        
        # 生成唯一ID
        sr_id = int(datetime.now().timestamp() * 1000000) + sequence + 1000000
        
        return (
            sr_id, returned_date_sk, return_time_sk, item_sk, customer_sk,
            cdemo_sk, hdemo_sk, addr_sk, store_sk, reason_sk,
            ticket_number, return_quantity, return_amt, return_tax,
            return_amt_inc_tax, fee, return_ship_cost, refunded_cash,
            reversed_charge, store_credit, net_loss
        )
    
    def _get_sales_record_by_id(self, record_id: int) -> Optional[Tuple]:
        """根据ID获取销售记录"""
        if not self.cursor:
            return None
            
        try:
            self.cursor.execute(
                f"SELECT * FROM {self.config.schema}.store_sales_heap WHERE ss_id = %s",
                (record_id,)
            )
            result = self.cursor.fetchone()
            return result
        except Exception as e:
            logger.warning(f"获取销售记录失败: {e}")
            return None
    
    def _get_returns_record_by_id(self, record_id: int) -> Optional[Tuple]:
        """根据ID获取退货记录"""
        if not self.cursor:
            return None
            
        try:
            self.cursor.execute(
                f"SELECT * FROM {self.config.schema}.store_returns_heap WHERE sr_id = %s",
                (record_id,)
            )
            result = self.cursor.fetchone()
            return result
        except Exception as e:
            logger.warning(f"获取退货记录失败: {e}")
            return None
    
    def _update_sales_record(self, old_data: Tuple) -> Tuple:
        """更新销售记录（修改部分字段）"""
        data = list(old_data)
        
        # 随机更新一些字段
        if random.random() > 0.5:
            data[11] = random.randint(1, 100)  # ss_quantity
        if random.random() > 0.7:
            data[20] = Decimal(str(round(random.uniform(0.0, 50.0), 2)))  # ss_coupon_amt
        
        # 重新计算相关字段
        quantity = data[11]
        list_price = data[13]
        sales_price = data[14]
        coupon_amt = data[20]
        
        ext_sales_price = sales_price * quantity
        ext_tax = ext_sales_price * Decimal(str(round(random.uniform(0.05, 0.15), 3)))
        net_paid = ext_sales_price - coupon_amt
        net_paid_inc_tax = net_paid + ext_tax
        
        data[16] = ext_sales_price  # ss_ext_sales_price
        data[19] = ext_tax  # ss_ext_tax
        data[21] = net_paid  # ss_net_paid
        data[22] = net_paid_inc_tax  # ss_net_paid_inc_tax
        
        return tuple(data)
    
    def _update_returns_record(self, old_data: Tuple) -> Tuple:
        """更新退货记录（修改部分字段）"""
        data = list(old_data)
        
        # 随机更新一些字段
        if random.random() > 0.5:
            data[11] = random.randint(1, 20)  # sr_return_quantity
        if random.random() > 0.7:
            data[15] = Decimal(str(round(random.uniform(1.0, 15.0), 2)))  # sr_fee
        
        return tuple(data)
    
    def execute_cdc_operations(self, operations: List[CDCOperation]) -> bool:
        """执行CDC操作"""
        if not self.cursor or not self.conn:
            logger.error("数据库连接未建立")
            return False
        
        try:
            insert_count = update_count = delete_count = 0
            
            for operation in operations:
                if operation.operation_type == OperationType.INSERT:
                    self._execute_insert(operation)
                    insert_count += 1
                elif operation.operation_type == OperationType.UPDATE:
                    self._execute_update(operation)
                    update_count += 1
                elif operation.operation_type == OperationType.DELETE:
                    self._execute_delete(operation)
                    delete_count += 1
            
            self.conn.commit()
            logger.info(f"批次操作完成: INSERT={insert_count}, UPDATE={update_count}, DELETE={delete_count}")
            return True
            
        except Exception as e:
            logger.error(f"执行CDC操作失败: {e}")
            self.conn.rollback()
            return False
    
    def _execute_insert(self, operation: CDCOperation):
        """执行INSERT操作"""
        if not self.cursor:
            raise Exception("数据库连接未建立")
            
        if operation.table_name == 'store_sales_heap':
            sql = f"""
            INSERT INTO {self.config.schema}.store_sales_heap VALUES 
            (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
        else:  # store_returns_heap
            sql = f"""
            INSERT INTO {self.config.schema}.store_returns_heap VALUES 
            (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
        
        self.cursor.execute(sql, operation.data)
    
    def _execute_update(self, operation: CDCOperation):
        """执行UPDATE操作"""
        if not self.cursor:
            raise Exception("数据库连接未建立")
            
        if operation.table_name == 'store_sales_heap':
            sql = f"""
            UPDATE {self.config.schema}.store_sales_heap 
            SET ss_sold_date_sk=%s, ss_sold_time_sk=%s, ss_item_sk=%s, ss_customer_sk=%s,
                ss_cdemo_sk=%s, ss_hdemo_sk=%s, ss_addr_sk=%s, ss_store_sk=%s, ss_promo_sk=%s,
                ss_ticket_number=%s, ss_quantity=%s, ss_wholesale_cost=%s, ss_list_price=%s,
                ss_sales_price=%s, ss_ext_discount_amt=%s, ss_ext_sales_price=%s,
                ss_ext_wholesale_cost=%s, ss_ext_list_price=%s, ss_ext_tax=%s,
                ss_coupon_amt=%s, ss_net_paid=%s, ss_net_paid_inc_tax=%s, ss_net_profit=%s
            WHERE ss_id=%s
            """
            self.cursor.execute(sql, operation.data[1:] + (operation.data[0],))
        else:  # store_returns_heap
            sql = f"""
            UPDATE {self.config.schema}.store_returns_heap 
            SET sr_returned_date_sk=%s, sr_return_time_sk=%s, sr_item_sk=%s, sr_customer_sk=%s,
                sr_cdemo_sk=%s, sr_hdemo_sk=%s, sr_addr_sk=%s, sr_store_sk=%s, sr_reason_sk=%s,
                sr_ticket_number=%s, sr_return_quantity=%s, sr_return_amt=%s, sr_return_tax=%s,
                sr_return_amt_inc_tax=%s, sr_fee=%s, sr_return_ship_cost=%s, sr_refunded_cash=%s,
                sr_reversed_charge=%s, sr_store_credit=%s, sr_net_loss=%s
            WHERE sr_id=%s
            """
            self.cursor.execute(sql, operation.data[1:] + (operation.data[0],))
    
    def _execute_delete(self, operation: CDCOperation):
        """执行DELETE操作"""
        if not self.cursor:
            raise Exception("数据库连接未建立")
            
        if operation.table_name == 'store_sales_heap':
            sql = f"DELETE FROM {self.config.schema}.store_sales_heap WHERE ss_id = %s"
        else:  # store_returns_heap
            sql = f"DELETE FROM {self.config.schema}.store_returns_heap WHERE sr_id = %s"
        
        self.cursor.execute(sql, (operation.data[0],))
    
    def check_table_exists(self, table_name: str) -> bool:
        """检查表是否存在"""
        if not self.cursor:
            logger.error("数据库连接未建立")
            return False
            
        try:
            check_sql = """
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = %s AND table_name = %s
            )
            """
            self.cursor.execute(check_sql, (self.config.schema, table_name))
            result = self.cursor.fetchone()
            return result[0] if result else False
        except Exception as e:
            logger.error(f"检查表 {table_name} 是否存在时出错: {e}")
            return False

def load_config_from_env() -> CloudberryConfig:
    """从环境变量加载Cloudberry配置"""
    return CloudberryConfig(
        host=os.getenv('CLOUDBERRY_HOST', '127.0.0.1'),
        port=int(os.getenv('CLOUDBERRY_PORT', '15432')),
        database=os.getenv('CLOUDBERRY_DATABASE', 'gpadmin'),
        user=os.getenv('CLOUDBERRY_USER', 'gpadmin'),
        password=os.getenv('CLOUDBERRY_PASSWORD', 'hashdata@123'),
        schema=os.getenv('CLOUDBERRY_SCHEMA', 'tpcds')
    )

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='Cloudberry TPC-DS CDC数据生成器')
    parser.add_argument('--total-batches', type=int, default=50, 
                       help='要生成的批次总数 (默认: 50)')
    parser.add_argument('--batch-size', type=int, default=200, 
                       help='微批次大小 (默认: 200)')
    parser.add_argument('--batch-interval', type=float, default=2.0, 
                       help='批次间隔时间(秒) (默认: 2.0)')
    parser.add_argument('--tables', choices=['sales', 'returns', 'both'], default='both',
                       help='要生成数据的表 (默认: both)')
    parser.add_argument('--continuous', action='store_true',
                       help='持续生成模式（无限循环）')
    
    args = parser.parse_args()
    
    # 加载配置
    config = load_config_from_env()
    logger.info(f"加载配置完成: {config.host}:{config.port}/{config.database}")
    
    # 创建CDC数据生成器
    generator = CDCDataGenerator(config)
    generator.micro_batch_size = args.batch_size
    generator.batch_interval = args.batch_interval
    
    try:
        # 连接数据库
        if not generator.connect():
            logger.error("无法连接到数据库，程序退出")
            sys.exit(1)
        
        # 检查表是否存在
        if args.tables in ['sales', 'both']:
            if not generator.check_table_exists('store_sales_heap'):
                logger.error("表 store_sales_heap 不存在，请先创建表")
                sys.exit(1)
        
        if args.tables in ['returns', 'both']:
            if not generator.check_table_exists('store_returns_heap'):
                logger.error("表 store_returns_heap 不存在，请先创建表")
                sys.exit(1)
        
        # 加载已存在的记录ID
        generator.load_existing_ids()
        
        logger.info(f"开始CDC数据生成: 批次大小={args.batch_size}, 间隔={args.batch_interval}秒")
        logger.info(f"{'持续模式' if args.continuous else f'批次模式({args.total_batches}批次)'}")
        
        batch_count = 0
        total_operations = 0
        
        while args.continuous or batch_count < args.total_batches:
            batch_count += 1
            batch_start_time = time.time()
            
            # 生成CDC操作
            all_operations = []
            
            if args.tables in ['sales', 'both']:
                sales_ops = generator.generate_store_sales_data(args.batch_size)
                all_operations.extend(sales_ops)
            
            if args.tables in ['returns', 'both']:
                returns_ops = generator.generate_store_returns_data(args.batch_size)
                all_operations.extend(returns_ops)
            
            # 执行CDC操作
            if generator.execute_cdc_operations(all_operations):
                total_operations += len(all_operations)
                batch_duration = time.time() - batch_start_time
                
                logger.info(f"批次 {batch_count} 完成: {len(all_operations)} 个操作, "
                          f"耗时 {batch_duration:.2f}秒, 累计 {total_operations} 个操作")
            else:
                logger.error(f"批次 {batch_count} 执行失败")
                if not args.continuous:
                    break
            
            # 等待下一个批次
            if args.continuous or batch_count < args.total_batches:
                time.sleep(args.batch_interval)
        
        logger.info(f"CDC数据生成完成！共执行 {batch_count} 个批次, {total_operations} 个操作")
        
    except KeyboardInterrupt:
        logger.info("用户中断程序执行")
    except Exception as e:
        logger.error(f"程序执行出错: {e}")
        sys.exit(1)
    finally:
        generator.disconnect()

if __name__ == "__main__":
    main() 