-- ===================================================================
-- Flink CDC 表定义脚本
-- 作者: Vance Chen  
-- 版本: 基于阶段2调试成功的配置
-- 适配: Flink 1.20.1 + CDC 3.4.0
-- ===================================================================

-- 销售数据CDC源表 (对应MySQL store_sales表)
CREATE TABLE store_sales_source (
    id INT,
    ss_sold_date_sk INT,
    ss_sold_time_sk INT,
    ss_item_sk INT,
    ss_customer_sk INT,
    ss_cdemo_sk INT,
    ss_hdemo_sk INT,
    ss_addr_sk INT,
    ss_store_sk INT,
    ss_promo_sk INT,
    ss_ticket_number INT,
    ss_quantity INT,
    ss_wholesale_cost DECIMAL(7,2),
    ss_list_price DECIMAL(7,2),
    ss_sales_price DECIMAL(7,2),
    ss_ext_discount_amt DECIMAL(7,2),
    ss_ext_sales_price DECIMAL(7,2),
    ss_ext_wholesale_cost DECIMAL(7,2),
    ss_ext_list_price DECIMAL(7,2),
    ss_ext_tax DECIMAL(7,2),
    ss_coupon_amt DECIMAL(7,2),
    ss_net_paid DECIMAL(7,2),
    ss_net_paid_inc_tax DECIMAL(7,2),
    ss_net_profit DECIMAL(7,2),
    op_type STRING METADATA FROM 'op_type' VIRTUAL,  -- CDC操作类型
    op_ts TIMESTAMP_LTZ(3) METADATA FROM 'op_ts' VIRTUAL,  -- CDC操作时间戳
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'mysql',
    'port' = '3306',
    'username' = 'flink_cdc',
    'password' = 'cdc123',
    'database-name' = 'business_db',
    'table-name' = 'store_sales',
    'server-id' = '5400-5404',
    'scan.incremental.snapshot.enabled' = 'true'
);

-- 退货数据CDC源表 (对应MySQL store_returns表)
CREATE TABLE store_returns_source (
    id INT,
    sr_returned_date_sk INT,
    sr_return_time_sk INT,
    sr_item_sk INT,
    sr_customer_sk INT,
    sr_cdemo_sk INT,
    sr_hdemo_sk INT,
    sr_addr_sk INT,
    sr_store_sk INT,
    sr_reason_sk INT,
    sr_ticket_number INT,
    sr_return_quantity INT,
    sr_return_amt DECIMAL(7,2),
    sr_return_tax DECIMAL(7,2),
    sr_return_amt_inc_tax DECIMAL(7,2),
    sr_fee DECIMAL(7,2),
    sr_return_ship_cost DECIMAL(7,2),
    sr_refunded_cash DECIMAL(7,2),
    sr_reversed_charge DECIMAL(7,2),
    sr_store_credit DECIMAL(7,2),
    sr_net_loss DECIMAL(7,2),
    op_type STRING METADATA FROM 'op_type' VIRTUAL,  -- CDC操作类型
    op_ts TIMESTAMP_LTZ(3) METADATA FROM 'op_ts' VIRTUAL,  -- CDC操作时间戳
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'mysql',
    'port' = '3306',
    'username' = 'flink_cdc',
    'password' = 'cdc123',
    'database-name' = 'business_db',
    'table-name' = 'store_returns',
    'server-id' = '5405-5409',
    'scan.incremental.snapshot.enabled' = 'true'
);

-- 销售数据控制台输出表 (用于测试和监控)
CREATE TABLE sales_console (
    op_type STRING,
    op_time TIMESTAMP_LTZ(3),
    id INT,
    ticket_number INT,
    item_sk INT,
    customer_sk INT,
    quantity INT,
    sales_price DECIMAL(7,2),
    ext_sales_price DECIMAL(7,2),
    net_profit DECIMAL(7,2)
) WITH (
    'connector' = 'print',
    'print-identifier' = 'SALES-CDC'
);

-- 退货数据控制台输出表 (用于测试和监控)
CREATE TABLE returns_console (
    op_type STRING,
    op_time TIMESTAMP_LTZ(3),
    id INT,
    ticket_number INT,
    item_sk INT,
    customer_sk INT,
    return_quantity INT,
    return_amt DECIMAL(7,2),
    net_loss DECIMAL(7,2)
) WITH (
    'connector' = 'print',
    'print-identifier' = 'RETURNS-CDC'
); 