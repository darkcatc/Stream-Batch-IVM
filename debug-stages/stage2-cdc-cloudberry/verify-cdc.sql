-- 简单的CDC验证脚本
-- 作者: Vance Chen

-- 创建简单的销售数据CDC源表
CREATE TABLE simple_sales_cdc (
    ss_ticket_number BIGINT,
    ss_item_sk BIGINT,
    ss_quantity INT,
    ss_sales_price DECIMAL(7,2),
    created_at TIMESTAMP(3),
    -- CDC元数据
    op_type STRING METADATA FROM 'row_kind' VIRTUAL,
    PRIMARY KEY (ss_ticket_number) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'mysql',
    'port' = '3306',
    'username' = 'flink_cdc',
    'password' = 'flink123',
    'database-name' = 'business_db',
    'table-name' = 'store_sales'
);

-- 查询当前数据计数
SELECT COUNT(*) as total_count FROM simple_sales_cdc; 