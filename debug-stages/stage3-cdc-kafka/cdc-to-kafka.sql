-- ===================================================================
-- 修正时间戳的CDC到Kafka数据流作业
-- 作者: Vance Chen
-- 修复: 使用MySQL实际时间戳字段，解决1970年问题
-- ===================================================================

-- 设置检查点
SET 'execution.checkpointing.interval' = '10s';

-- 1. 创建销售数据CDC源表
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
    -- CDC元数据字段
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
    'password' = 'flink_cdc123',
    'database-name' = 'business_db',
    'table-name' = 'store_sales',
    'server-time-zone' = 'Asia/Shanghai'
);

-- 2. 创建销售事件Kafka目标表 (使用upsert-kafka支持CDC变更)
CREATE TABLE sales_events_kafka (
    sales_id BIGINT,
    event_type STRING,
    event_time TIMESTAMP_LTZ(3),
    created_time TIMESTAMP_LTZ(3),
    updated_time TIMESTAMP_LTZ(3),
    ticket_number BIGINT,
    item_sk INT,
    customer_sk INT,
    store_sk INT,
    quantity INT,
    sales_price DECIMAL(7,2),
    ext_sales_price DECIMAL(7,2),
    net_profit DECIMAL(7,2),
    event_source STRING,
    PRIMARY KEY (sales_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sales-events',
    'properties.bootstrap.servers' = 'kafka:29092',
    'key.format' = 'json',
    'value.format' = 'json'
);

-- 3. 🚀 启动核心任务：CDC → Kafka 数据流 (修正时间戳)
INSERT INTO sales_events_kafka
SELECT 
    id as sales_id,
    op_type as event_type,
    COALESCE(op_ts, LOCALTIMESTAMP) as event_time,  -- 使用op_ts，如果为空则用当前时间
    created_at as created_time,                      -- MySQL创建时间
    updated_at as updated_time,                      -- MySQL更新时间
    ss_ticket_number as ticket_number,
    ss_item_sk as item_sk,
    ss_customer_sk as customer_sk,
    ss_store_sk as store_sk,
    ss_quantity as quantity,
    ss_sales_price as sales_price,
    ss_ext_sales_price as ext_sales_price,
    ss_net_profit as net_profit,
    'CDC-TO-KAFKA-TIMESTAMP-FIXED' as event_source
FROM store_sales_source; 