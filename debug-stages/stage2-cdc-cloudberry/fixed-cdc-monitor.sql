-- 修正的 Flink CDC 数据流监控脚本
-- 作者: Vance Chen
-- 用于监控MySQL中的销售和退货数据变化

-- 设置检查点间隔
SET 'execution.checkpointing.interval' = '10s';

-- 创建销售数据CDC源表（匹配实际MySQL结构）
CREATE TABLE store_sales_source (
    id BIGINT,
    ss_sold_date_sk INT,
    ss_sold_time_sk INT,
    ss_item_sk INT,
    ss_customer_sk INT,
    ss_cdemo_sk INT,
    ss_hdemo_sk INT,
    ss_addr_sk INT,
    ss_store_sk INT,
    ss_promo_sk INT,
    ss_ticket_number BIGINT,
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
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    -- 元数据字段
    db_name STRING METADATA FROM 'database_name' VIRTUAL,
    table_name STRING METADATA FROM 'table_name' VIRTUAL,
    op_ts TIMESTAMP_LTZ(3) METADATA FROM 'op_ts' VIRTUAL,
    op_type STRING METADATA FROM 'row_kind' VIRTUAL,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'mysql',
    'port' = '3306',
    'username' = 'flink_cdc',
    'password' = 'flink123',
    'database-name' = 'business_db',
    'table-name' = 'store_sales',
    'server-time-zone' = 'Asia/Shanghai'
);

-- 创建退货数据CDC源表（匹配实际MySQL结构）
CREATE TABLE store_returns_source (
    id BIGINT,
    sr_returned_date_sk INT,
    sr_return_time_sk INT,
    sr_item_sk INT,
    sr_customer_sk INT,
    sr_cdemo_sk INT,
    sr_hdemo_sk INT,
    sr_addr_sk INT,
    sr_store_sk INT,
    sr_reason_sk INT,
    sr_ticket_number BIGINT,
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
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    -- 元数据字段
    db_name STRING METADATA FROM 'database_name' VIRTUAL,
    table_name STRING METADATA FROM 'table_name' VIRTUAL,
    op_ts TIMESTAMP_LTZ(3) METADATA FROM 'op_ts' VIRTUAL,
    op_type STRING METADATA FROM 'row_kind' VIRTUAL,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'mysql',
    'port' = '3306',
    'username' = 'flink_cdc',
    'password' = 'flink123',
    'database-name' = 'business_db',
    'table-name' = 'store_returns',
    'server-time-zone' = 'Asia/Shanghai'
);

-- 创建控制台输出表 - 用于销售数据
CREATE TABLE sales_console (
    op_type STRING,
    op_time TIMESTAMP_LTZ(3),
    id BIGINT,
    ticket_number BIGINT,
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

-- 创建控制台输出表 - 用于退货数据
CREATE TABLE returns_console (
    op_type STRING,
    op_time TIMESTAMP_LTZ(3),
    id BIGINT,
    ticket_number BIGINT,
    item_sk INT,
    customer_sk INT,
    return_quantity INT,
    return_amt DECIMAL(7,2),
    net_loss DECIMAL(7,2)
) WITH (
    'connector' = 'print',
    'print-identifier' = 'RETURNS-CDC'
);

-- 监控销售数据变化
INSERT INTO sales_console
SELECT 
    op_type,
    op_ts,
    id,
    ss_ticket_number,
    ss_item_sk,
    ss_customer_sk,
    ss_quantity,
    ss_sales_price,
    ss_ext_sales_price,
    ss_net_profit
FROM store_sales_source;

-- 监控退货数据变化
INSERT INTO returns_console
SELECT 
    op_type,
    op_ts,
    id,
    sr_ticket_number,
    sr_item_sk,
    sr_customer_sk,
    sr_return_quantity,
    sr_return_amt,
    sr_net_loss
FROM store_returns_source; 