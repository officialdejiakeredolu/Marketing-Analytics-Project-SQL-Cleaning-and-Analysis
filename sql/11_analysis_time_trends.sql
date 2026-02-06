-- ============================================================================
-- ANALYSIS 5: TIME SERIES & TREND ANALYSIS
-- Business Questions:
-- 1. How has performance changed month-over-month?
-- 2. What are the seasonal patterns?
-- 3. Which months have best/worst performance?
-- 4. Are metrics improving or declining over time?
-- ============================================================================

-- ============================================================================
-- PART 1: Monthly Performance Trends
-- ============================================================================

WITH monthly_metrics AS (
    SELECT
        DATE_TRUNC('month', t.transaction_date) as month,
        COUNT(DISTINCT t.transaction_id) as transactions,
        COUNT(DISTINCT t.customer_id) as unique_customers,
        SUM(t.net_revenue) as revenue,
        AVG(t.net_revenue) as avg_order_value,
        SUM(t.items_purchased) as items_sold
    FROM clean_customer_transactions t
    WHERE t.transaction_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', t.transaction_date)
)
SELECT
    TO_CHAR(month, 'YYYY-MM') as month,
    transactions,
    unique_customers,
    ROUND(revenue, 2) as total_revenue,
    ROUND(avg_order_value, 2) as avg_order_value,
    items_sold,
    
    -- Month-over-Month Growth
    ROUND(
        ((revenue - LAG(revenue) OVER (ORDER BY month)) / 
        NULLIF(LAG(revenue) OVER (ORDER BY month), 0)) * 100, 
        1
    ) as mom_revenue_growth_pct,
    
    ROUND(
        ((transactions - LAG(transactions) OVER (ORDER BY month))::NUMERIC / 
        NULLIF(LAG(transactions) OVER (ORDER BY month), 0)) * 100, 
        1
    ) as mom_transaction_growth_pct,
    
    -- 3-Month Moving Average
    ROUND(
        AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
        2
    ) as revenue_3mo_moving_avg,
    
    -- Running Total
    ROUND(
        SUM(revenue) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
        2
    ) as revenue_running_total,
    
    -- Rank months by performance
    RANK() OVER (ORDER BY revenue DESC) as revenue_rank
FROM monthly_metrics
ORDER BY month;

============================================================================
PART 2: Day of Week Performance
============================================================================

WITH daily_patterns AS (
    SELECT
        TO_CHAR(transaction_date, 'Day') as day_of_week,
        EXTRACT(ISODOW FROM transaction_date) as day_number,
        COUNT(*) as transactions,
        SUM(net_revenue) as revenue,
        AVG(net_revenue) as avg_order_value
    FROM clean_customer_transactions
    WHERE transaction_date IS NOT NULL
    GROUP BY TO_CHAR(transaction_date, 'Day'), EXTRACT(ISODOW FROM transaction_date)
)
SELECT
    TRIM(day_of_week) as day_of_week,
    transactions,
    ROUND(revenue, 2) as total_revenue,
    ROUND(avg_order_value, 2) as avg_order_value,
    ROUND((revenue / SUM(revenue) OVER ()) * 100, 1) as pct_of_weekly_revenue,
    ROUND(revenue / NULLIF(transactions, 0), 2) as revenue_per_transaction,
    CASE 
        WHEN day_number IN (6, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END as day_type,
    RANK() OVER (ORDER BY revenue DESC) as performance_rank
FROM daily_patterns
ORDER BY day_number;

Weekend vs Weekday Comparison
SELECT ''; -- Separator
SELECT '=== WEEKEND VS WEEKDAY COMPARISON ===' as comparison;

WITH day_type_comparison AS (
    SELECT
        CASE 
            WHEN EXTRACT(ISODOW FROM transaction_date) IN (6, 7) THEN 'Weekend'
            ELSE 'Weekday'
        END as day_type,
        COUNT(*) as transactions,
        SUM(net_revenue) as revenue,
        AVG(net_revenue) as avg_order_value
    FROM clean_customer_transactions
    WHERE transaction_date IS NOT NULL
    GROUP BY day_type
)
SELECT
    day_type,
    transactions,
    ROUND(revenue, 2) as total_revenue,
    ROUND(avg_order_value, 2) as avg_order_value,
    ROUND((revenue / SUM(revenue) OVER ()) * 100, 1) as pct_of_total_revenue,
    ROUND(revenue / NULLIF(transactions, 0), 2) as revenue_per_transaction
FROM day_type_comparison
ORDER BY revenue DESC;

-- ============================================================================
-- PART 3: Seasonal Performance Analysis (by Quarter)
-- ============================================================================

WITH quarterly_performance AS (
    SELECT
        EXTRACT(YEAR FROM transaction_date) as year,
        EXTRACT(QUARTER FROM transaction_date) as quarter,
        'Q' || EXTRACT(QUARTER FROM transaction_date) || ' ' || EXTRACT(YEAR FROM transaction_date) as quarter_label,
        COUNT(*) as transactions,
        COUNT(DISTINCT customer_id) as unique_customers,
        SUM(net_revenue) as revenue,
        AVG(net_revenue) as avg_order_value,
        SUM(items_purchased) as items_sold
    FROM clean_customer_transactions
    WHERE transaction_date IS NOT NULL
    GROUP BY 
        EXTRACT(YEAR FROM transaction_date),
        EXTRACT(QUARTER FROM transaction_date)
)
SELECT
    quarter_label,
    transactions,
    unique_customers,
    ROUND(revenue, 2) as total_revenue,
    ROUND(avg_order_value, 2) as avg_order_value,
    items_sold,
    ROUND((revenue / SUM(revenue) OVER ()) * 100, 1) as pct_of_annual_revenue,
    
    -- Year-over-Year Growth (Would apply to datasets )
    ROUND(
        ((revenue - LAG(revenue, 4) OVER (ORDER BY year, quarter)) / 
        NULLIF(LAG(revenue, 4) OVER (ORDER BY year, quarter), 0)) * 100,
        1
    ) as yoy_growth_pct,
    
    -- Quarter Ranking
    RANK() OVER (ORDER BY revenue DESC) as revenue_rank,
    
    -- Seasonality Indicator
    CASE 
        WHEN revenue > AVG(revenue) OVER () * 1.2 THEN 'Peak Season'
        WHEN revenue < AVG(revenue) OVER () * 0.8 THEN 'Low Season'
        ELSE 'Regular Season'
    END as seasonality
FROM quarterly_performance
ORDER BY year, quarter;

-- ============================================================================
-- PART 4: Email Campaign Performance Trends
-- ============================================================================

WITH email_monthly_trends AS (
    SELECT
        DATE_TRUNC('month', send_date) as month,
        COUNT(*) as campaigns_sent,
        SUM(emails_sent) as total_emails,
        SUM(opens) as total_opens,
        SUM(clicks) as total_clicks,
        AVG(open_rate_pct) as avg_open_rate,
        AVG(click_through_rate_pct) as avg_ctr,
        SUM(cost) as total_spend
    FROM clean_email_campaigns
    WHERE send_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', send_date)
)
SELECT
    TO_CHAR(month, 'YYYY-MM') as month,
    campaigns_sent,
    total_emails,
    total_opens,
    total_clicks,
    ROUND(avg_open_rate, 2) as avg_open_rate_pct,
    ROUND(avg_ctr, 2) as avg_click_rate_pct,
    ROUND(total_spend, 2) as total_spend,
    
    -- Trends
    ROUND(
        avg_open_rate - LAG(avg_open_rate) OVER (ORDER BY month),
        2
    ) as open_rate_change,
    
    ROUND(
        avg_ctr - LAG(avg_ctr) OVER (ORDER BY month),
        2
    ) as ctr_change,
    
    -- Performance Assessment
    CASE 
        WHEN avg_open_rate > LAG(avg_open_rate) OVER (ORDER BY month) 
         AND avg_ctr > LAG(avg_ctr) OVER (ORDER BY month) 
            THEN 'Improving'
        WHEN avg_open_rate < LAG(avg_open_rate) OVER (ORDER BY month) 
         AND avg_ctr < LAG(avg_ctr) OVER (ORDER BY month) 
            THEN 'Declining'
        ELSE '→ Mixed'
    END as trend_direction
FROM email_monthly_trends
ORDER BY month;

-- ============================================================================
-- PART 5: Paid Ads Cost Trends
-- ============================================================================

WITH paid_ads_trends AS (
    SELECT
        DATE_TRUNC('month', ad_date) as month,
        platform,
        COUNT(*) as ads_run,
        SUM(impressions) as impressions,
        SUM(clicks) as clicks,
        SUM(spend) as spend,
        SUM(revenue) as revenue,
        AVG(cpc) as avg_cpc,
        AVG(roas) as avg_roas
    FROM clean_paid_ads
    WHERE ad_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', ad_date), platform
)
SELECT
    TO_CHAR(month, 'YYYY-MM') as month,
    platform,
    ads_run,
    ROUND(spend, 2) as total_spend,
    ROUND(revenue, 2) as total_revenue,
    ROUND(avg_cpc, 2) as avg_cost_per_click,
    ROUND(avg_roas, 2) as avg_roas,
    
    -- Cost Efficiency Trends
    ROUND(
        avg_cpc - LAG(avg_cpc) OVER (PARTITION BY platform ORDER BY month),
        2
    ) as cpc_change,
    
    ROUND(
        ((avg_cpc - LAG(avg_cpc) OVER (PARTITION BY platform ORDER BY month)) /
        NULLIF(LAG(avg_cpc) OVER (PARTITION BY platform ORDER BY month), 0)) * 100,
        1
    ) as cpc_change_pct,
    
    -- Platform Efficiency
    CASE 
        WHEN avg_cpc < LAG(avg_cpc) OVER (PARTITION BY platform ORDER BY month) 
            THEN 'CPC Decreasing (Good)'
        WHEN avg_cpc > LAG(avg_cpc) OVER (PARTITION BY platform ORDER BY month) 
            THEN 'CPC Increasing (Monitor)'
        ELSE 'Stable'
    END as cost_trend
FROM paid_ads_trends
ORDER BY month, platform;

-- ============================================================================
-- PART 6: Customer Acquisition Cohort Analysis
-- ============================================================================

WITH customer_cohorts AS (
    SELECT
        DATE_TRUNC('month', cm.signup_date) as cohort_month,
        COUNT(DISTINCT cm.customer_id) as new_customers,
        COUNT(DISTINCT t.customer_id) as customers_who_purchased,
        SUM(t.net_revenue) as cohort_revenue,
        AVG(t.net_revenue) as avg_revenue_per_customer
    FROM clean_customer_master cm
    LEFT JOIN clean_customer_transactions t 
        ON cm.customer_id = t.customer_id
    WHERE cm.signup_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', cm.signup_date)
)
SELECT
    TO_CHAR(cohort_month, 'YYYY-MM') as acquisition_month,
    new_customers,
    customers_who_purchased,
    ROUND((customers_who_purchased::NUMERIC / NULLIF(new_customers, 0)) * 100, 1) as activation_rate_pct,
    ROUND(cohort_revenue, 2) as total_cohort_revenue,
    ROUND(avg_revenue_per_customer, 2) as avg_revenue_per_customer,
    ROUND(cohort_revenue / NULLIF(new_customers, 0), 2) as revenue_per_acquired_customer,
    
    -- Cohort Quality Assessment
    CASE 
        WHEN (customers_who_purchased::NUMERIC / NULLIF(new_customers, 0)) > 0.5 
            THEN 'High Quality Cohort'
        WHEN (customers_who_purchased::NUMERIC / NULLIF(new_customers, 0)) > 0.3 
            THEN 'Average Cohort'
        ELSE 'Low Quality Cohort'
    END as cohort_quality
FROM customer_cohorts
ORDER BY cohort_month;

-- ============================================================================
-- KEY TREND INSIGHTS
-- ============================================================================

SELECT '=== TREND SUMMARY & PREDICTIONS ===' as insights;

WITH overall_trends AS (
    SELECT
        COUNT(*) as total_data_points,
        MIN(transaction_date) as earliest_date,
        MAX(transaction_date) as latest_date,
        SUM(net_revenue) as total_revenue,
        AVG(net_revenue) as avg_order_value
    FROM clean_customer_transactions
),
monthly_growth AS (
    SELECT
        DATE_TRUNC('month', transaction_date) as month,
        SUM(net_revenue) as revenue
    FROM clean_customer_transactions
    GROUP BY DATE_TRUNC('month', transaction_date)
    ORDER BY month
)
SELECT
    TO_CHAR(earliest_date, 'YYYY-MM-DD') as data_start_date,
    TO_CHAR(latest_date, 'YYYY-MM-DD') as data_end_date,
    ROUND(total_revenue, 2) as total_revenue_analyzed,
    ROUND(avg_order_value, 2) as avg_order_value,
    (SELECT COUNT(*) FROM monthly_growth) as months_of_data,
    ROUND(
        ((SELECT revenue FROM monthly_growth ORDER BY month DESC LIMIT 1) -
         (SELECT revenue FROM monthly_growth ORDER BY month LIMIT 1)) /
        NULLIF((SELECT revenue FROM monthly_growth ORDER BY month LIMIT 1), 0) * 100,
        1
    ) as total_growth_pct
FROM overall_trends;