CREATE TABLE tpcds.store_sales_heap (LIKE tpcds.store_sales) WITH (APPENDONLY=FALSE);
INSERT INTO tpcds.store_sales_heap SELECT * FROM tpcds.store_sales;

CREATE TABLE tpcds.store_sales_heap AS
SELECT
    ROW_NUMBER() OVER() as ss_id,
    *
FROM
    tpcds.store_sales
DISTRIBUTED BY (ss_id);

CREATE TABLE tpcds.store_returns_heap AS
SELECT
    ROW_NUMBER() OVER() as sr_id,
    *
FROM
    tpcds.store_returns
DISTRIBUTED BY (sr_id);


CREATE TABLE tpcds.store_returns_heap (
	sr_id int8 NULL,
	sr_returned_date_sk int4 NULL,
	sr_return_time_sk int4 NULL,
	sr_item_sk int4 NULL,
	sr_customer_sk int4 NULL,
	sr_cdemo_sk int4 NULL,
	sr_hdemo_sk int4 NULL,
	sr_addr_sk int4 NULL,
	sr_store_sk int4 NULL,
	sr_reason_sk int4 NULL,
	sr_ticket_number int8 NULL,
	sr_return_quantity int4 NULL,
	sr_return_amt numeric(7, 2) NULL,
	sr_return_tax numeric(7, 2) NULL,
	sr_return_amt_inc_tax numeric(7, 2) NULL,
	sr_fee numeric(7, 2) NULL,
	sr_return_ship_cost numeric(7, 2) NULL,
	sr_refunded_cash numeric(7, 2) NULL,
	sr_reversed_charge numeric(7, 2) NULL,
	sr_store_credit numeric(7, 2) NULL,
	sr_net_loss numeric(7, 2) NULL
)
USING heap
DISTRIBUTED BY (sr_id);

CREATE TABLE tpcds.store_sales_heap (
	ss_id int8 NULL,
	ss_sold_date_sk int4 NULL,
	ss_sold_time_sk int4 NULL,
	ss_item_sk int4 NULL,
	ss_customer_sk int4 NULL,
	ss_cdemo_sk int4 NULL,
	ss_hdemo_sk int4 NULL,
	ss_addr_sk int4 NULL,
	ss_store_sk int4 NULL,
	ss_promo_sk int4 NULL,
	ss_ticket_number int8 NULL,
	ss_quantity int4 NULL,
	ss_wholesale_cost numeric(7, 2) NULL,
	ss_list_price numeric(7, 2) NULL,
	ss_sales_price numeric(7, 2) NULL,
	ss_ext_discount_amt numeric(7, 2) NULL,
	ss_ext_sales_price numeric(7, 2) NULL,
	ss_ext_wholesale_cost numeric(7, 2) NULL,
	ss_ext_list_price numeric(7, 2) NULL,
	ss_ext_tax numeric(7, 2) NULL,
	ss_coupon_amt numeric(7, 2) NULL,
	ss_net_paid numeric(7, 2) NULL,
	ss_net_paid_inc_tax numeric(7, 2) NULL,
	ss_net_profit numeric(7, 2) NULL
)
USING heap
DISTRIBUTED BY (ss_id);

DROP MATERIALIZED VIEW IF EXISTS tpcds.store_daily_performance_enriched_ivm;
CREATE INCREMENTAL MATERIALIZED VIEW tpcds.store_daily_performance_enriched_ivm
AS
SELECT
    -- 维度信息 (从维度表中关联得到)
    ss.ss_store_sk,
    s.s_store_name,
    s.s_state,
    s.s_market_manager,
    d.d_date sold_date_sk,
    -- 核心业务指标 (与之前相同)
    SUM(ss.ss_net_paid_inc_tax) AS total_sales_amount,
    SUM(ss.ss_net_profit) AS total_net_profit,
    SUM(ss.ss_quantity) AS total_items_sold,
    COUNT(ss.ss_ticket_number) AS transaction_count
FROM
    -- 核心事实表与维度表的 JOIN
    tpcds.store_sales_heap ss
JOIN
    tpcds.date_dim d ON ss.ss_sold_date_sk = d.d_date_sk
JOIN
    tpcds.store s ON ss.ss_store_sk = s.s_store_sk
GROUP BY
    -- 所有非聚合的维度列都需要出现在 GROUP BY 中
    ss.ss_store_sk,
    s.s_store_name,
    s.s_state,
    s.s_market_manager,
    d.d_date
DISTRIBUTED BY (ss_store_sk);

