-- 启动销售数据CDC监控任务
INSERT INTO sales_console
SELECT 
    op_type,
    op_ts as op_time,
    id,
    ss_ticket_number as ticket_number,
    ss_item_sk as item_sk,
    ss_customer_sk as customer_sk,
    ss_quantity as quantity,
    ss_sales_price as sales_price,
    ss_ext_sales_price as ext_sales_price,
    ss_net_profit as net_profit
FROM store_sales_source;

-- 启动退货数据CDC监控任务
INSERT INTO returns_console
SELECT 
    op_type,
    op_ts as op_time,
    id,
    sr_ticket_number as ticket_number,
    sr_item_sk as item_sk,
    sr_customer_sk as customer_sk,
    sr_return_quantity as return_quantity,
    sr_return_amt as return_amt,
    sr_net_loss as net_loss
FROM store_returns_source; 