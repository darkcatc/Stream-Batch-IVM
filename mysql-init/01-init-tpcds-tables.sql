-- =============================================
-- MySQL TPC-DS 数据模型初始化脚本
-- 作者：Vance Chen
-- 基于 Greenplum TPC-DS 表结构创建 MySQL 版本
-- 支持 CDC 同步到 Flink 和后续同步到 Greenplum
-- =============================================

USE business_db;

-- =============================================
-- 商店销售事实表 (基于 tpcds.store_sales_heap)
-- =============================================
CREATE TABLE IF NOT EXISTS store_sales (
    -- 添加自增主键用于 CDC 同步
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    
    -- 原 TPC-DS 字段
    ss_sold_date_sk INT NULL COMMENT '销售日期维度键',
    ss_sold_time_sk INT NULL COMMENT '销售时间维度键', 
    ss_item_sk INT NOT NULL COMMENT '商品维度键',
    ss_customer_sk INT NULL COMMENT '客户维度键',
    ss_cdemo_sk INT NULL COMMENT '客户人口统计维度键',
    ss_hdemo_sk INT NULL COMMENT '家庭人口统计维度键',
    ss_addr_sk INT NULL COMMENT '地址维度键',
    ss_store_sk INT NULL COMMENT '商店维度键',
    ss_promo_sk INT NULL COMMENT '促销维度键',
    ss_ticket_number BIGINT NOT NULL COMMENT '票据号码',
    ss_quantity INT NULL COMMENT '销售数量',
    ss_wholesale_cost DECIMAL(7,2) NULL COMMENT '批发成本',
    ss_list_price DECIMAL(7,2) NULL COMMENT '标价',
    ss_sales_price DECIMAL(7,2) NULL COMMENT '销售价格',
    ss_ext_discount_amt DECIMAL(7,2) NULL COMMENT '扩展折扣金额',
    ss_ext_sales_price DECIMAL(7,2) NULL COMMENT '扩展销售价格',
    ss_ext_wholesale_cost DECIMAL(7,2) NULL COMMENT '扩展批发成本',
    ss_ext_list_price DECIMAL(7,2) NULL COMMENT '扩展标价',
    ss_ext_tax DECIMAL(7,2) NULL COMMENT '扩展税费',
    ss_coupon_amt DECIMAL(7,2) NULL COMMENT '优惠券金额',
    ss_net_paid DECIMAL(7,2) NULL COMMENT '净支付金额',
    ss_net_paid_inc_tax DECIMAL(7,2) NULL COMMENT '含税净支付金额',
    ss_net_profit DECIMAL(7,2) NULL COMMENT '净利润',
    
    -- CDC 和审计字段
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '记录创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '记录更新时间',
    
    -- 索引优化
    INDEX idx_item_sk (ss_item_sk),
    INDEX idx_customer_sk (ss_customer_sk),
    INDEX idx_store_sk (ss_store_sk),
    INDEX idx_sold_date_sk (ss_sold_date_sk),
    INDEX idx_ticket_number (ss_ticket_number),
    INDEX idx_created_at (created_at),
    
    -- 复合索引用于常见查询模式
    INDEX idx_store_date (ss_store_sk, ss_sold_date_sk),
    INDEX idx_customer_date (ss_customer_sk, ss_sold_date_sk)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='商店销售事实表 - 基于TPC-DS标准';

-- =============================================
-- 商店退货事实表 (基于 tpcds.store_returns_heap)
-- =============================================
CREATE TABLE IF NOT EXISTS store_returns (
    -- 添加自增主键用于 CDC 同步
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    
    -- 原 TPC-DS 字段
    sr_returned_date_sk INT NULL COMMENT '退货日期维度键',
    sr_return_time_sk INT NULL COMMENT '退货时间维度键',
    sr_item_sk INT NOT NULL COMMENT '商品维度键',
    sr_customer_sk INT NULL COMMENT '客户维度键',
    sr_cdemo_sk INT NULL COMMENT '客户人口统计维度键',
    sr_hdemo_sk INT NULL COMMENT '家庭人口统计维度键',
    sr_addr_sk INT NULL COMMENT '地址维度键',
    sr_store_sk INT NULL COMMENT '商店维度键',
    sr_reason_sk INT NULL COMMENT '退货原因维度键',
    sr_ticket_number BIGINT NOT NULL COMMENT '原始票据号码',
    sr_return_quantity INT NULL COMMENT '退货数量',
    sr_return_amt DECIMAL(7,2) NULL COMMENT '退货金额',
    sr_return_tax DECIMAL(7,2) NULL COMMENT '退货税费',
    sr_return_amt_inc_tax DECIMAL(7,2) NULL COMMENT '含税退货金额',
    sr_fee DECIMAL(7,2) NULL COMMENT '手续费',
    sr_return_ship_cost DECIMAL(7,2) NULL COMMENT '退货运费',
    sr_refunded_cash DECIMAL(7,2) NULL COMMENT '现金退款',
    sr_reversed_charge DECIMAL(7,2) NULL COMMENT '撤销费用',
    sr_store_credit DECIMAL(7,2) NULL COMMENT '商店信用',
    sr_net_loss DECIMAL(7,2) NULL COMMENT '净损失',
    
    -- CDC 和审计字段
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '记录创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '记录更新时间',
    
    -- 索引优化
    INDEX idx_item_sk (sr_item_sk),
    INDEX idx_customer_sk (sr_customer_sk),
    INDEX idx_store_sk (sr_store_sk),
    INDEX idx_returned_date_sk (sr_returned_date_sk),
    INDEX idx_ticket_number (sr_ticket_number),
    INDEX idx_created_at (created_at),
    
    -- 复合索引用于常见查询模式
    INDEX idx_store_date (sr_store_sk, sr_returned_date_sk),
    INDEX idx_customer_date (sr_customer_sk, sr_returned_date_sk)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='商店退货事实表 - 基于TPC-DS标准';

-- =============================================
-- 插入测试数据 - 模拟 TPC-DS 销售数据
-- =============================================
INSERT INTO store_sales (
    ss_sold_date_sk, ss_sold_time_sk, ss_item_sk, ss_customer_sk, 
    ss_store_sk, ss_ticket_number, ss_quantity, ss_wholesale_cost, 
    ss_list_price, ss_sales_price, ss_ext_sales_price, ss_net_paid, ss_net_profit
) VALUES
(20240101, 36000, 1001, 5001, 101, 1000001, 2, 45.50, 89.99, 79.99, 159.98, 159.98, 68.98),
(20240101, 36300, 1002, 5002, 101, 1000002, 1, 120.00, 199.99, 179.99, 179.99, 179.99, 59.99),
(20240101, 36600, 1003, 5003, 102, 1000003, 3, 25.00, 49.99, 44.99, 134.97, 134.97, 59.97),
(20240102, 37800, 1001, 5004, 101, 1000004, 1, 45.50, 89.99, 89.99, 89.99, 89.99, 44.49),
(20240102, 38100, 1004, 5005, 103, 1000005, 2, 80.00, 149.99, 129.99, 259.98, 259.98, 99.98);

-- =============================================
-- 插入测试数据 - 模拟 TPC-DS 退货数据
-- =============================================
INSERT INTO store_returns (
    sr_returned_date_sk, sr_return_time_sk, sr_item_sk, sr_customer_sk,
    sr_store_sk, sr_ticket_number, sr_return_quantity, sr_return_amt,
    sr_return_tax, sr_return_amt_inc_tax, sr_refunded_cash, sr_net_loss
) VALUES
(20240103, 39600, 1001, 5001, 101, 1000001, 1, 79.99, 6.40, 86.39, 86.39, 45.50),
(20240104, 40200, 1003, 5003, 102, 1000003, 1, 44.99, 3.60, 48.59, 48.59, 25.00);

-- =============================================
-- 创建数据生成存储过程（用于模拟实时数据）
-- =============================================
DELIMITER //

CREATE PROCEDURE GenerateSalesData(IN record_count INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE random_date_sk INT;
    DECLARE random_time_sk INT;
    DECLARE random_item_sk INT;
    DECLARE random_customer_sk INT;
    DECLARE random_store_sk INT;
    DECLARE random_ticket BIGINT;
    
    WHILE i < record_count DO
        SET random_date_sk = 20240100 + FLOOR(RAND() * 31) + 1;
        SET random_time_sk = 30000 + FLOOR(RAND() * 39600);
        SET random_item_sk = 1000 + FLOOR(RAND() * 100);
        SET random_customer_sk = 5000 + FLOOR(RAND() * 1000);
        SET random_store_sk = 100 + FLOOR(RAND() * 10);
        SET random_ticket = 1000000 + i + FLOOR(RAND() * 1000);
        
        INSERT INTO store_sales (
            ss_sold_date_sk, ss_sold_time_sk, ss_item_sk, ss_customer_sk,
            ss_store_sk, ss_ticket_number, ss_quantity, ss_wholesale_cost,
            ss_list_price, ss_sales_price, ss_ext_sales_price, ss_net_paid, ss_net_profit
        ) VALUES (
            random_date_sk, random_time_sk, random_item_sk, random_customer_sk,
            random_store_sk, random_ticket, 
            1 + FLOOR(RAND() * 5),
            ROUND(20 + RAND() * 100, 2),
            ROUND(40 + RAND() * 200, 2),
            ROUND(35 + RAND() * 180, 2),
            ROUND((35 + RAND() * 180) * (1 + FLOOR(RAND() * 5)), 2),
            ROUND((35 + RAND() * 180) * (1 + FLOOR(RAND() * 5)), 2),
            ROUND(15 + RAND() * 80, 2)
        );
        
        SET i = i + 1;
    END WHILE;
END //

DELIMITER ;

-- 生成初始测试数据
CALL GenerateSalesData(100);

-- 提示信息
SELECT 'TPC-DS MySQL 数据模型初始化完成！' AS message;
SELECT COUNT(*) as sales_records FROM store_sales;
SELECT COUNT(*) as return_records FROM store_returns;
SELECT 'CDC 配置已就绪，可以开始监控数据变更同步到 Flink。' AS cdc_status; 