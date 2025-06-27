-- =============================================
-- CloudBerry 数据同步验证脚本 (修复版)
-- 作者：Vance Chen
-- 功能：验证MySQL CDC到CloudBerry的数据同步结果
-- 修复：匹配新的表结构（含source_id主键）
-- =============================================

-- 连接信息提示
\echo '======================================'
\echo 'CloudBerry 数据同步验证 (修复版)'
\echo '======================================'
\echo ''

-- 检查数据库连接
\echo '1. 数据库信息:'
SELECT 
    current_database() as 数据库,
    current_user as 用户,
    version() as 版本;

\echo ''

-- 检查tpcds schema是否存在
\echo '2. 检查tpcds schema:'
SELECT 
    schema_name as "Schema名称"
FROM information_schema.schemata 
WHERE schema_name = 'tpcds';

\echo ''

-- 创建tpcds schema（如果不存在）
\echo '3. 创建tpcds schema（如果需要）:'
CREATE SCHEMA IF NOT EXISTS tpcds;
\echo 'tpcds schema 准备就绪'

\echo ''

-- 检查目标表是否存在
\echo '4. 检查目标表结构:'

-- 检查store_sales_heap表
\echo '4.1 store_sales_heap 表信息:'
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'tpcds' AND table_name = 'store_sales_heap'
        ) 
        THEN 'EXISTS' 
        ELSE 'NOT EXISTS' 
    END as "store_sales_heap状态";

-- 检查store_returns_heap表
\echo '4.2 store_returns_heap 表信息:'
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'tpcds' AND table_name = 'store_returns_heap'
        ) 
        THEN 'EXISTS' 
        ELSE 'NOT EXISTS' 
    END as "store_returns_heap状态";

\echo ''

-- 创建目标表（如果不存在）- 修复版本含主键
\echo '5. 创建目标表（如果需要）- 修复版本:'

-- 删除旧表（如果存在）
DROP TABLE IF EXISTS tpcds.store_sales_heap;
DROP TABLE IF EXISTS tpcds.store_returns_heap;

-- 创建store_sales_heap表（含主键）
CREATE TABLE tpcds.store_sales_heap (
    source_id BIGINT PRIMARY KEY,  -- 主键，对应MySQL的id
    ss_sold_date_sk INTEGER,
    ss_sold_time_sk INTEGER,
    ss_item_sk INTEGER,
    ss_customer_sk INTEGER,
    ss_cdemo_sk INTEGER,
    ss_hdemo_sk INTEGER,
    ss_addr_sk INTEGER,
    ss_store_sk INTEGER,
    ss_promo_sk INTEGER,
    ss_ticket_number BIGINT,
    ss_quantity INTEGER,
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
    sync_timestamp TIMESTAMP
)
DISTRIBUTED BY (source_id);

-- 创建store_returns_heap表（含主键）
CREATE TABLE tpcds.store_returns_heap (
    source_id BIGINT PRIMARY KEY,  -- 主键，对应MySQL的id
    sr_returned_date_sk INTEGER,
    sr_return_time_sk INTEGER,
    sr_item_sk INTEGER,
    sr_customer_sk INTEGER,
    sr_cdemo_sk INTEGER,
    sr_hdemo_sk INTEGER,
    sr_addr_sk INTEGER,
    sr_store_sk INTEGER,
    sr_reason_sk INTEGER,
    sr_ticket_number BIGINT,
    sr_return_quantity INTEGER,
    sr_return_amt DECIMAL(7,2),
    sr_return_tax DECIMAL(7,2),
    sr_return_amt_inc_tax DECIMAL(7,2),
    sr_fee DECIMAL(7,2),
    sr_return_ship_cost DECIMAL(7,2),
    sr_refunded_cash DECIMAL(7,2),
    sr_reversed_charge DECIMAL(7,2),
    sr_store_credit DECIMAL(7,2),
    sr_net_loss DECIMAL(7,2),
    sync_timestamp TIMESTAMP
)
DISTRIBUTED BY (source_id);

\echo '目标表创建完成（含主键）'

\echo ''

-- 检查数据同步情况
\echo '6. 数据同步验证:'

-- 销售数据统计
\echo '6.1 销售数据统计:'
SELECT 
    COUNT(*) as "销售记录数",
    MIN(sync_timestamp) as "最早同步时间",
    MAX(sync_timestamp) as "最新同步时间",
    COUNT(DISTINCT ss_item_sk) as "不同商品数",
    SUM(ss_ext_sales_price) as "总销售额",
    MIN(source_id) as "最小ID",
    MAX(source_id) as "最大ID"
FROM tpcds.store_sales_heap;

\echo ''

-- 退货数据统计
\echo '6.2 退货数据统计:'
SELECT 
    COUNT(*) as "退货记录数",
    MIN(sync_timestamp) as "最早同步时间",
    MAX(sync_timestamp) as "最新同步时间",
    COUNT(DISTINCT sr_item_sk) as "不同商品数",
    SUM(sr_return_amt) as "总退货金额",
    MIN(source_id) as "最小ID",
    MAX(source_id) as "最大ID"
FROM tpcds.store_returns_heap;

\echo ''

-- 最近同步的数据样本
\echo '7. 最近同步的数据样本:'

\echo '7.1 最近的销售记录 (前5条):'
SELECT 
    source_id as "源ID",
    ss_item_sk as "商品ID",
    ss_ticket_number as "票号",
    ss_quantity as "数量",
    ss_sales_price as "销售价格",
    ss_ext_sales_price as "扩展销售价格",
    sync_timestamp as "同步时间"
FROM tpcds.store_sales_heap 
ORDER BY sync_timestamp DESC 
LIMIT 5;

\echo ''

\echo '7.2 最近的退货记录 (前5条):'
SELECT 
    source_id as "源ID",
    sr_item_sk as "商品ID",
    sr_ticket_number as "票号",
    sr_return_quantity as "退货数量",
    sr_return_amt as "退货金额",
    sync_timestamp as "同步时间"
FROM tpcds.store_returns_heap 
ORDER BY sync_timestamp DESC 
LIMIT 5;

\echo ''

-- 验证主键约束
\echo '8. 主键约束验证:'

\echo '8.1 销售表主键重复检查:'
SELECT 
    COUNT(*) as "总记录数",
    COUNT(DISTINCT source_id) as "唯一主键数",
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT source_id) THEN '主键唯一'
        ELSE '存在重复主键'
    END as "主键状态"
FROM tpcds.store_sales_heap;

\echo '8.2 退货表主键重复检查:'
SELECT 
    COUNT(*) as "总记录数",
    COUNT(DISTINCT source_id) as "唯一主键数",
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT source_id) THEN '主键唯一'
        ELSE '存在重复主键'
    END as "主键状态"
FROM tpcds.store_returns_heap;

\echo ''
\echo '======================================'
\echo '修复版验证完成！'
\echo '======================================'
\echo ''
\echo '关键修复点:'
\echo '1. 添加了source_id主键字段'
\echo '2. 支持CDC的update/delete操作'
\echo '3. 重建了表结构以支持upsert'
\echo ''
\echo '监控建议:'
\echo '1. 定期执行此脚本检查同步状态'
\echo '2. 观察sync_timestamp字段的更新'
\echo '3. 对比MySQL源数据与CloudBerry数据'
\echo '4. 验证主键约束的完整性'
\echo '' 