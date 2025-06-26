-- =============================================
-- Flink SQL - MySQL CDC 直接到 Cloudberry 数据同步（配置化版本）
-- 作者：Vance Chen
-- 用于将 MySQL TPC-DS 数据直接同步到 Cloudberry 数据仓库
-- 此文件为模板，使用配置变量，运行前需要生成实际的SQL文件
-- =============================================

-- 设置 Flink SQL 环境
SET 'execution.runtime-mode' = 'streaming';
SET 'execution.checkpointing.interval' = '${FLINK_CHECKPOINT_INTERVAL}ms';
SET 'table.exec.source.idle-timeout' = '30s';
SET 'table.exec.sink.not-null-enforcer' = 'drop';

-- =============================================
-- 创建 MySQL CDC 源表 - store_sales
-- =============================================
CREATE TABLE mysql_source_store_sales (
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
    'hostname' = '${MYSQL_HOST}',
    'port' = '${MYSQL_PORT}',
    'username' = '${MYSQL_CDC_USER}',
    'password' = '${MYSQL_CDC_PASSWORD}',
    'database-name' = '${MYSQL_DATABASE}',
    'table-name' = 'store_sales',
    'server-time-zone' = '${TIMEZONE}',
    'scan.incremental.snapshot.enabled' = '${FLINK_CDC_INCREMENTAL_SNAPSHOT_ENABLED}',
    'scan.incremental.snapshot.chunk.size' = '${FLINK_CDC_SNAPSHOT_CHUNK_SIZE}',
    'debezium.snapshot.mode' = '${FLINK_CDC_SNAPSHOT_MODE}'
);

-- =============================================
-- 创建 MySQL CDC 源表 - store_returns
-- =============================================
CREATE TABLE mysql_source_store_returns (
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
    'hostname' = '${MYSQL_HOST}',
    'port' = '${MYSQL_PORT}',
    'username' = '${MYSQL_CDC_USER}',
    'password' = '${MYSQL_CDC_PASSWORD}',
    'database-name' = '${MYSQL_DATABASE}',
    'table-name' = 'store_returns',
    'server-time-zone' = '${TIMEZONE}',
    'scan.incremental.snapshot.enabled' = '${FLINK_CDC_INCREMENTAL_SNAPSHOT_ENABLED}',
    'scan.incremental.snapshot.chunk.size' = '${FLINK_CDC_SNAPSHOT_CHUNK_SIZE}',
    'debezium.snapshot.mode' = '${FLINK_CDC_SNAPSHOT_MODE}'
);

-- =============================================
-- 创建 Cloudberry Sink 表 - store_sales_heap
-- 注意：需要先在 Cloudberry 中创建对应的表结构
-- =============================================
CREATE TABLE cloudberry_store_sales (
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
    ss_net_profit DECIMAL(7,2)
) WITH (
    'connector' = 'jdbc',
    'url' = '${CLOUDBERRY_JDBC_URL}',
    'table-name' = '${CLOUDBERRY_SCHEMA}.store_sales_heap',
    'username' = '${CLOUDBERRY_USER}',
    'password' = '${CLOUDBERRY_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '${FLINK_JDBC_BUFFER_FLUSH_MAX_ROWS}',
    'sink.buffer-flush.interval' = '${FLINK_JDBC_BUFFER_FLUSH_INTERVAL}',
    'sink.max-retries' = '${FLINK_JDBC_MAX_RETRIES}',
    'sink.parallelism' = '${FLINK_JDBC_SINK_PARALLELISM}'
);

-- =============================================
-- 创建 Cloudberry Sink 表 - store_returns_heap
-- =============================================
CREATE TABLE cloudberry_store_returns (
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
    sr_net_loss DECIMAL(7,2)
) WITH (
    'connector' = 'jdbc',
    'url' = '${CLOUDBERRY_JDBC_URL}',
    'table-name' = '${CLOUDBERRY_SCHEMA}.store_returns_heap',
    'username' = '${CLOUDBERRY_USER}',
    'password' = '${CLOUDBERRY_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '${FLINK_JDBC_BUFFER_FLUSH_MAX_ROWS}',
    'sink.buffer-flush.interval' = '${FLINK_JDBC_BUFFER_FLUSH_INTERVAL}',
    'sink.max-retries' = '${FLINK_JDBC_MAX_RETRIES}',
    'sink.parallelism' = '${FLINK_JDBC_SINK_PARALLELISM}'
);

-- =============================================
-- 数据同步任务 - store_sales 到 Cloudberry
-- 过滤 MySQL 特有字段，只同步 TPC-DS 标准字段
-- =============================================
INSERT INTO cloudberry_store_sales 
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
    ss_net_profit
FROM mysql_source_store_sales;

-- =============================================
-- 数据同步任务 - store_returns 到 Cloudberry
-- =============================================
INSERT INTO cloudberry_store_returns 
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
    sr_net_loss
FROM mysql_source_store_returns; 