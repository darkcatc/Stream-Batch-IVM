-- =============================================
-- Flink 作业：Returns 数据 CDC 同步
-- 作者：Vance Chen
-- 功能：MySQL store_returns → Kafka + Cloudberry
-- 架构：单一 CDC 源，多目标 Sink 合并
-- =============================================

-- 设置 Flink SQL 环境
SET 'execution.runtime-mode' = 'streaming';
SET 'execution.checkpointing.interval' = '60s';
SET 'table.exec.source.idle-timeout' = '30s';
SET 'table.exec.sink.not-null-enforcer' = 'drop';

-- =============================================
-- 📊 源表：MySQL CDC - store_returns
-- =============================================
CREATE TABLE mysql_store_returns (
    id BIGINT,
    sr_returned_date_sk INT,
    sr_return_time_sk INT,
    sr_item_sk INT NOT NULL,
    sr_customer_sk INT,
    sr_cdemo_sk INT,
    sr_hdemo_sk INT,
    sr_addr_sk INT,
    sr_store_sk INT,
    sr_reason_sk INT,
    sr_ticket_number BIGINT NOT NULL,
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
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'mysql',
    'port' = '3306',
    'username' = 'flink_cdc',
    'password' = 'flink_cdc123',
    'database-name' = 'business_db',
    'table-name' = 'store_returns',
    'server-time-zone' = 'Asia/Shanghai',
    'server-id' = '5011-5020',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '8192',
    'debezium.snapshot.mode' = 'initial'
);

-- =============================================
-- 🚀 目标1：Kafka Sink (支持 CDC Upsert)
-- =============================================
CREATE TABLE kafka_returns_sink (
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
    -- CDC 元数据字段
    cdc_op_type STRING METADATA FROM 'op_type' VIRTUAL,
    cdc_ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' VIRTUAL,
    proc_time AS PROCTIME(),  -- 处理时间，用于实时分析
    PRIMARY KEY (id) NOT ENFORCED  -- 主键支持 upsert 操作
) WITH (
    'connector' = 'upsert-kafka',  -- 使用 upsert-kafka 支持 CDC 变更
    'topic' = 'tpcds.store_returns',
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
CREATE TABLE cloudberry_returns_sink (
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
    sync_timestamp TIMESTAMP(3)  -- 同步时间戳
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://127.0.0.1:15432/gpadmin',
    'table-name' = 'tpcds.store_returns_heap',
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
INSERT INTO kafka_returns_sink
SELECT 
    id,
    sr_returned_date_sk,
    sr_return_time_sk,
    sr_item_sk,
    sr_customer_sk,
    sr_cdemo_sk,
    sr_hdemo_sk,
    sr_addr_sk,
    sr_store_sk,
    sr_reason_sk,
    sr_ticket_number,
    sr_return_quantity,
    sr_return_amt,
    sr_return_tax,
    sr_return_amt_inc_tax,
    sr_fee,
    sr_return_ship_cost,
    sr_refunded_cash,
    sr_reversed_charge,
    sr_store_credit,
    sr_net_loss,
    created_at,
    updated_at
FROM mysql_store_returns;

-- =============================================
-- 📋 数据同步任务 2：MySQL → Cloudberry
-- =============================================
INSERT INTO cloudberry_returns_sink
SELECT 
    sr_returned_date_sk,
    sr_return_time_sk,
    sr_item_sk,
    sr_customer_sk,
    sr_cdemo_sk,
    sr_hdemo_sk,
    sr_addr_sk,
    sr_store_sk,
    sr_reason_sk,
    sr_ticket_number,
    sr_return_quantity,
    sr_return_amt,
    sr_return_tax,
    sr_return_amt_inc_tax,
    sr_fee,
    sr_return_ship_cost,
    sr_refunded_cash,
    sr_reversed_charge,
    sr_store_credit,
    sr_net_loss,
    CURRENT_TIMESTAMP  -- 同步时间戳
FROM mysql_store_returns; 