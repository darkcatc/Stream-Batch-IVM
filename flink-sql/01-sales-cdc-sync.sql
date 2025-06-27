-- =============================================
-- Flink 作业：Sales 数据 CDC 同步
-- 作者：Vance Chen
-- 功能：MySQL store_sales → Kafka + Cloudberry
-- 架构：单一 CDC 源，多目标 Sink 合并
-- =============================================

-- 设置 Flink SQL 环境
SET 'execution.runtime-mode' = 'streaming';
SET 'execution.checkpointing.interval' = '60s';
SET 'table.exec.source.idle-timeout' = '30s';
SET 'table.exec.sink.not-null-enforcer' = 'drop';

-- =============================================
-- 📊 源表：MySQL CDC - store_sales
-- =============================================
CREATE TABLE mysql_store_sales (
    id BIGINT,
    ss_sold_date_sk INT,
    ss_sold_time_sk INT,
    ss_item_sk INT NOT NULL,
    ss_customer_sk INT,
    ss_cdemo_sk INT,
    ss_hdemo_sk INT,
    ss_addr_sk INT,
    ss_store_sk INT,
    ss_promo_sk INT,
    ss_ticket_number BIGINT NOT NULL,
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
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'mysql',
    'port' = '3306',
    'username' = 'flink_cdc',
    'password' = 'flink_cdc123',
    'database-name' = 'business_db',
    'table-name' = 'store_sales',
    'server-time-zone' = 'Asia/Shanghai',
    'server-id' = '5001-5010',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '8192',
    'debezium.snapshot.mode' = 'initial'
);

-- =============================================
-- 🚀 目标1：Kafka Sink (支持 CDC Upsert)
-- =============================================
CREATE TABLE kafka_sales_sink (
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
    -- CDC 元数据字段
    cdc_op_type STRING METADATA FROM 'op_type' VIRTUAL,
    cdc_ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' VIRTUAL,
    proc_time AS PROCTIME(),  -- 处理时间，用于实时分析
    PRIMARY KEY (id) NOT ENFORCED  -- 主键支持 upsert 操作
) WITH (
    'connector' = 'upsert-kafka',  -- 使用 upsert-kafka 支持 CDC 变更
    'topic' = 'tpcds.store_sales',
    'properties.bootstrap.servers' = 'kafka:29092',
    'key.format' = 'json',          -- 主键序列化格式
    'value.format' = 'json',        -- 值序列化格式
    'value.json.timestamp-format.standard' = 'ISO-8601',
    'value.json.fail-on-missing-field' = 'false',
    'value.json.ignore-parse-errors' = 'true'
);

-- =============================================
-- 🏢 目标2：Cloudberry Sink
-- =============================================
CREATE TABLE cloudberry_sales_sink (
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
    sync_timestamp TIMESTAMP(3)  -- 同步时间戳
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://127.0.0.1:15432/gpadmin',
    'table-name' = 'tpcds.store_sales_heap',
    'username' = 'gpadmin',
    'password' = 'hashdata@123',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '1000',
    'sink.buffer-flush.interval' = '2s',
    'sink.max-retries' = '3',
    'sink.parallelism' = '2'
);

-- =============================================
-- 📋 数据同步任务 1：MySQL → Kafka
-- =============================================
INSERT INTO kafka_sales_sink
SELECT 
    id,
    ss_sold_date_sk,
    ss_sold_time_sk,
    ss_item_sk,
    ss_customer_sk,
    ss_cdemo_sk,
    ss_hdemo_sk,
    ss_addr_sk,
    ss_store_sk,
    ss_promo_sk,
    ss_ticket_number,
    ss_quantity,
    ss_wholesale_cost,
    ss_list_price,
    ss_sales_price,
    ss_ext_discount_amt,
    ss_ext_sales_price,
    ss_ext_wholesale_cost,
    ss_ext_list_price,
    ss_ext_tax,
    ss_coupon_amt,
    ss_net_paid,
    ss_net_paid_inc_tax,
    ss_net_profit,
    created_at,
    updated_at
FROM mysql_store_sales;

-- =============================================
-- 📋 数据同步任务 2：MySQL → Cloudberry
-- =============================================
INSERT INTO cloudberry_sales_sink
SELECT 
    ss_sold_date_sk,
    ss_sold_time_sk,
    ss_item_sk,
    ss_customer_sk,
    ss_cdemo_sk,
    ss_hdemo_sk,
    ss_addr_sk,
    ss_store_sk,
    ss_promo_sk,
    ss_ticket_number,
    ss_quantity,
    ss_wholesale_cost,
    ss_list_price,
    ss_sales_price,
    ss_ext_discount_amt,
    ss_ext_sales_price,
    ss_ext_wholesale_cost,
    ss_ext_list_price,
    ss_ext_tax,
    ss_coupon_amt,
    ss_net_paid,
    ss_net_paid_inc_tax,
    ss_net_profit,
    CURRENT_TIMESTAMP  -- 同步时间戳
FROM mysql_store_sales; 