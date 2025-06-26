-- =============================================
-- Flink SQL - 实时流式分析任务
-- 作者：Vance Chen
-- 基于 TPC-DS 数据的实时销售分析
-- =============================================

-- 设置流式处理环境
SET 'execution.runtime-mode' = 'streaming';
SET 'execution.checkpointing.interval' = '30s';
SET 'table.exec.source.idle-timeout' = '10s';

-- =============================================
-- 从 Kafka 读取销售数据
-- =============================================
CREATE TABLE kafka_sales_source (
    id BIGINT,
    ss_sold_date_sk INT,
    ss_sold_time_sk INT,
    ss_item_sk INT,
    ss_customer_sk INT,
    ss_store_sk INT,
    ss_ticket_number BIGINT,
    ss_quantity INT,
    ss_sales_price DECIMAL(7,2),
    ss_ext_sales_price DECIMAL(7,2),
    ss_net_paid DECIMAL(7,2),
    ss_net_profit DECIMAL(7,2),
    created_at TIMESTAMP(3),
    event_time AS created_at,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'tpcds.store_sales',
    'properties.bootstrap.servers' = 'kafka:29092',
    'format' = 'json',
    'scan.startup.mode' = 'latest-offset',
    'json.timestamp-format.standard' = 'ISO-8601',
    'json.fail-on-missing-field' = 'false'
);

-- =============================================
-- 从 Kafka 读取退货数据
-- =============================================
CREATE TABLE kafka_returns_source (
    id BIGINT,
    sr_returned_date_sk INT,
    sr_return_time_sk INT,
    sr_item_sk INT,
    sr_customer_sk INT,
    sr_store_sk INT,
    sr_ticket_number BIGINT,
    sr_return_quantity INT,
    sr_return_amt DECIMAL(7,2),
    sr_net_loss DECIMAL(7,2),
    created_at TIMESTAMP(3),
    event_time AS created_at,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'tpcds.store_returns',
    'properties.bootstrap.servers' = 'kafka:29092',
    'format' = 'json',
    'scan.startup.mode' = 'latest-offset',
    'json.timestamp-format.standard' = 'ISO-8601',
    'json.fail-on-missing-field' = 'false'
);

-- =============================================
-- 实时销售统计结果输出到 Kafka
-- =============================================
CREATE TABLE kafka_sales_metrics (
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    store_sk INT,
    total_sales BIGINT,
    total_revenue DECIMAL(10,2),
    total_profit DECIMAL(10,2),
    avg_order_value DECIMAL(8,2),
    top_item_sk INT
) WITH (
    'connector' = 'kafka',
    'topic' = 'tpcds.sales_metrics',
    'properties.bootstrap.servers' = 'kafka:29092',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

-- =============================================
-- 实时退货统计结果输出到 Kafka
-- =============================================
CREATE TABLE kafka_return_metrics (
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    store_sk INT,
    total_returns BIGINT,
    total_return_amount DECIMAL(10,2),
    total_loss DECIMAL(10,2),
    return_rate DECIMAL(5,4)
) WITH (
    'connector' = 'kafka',
    'topic' = 'tpcds.return_metrics',
    'properties.bootstrap.servers' = 'kafka:29092',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

-- =============================================
-- 实时销售分析 - 每分钟各商店销售统计
-- =============================================
INSERT INTO kafka_sales_metrics
SELECT 
    window_start,
    window_end,
    ss_store_sk as store_sk,
    COUNT(*) as total_sales,
    SUM(ss_ext_sales_price) as total_revenue,
    SUM(ss_net_profit) as total_profit,
    AVG(ss_ext_sales_price) as avg_order_value,
    -- 计算销量最高的商品（简化版本）
    FIRST_VALUE(ss_item_sk) as top_item_sk
FROM TABLE(
    TUMBLE(TABLE kafka_sales_source, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)
)
WHERE ss_store_sk IS NOT NULL
GROUP BY window_start, window_end, ss_store_sk;

-- =============================================
-- 实时退货分析 - 每分钟各商店退货统计
-- =============================================
INSERT INTO kafka_return_metrics
SELECT 
    window_start,
    window_end,
    sr_store_sk as store_sk,
    COUNT(*) as total_returns,
    SUM(sr_return_amt) as total_return_amount,
    SUM(sr_net_loss) as total_loss,
    -- 计算退货率（这里是简化计算，实际需要与销售数据关联）
    CAST(COUNT(*) AS DECIMAL(5,4)) / 100.0 as return_rate
FROM TABLE(
    TUMBLE(TABLE kafka_returns_source, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)
)
WHERE sr_store_sk IS NOT NULL
GROUP BY window_start, window_end, sr_store_sk;

-- =============================================
-- 高级流式分析示例
-- =============================================

-- 创建实时告警输出表
CREATE TABLE kafka_alerts (
    alert_time TIMESTAMP(3),
    alert_type STRING,
    store_sk INT,
    message STRING,
    value DECIMAL(10,2)
) WITH (
    'connector' = 'kafka',
    'topic' = 'tpcds.alerts',
    'properties.bootstrap.servers' = 'kafka:29092',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

-- 实时告警：检测异常高退货率
INSERT INTO kafka_alerts
SELECT 
    window_end as alert_time,
    'HIGH_RETURN_RATE' as alert_type,
    sr_store_sk as store_sk,
    CONCAT('商店 ', CAST(sr_store_sk AS STRING), ' 退货率异常：', CAST(return_rate * 100 AS STRING), '%') as message,
    return_rate * 100 as value
FROM (
    SELECT 
        window_end,
        sr_store_sk,
        COUNT(*) as return_count,
        SUM(sr_return_amt) as total_return_amount,
        -- 简化的退货率计算
        CASE 
            WHEN COUNT(*) > 10 THEN CAST(COUNT(*) AS DECIMAL(5,4)) / 50.0
            ELSE 0.0
        END as return_rate
    FROM TABLE(
        TUMBLE(TABLE kafka_returns_source, DESCRIPTOR(event_time), INTERVAL '5' MINUTE)
    )
    WHERE sr_store_sk IS NOT NULL
    GROUP BY window_end, sr_store_sk
)
WHERE return_rate > 0.15; -- 退货率超过 15% 时触发告警

-- =============================================
-- 商品销售趋势分析（滑动窗口）
-- =============================================
CREATE TABLE kafka_item_trends (
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    item_sk INT,
    sales_count BIGINT,
    revenue DECIMAL(10,2),
    trend_direction STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'tpcds.item_trends',
    'properties.bootstrap.servers' = 'kafka:29092',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

-- 分析商品销售趋势（5分钟滑动窗口，每1分钟输出）
INSERT INTO kafka_item_trends
SELECT 
    window_start,
    window_end,
    ss_item_sk as item_sk,
    COUNT(*) as sales_count,
    SUM(ss_ext_sales_price) as revenue,
    CASE 
        WHEN COUNT(*) > 10 THEN 'HOT'
        WHEN COUNT(*) > 5 THEN 'NORMAL'
        ELSE 'COLD'
    END as trend_direction
FROM TABLE(
    HOP(TABLE kafka_sales_source, DESCRIPTOR(event_time), INTERVAL '1' MINUTE, INTERVAL '5' MINUTE)
)
WHERE ss_item_sk IS NOT NULL
GROUP BY window_start, window_end, ss_item_sk
HAVING COUNT(*) > 1; -- 过滤掉销量过低的商品

-- =============================================
-- 说明：
-- 1. 以上查询展示了基于 Kafka 的实时流式分析
-- 2. 包含窗口聚合、实时告警、趋势分析等典型场景
-- 3. 实际生产环境中需要根据业务需求调整窗口大小和指标计算逻辑
-- 4. 可以将分析结果进一步输出到 Cloudberry 进行历史数据存储
-- ============================================= 