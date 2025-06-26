#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MySQL 连接测试脚本
作者：Vance Chen
用于测试 MySQL 数据库连接是否正常
"""

import sys

def test_mysql_connection():
    """测试MySQL连接"""
    try:
        import mysql.connector
        print("✅ mysql.connector 模块导入成功")
    except ImportError as e:
        print(f"❌ 导入失败: {e}")
        print("💡 请先安装依赖: pip install mysql-connector-python")
        return False
    
    # 数据库配置
    config = {
        'host': 'localhost',
        'port': 3306,
        'user': 'root',
        'password': 'root123',
        'database': 'business_db'
    }
    
    print(f"🔗 尝试连接到 MySQL: {config['host']}:{config['port']}")
    
    try:
        # 尝试连接数据库
        connection = mysql.connector.connect(**config)
        
        if connection.is_connected():
            print("✅ MySQL 连接成功！")
            
            # 获取数据库信息
            cursor = connection.cursor()
            cursor.execute("SELECT VERSION()")
            version = cursor.fetchone()
            print(f"📊 MySQL 版本: {version[0]}")
            
            # 检查表是否存在
            cursor.execute("SHOW TABLES")
            tables = cursor.fetchall()
            print(f"📋 数据库中的表: {[table[0] for table in tables]}")
            
            # 检查store_sales表的数据量
            cursor.execute("SELECT COUNT(*) FROM store_sales")
            sales_count = cursor.fetchone()[0]
            print(f"📈 store_sales 表记录数: {sales_count}")
            
            # 检查store_returns表的数据量
            cursor.execute("SELECT COUNT(*) FROM store_returns")
            returns_count = cursor.fetchone()[0]
            print(f"🔄 store_returns 表记录数: {returns_count}")
            
            cursor.close()
            connection.close()
            print("🔌 连接已关闭")
            return True
            
    except mysql.connector.Error as err:
        print(f"❌ 连接失败: {err}")
        print("💡 请确保:")
        print("   1. Docker MySQL 服务已启动")
        print("   2. 端口 3306 可访问")
        print("   3. 用户名密码正确")
        return False
    
    except Exception as e:
        print(f"❌ 其他错误: {e}")
        return False

def main():
    print("🧪 MySQL 连接测试工具")
    print("=" * 40)
    
    success = test_mysql_connection()
    
    if success:
        print("\n🎉 连接测试通过！可以启动数据生成器")
        print("📝 运行数据生成器: python3 scripts/data-generator.py")
    else:
        print("\n⚠️  连接测试失败，请检查环境配置")
        sys.exit(1)

if __name__ == '__main__':
    main() 