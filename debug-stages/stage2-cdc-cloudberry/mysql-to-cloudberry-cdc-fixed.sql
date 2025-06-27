-- =============================================
-- MySQL CDC → CloudBerry 数据同步作业 (修复版)
-- 作者：Vance Chen
-- 功能：通过Flink CDC将MySQL数据实时同步到CloudBerry数据仓库
-- 架构：MySQL Binlog → Flink CDC → JDBC → CloudBerry
-- 修复：为sink表添加主键支持update/delete操作
-- =============================================

-- 设置 Flink SQL 环境
SET 'execution.runtime-mode' = 'streaming';
SET 'execution.checkpointing.interval' = '60s';
SET 'table.exec.source.idle-timeout' = '30s';
SET 'table.exec.sink.not-null-enforcer' = 'drop';

-- =============================================
-- 📊 源表1：MySQL CDC - store_sales
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
-- 📊 源表2：MySQL CDC - store_returns
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
-- 🏢 目标表1：CloudBerry - store_sales (修复：添加主键)
-- =============================================
CREATE TABLE cloudberry_store_sales (
    source_id BIGINT,  -- 来源MySQL的ID，作为主键
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
    sync_timestamp TIMESTAMP(3),  -- 同步时间戳
    PRIMARY KEY (source_id) NOT ENFORCED  -- 添加主键支持upsert
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
-- 🏢 目标表2：CloudBerry - store_returns (修复：添加主键)
-- =============================================
CREATE TABLE cloudberry_store_returns (
    source_id BIGINT,  -- 来源MySQL的ID，作为主键
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
    sync_timestamp TIMESTAMP(3),  -- 同步时间戳
    PRIMARY KEY (source_id) NOT ENFORCED  -- 添加主键支持upsert
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
-- 🔄 数据同步任务1：Sales CDC → CloudBerry (修复：包含主键)
-- =============================================
INSERT INTO cloudberry_store_sales
SELECT 
    id as source_id,  -- 映射MySQL的id到source_id主键
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

-- =============================================
-- 🔄 数据同步任务2：Returns CDC → CloudBerry (修复：包含主键)
-- =============================================
INSERT INTO cloudberry_store_returns
SELECT 
    id as source_id,  -- 映射MySQL的id到source_id主键
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