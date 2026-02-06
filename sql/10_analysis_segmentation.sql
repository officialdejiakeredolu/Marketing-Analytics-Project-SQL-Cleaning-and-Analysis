-- ============================================================================
-- ANALYSIS 4: CUSTOMER SEGMENTATION & LIFETIME VALUE ANALYSIS
-- Business Questions:
-- 1. Which customer segments have the highest LTV?
-- 2. How do campaigns perform across different segments?
-- 3. Which demographics respond best to which channels?
-- 4. Geographic performance analysis
-- ============================================================================

-- ============================================================================
-- PART 1: Customer Segment Performance Overview
-- ============================================================================

WITH segment_metrics AS (
    SELECT
        cm.customer_segment,
        COUNT(DISTINCT cm.customer_id) as total_customers,
        COUNT(DISTINCT t.transaction_id) as total_transactions,
        SUM(t.net_revenue) as total_revenue,
        SUM(t.items_purchased) as total_items,
        AVG(EXTRACT(YEAR FROM AGE(CURRENT_DATE, cm.signup_date))) as avg_customer_age_years
    FROM clean_customer_master cm
    LEFT JOIN clean_customer_transactions t 
        ON cm.customer_id = t.customer_id
    GROUP BY cm.customer_segment
)
SELECT
    customer_segment,
    total_customers,
    total_transactions,
    ROUND(total_revenue, 2) as total_revenue,
    
    -- Customer Value Metrics
    ROUND(total_revenue / NULLIF(total_customers, 0), 2) as avg_ltv_per_customer,
    ROUND(total_transactions::NUMERIC / NULLIF(total_customers, 0), 1) as avg_orders_per_customer,
    ROUND(total_revenue / NULLIF(total_transactions, 0), 2) as avg_order_value,
    ROUND(total_items::NUMERIC / NULLIF(total_transactions, 0), 1) as avg_items_per_order,
    ROUND(avg_customer_age_years, 1) as avg_tenure_years,
    
    -- Segment Share
    ROUND((total_revenue / SUM(total_revenue) OVER ()) * 100, 1) as pct_of_total_revenue,
    ROUND((total_customers::NUMERIC / SUM(total_customers) OVER ()) * 100, 1) as pct_of_customer_base,
    
    -- Segment Ranking
    RANK() OVER (ORDER BY total_revenue DESC) as revenue_rank,
    RANK() OVER (ORDER BY total_revenue / NULLIF(total_customers, 0) DESC) as ltv_rank
FROM segment_metrics
ORDER BY total_revenue DESC;

-- ============================================================================
-- PART 2: Channel Effectiveness by Customer Segment
-- ============================================================================

WITH segment_channel_performance AS (
    SELECT
        cm.customer_segment,
        t.referral_source as channel,
        COUNT(DISTINCT t.customer_id) as customers,
        COUNT(t.transaction_id) as transactions,
        SUM(t.net_revenue) as revenue,
        AVG(t.net_revenue) as avg_transaction_value
    FROM clean_customer_transactions t
    JOIN clean_customer_master cm ON t.customer_id = cm.customer_id
    WHERE t.referral_source IS NOT NULL 
      AND cm.customer_segment IS NOT NULL
    GROUP BY cm.customer_segment, t.referral_source
)
SELECT
    customer_segment,
    channel,
    customers,
    transactions,
    ROUND(revenue, 2) as total_revenue,
    ROUND(avg_transaction_value, 2) as avg_order_value,
    ROUND((revenue / SUM(revenue) OVER (PARTITION BY customer_segment)) * 100, 1) as pct_of_segment_revenue,
    ROUND((transactions::NUMERIC / NULLIF(customers, 0)), 1) as avg_purchases_per_customer,
    
    -- Identify best channel for each segment
    RANK() OVER (PARTITION BY customer_segment ORDER BY revenue DESC) as channel_rank_in_segment
FROM segment_channel_performance
ORDER BY customer_segment, revenue DESC;

-- Best Channel Recommendation per Segment
SELECT ''; -- Separator
SELECT '=== BEST CHANNEL BY SEGMENT ===' as recommendation;

WITH ranked_channels AS (
    SELECT
        cm.customer_segment,
        t.referral_source as channel,
        SUM(t.net_revenue) as revenue,
        RANK() OVER (PARTITION BY cm.customer_segment ORDER BY SUM(t.net_revenue) DESC) as rank
    FROM clean_customer_transactions t
    JOIN clean_customer_master cm ON t.customer_id = cm.customer_id
    WHERE t.referral_source IS NOT NULL
    GROUP BY cm.customer_segment, t.referral_source
)
SELECT
    customer_segment,
    channel as best_performing_channel,
    ROUND(revenue, 2) as revenue_from_channel,
    'Prioritize this channel for segment' as action
FROM ranked_channels
WHERE rank = 1
ORDER BY revenue DESC;

-- ============================================================================
-- PART 3: Age Group Analysis
-- ============================================================================

WITH age_group_performance AS (
    SELECT
        cm.age_group,
        COUNT(DISTINCT cm.customer_id) as customers,
        COUNT(DISTINCT t.transaction_id) as transactions,
        SUM(t.net_revenue) as revenue,
        COUNT(DISTINCT CASE WHEN cm.email_opt_in = TRUE THEN cm.customer_id END) as email_subscribers
    FROM clean_customer_master cm
    LEFT JOIN clean_customer_transactions t ON cm.customer_id = t.customer_id
    GROUP BY cm.age_group
),
ltv_calculations AS (
    SELECT
        age_group,
        customers,
        transactions,
        revenue,
        email_subscribers,
        revenue / NULLIF(customers, 0) as ltv_per_customer
    FROM age_group_performance
),
percentile_values AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ltv_per_customer) as p25,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY ltv_per_customer) as p50_median,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ltv_per_customer) as p75,
        MIN(ltv_per_customer) as min_ltv,
        MAX(ltv_per_customer) as max_ltv
    FROM ltv_calculations
)
SELECT
    lc.age_group,
    lc.customers,
    lc.transactions,
    ROUND(lc.revenue, 2) as total_revenue,
    ROUND(lc.ltv_per_customer, 2) as avg_ltv,
    ROUND(lc.transactions::NUMERIC / NULLIF(lc.customers, 0), 1) as avg_orders_per_customer,
    lc.email_subscribers,
    ROUND((lc.email_subscribers::NUMERIC / NULLIF(lc.customers, 0)) * 100, 1) as email_opt_in_rate_pct,
    ROUND((lc.revenue / SUM(lc.revenue) OVER ()) * 100, 1) as pct_of_total_revenue,
    
    -- Age Group Insights - Using quartile-based classification
    CASE 
        WHEN lc.ltv_per_customer >= pv.p75 
            THEN 'High Value Segment (Top 25%)'
        WHEN lc.ltv_per_customer >= pv.p50_median 
            THEN 'Above Average Segment'
        WHEN lc.ltv_per_customer >= pv.p25 
            THEN 'Below Average Segment'
        ELSE 'Growth Opportunity (Bottom 25%)'
    END as segment_classification,
    
    -- Performance vs Best
    ROUND(((lc.ltv_per_customer - pv.min_ltv) / NULLIF(pv.max_ltv - pv.min_ltv, 0)) * 100, 0) as performance_score_0_to_100
FROM ltv_calculations lc
CROSS JOIN percentile_values pv
ORDER BY 
    CASE lc.age_group
        WHEN '18-24' THEN 1
        WHEN '25-34' THEN 2
        WHEN '35-44' THEN 3
        WHEN '45-54' THEN 4
        WHEN '55-64' THEN 5
        WHEN '65+' THEN 6
        ELSE 7
    END;

-- ============================================================================
-- PART 4: Geographic Performance Analysis
-- ============================================================================

WITH state_performance AS (
    SELECT
        cm.state,
        COUNT(DISTINCT cm.customer_id) as customers,
        COUNT(DISTINCT t.transaction_id) as transactions,
        SUM(t.net_revenue) as revenue,
        AVG(t.net_revenue) as avg_transaction_value,
        COUNT(DISTINCT CASE WHEN cm.email_opt_in = TRUE THEN cm.customer_id END) as email_subscribers
    FROM clean_customer_master cm
    LEFT JOIN clean_customer_transactions t ON cm.customer_id = t.customer_id
    WHERE cm.state IS NOT NULL
    GROUP BY cm.state
)
SELECT
    state,
    customers,
    transactions,
    ROUND(revenue, 2) as total_revenue,
    ROUND(revenue / NULLIF(customers, 0), 2) as revenue_per_customer,
    ROUND(avg_transaction_value, 2) as avg_order_value,
    ROUND(transactions::NUMERIC / NULLIF(customers, 0), 1) as avg_orders_per_customer,
    ROUND((email_subscribers::NUMERIC / NULLIF(customers, 0)) * 100, 1) as email_opt_in_rate_pct,
    
    -- State Ranking
    RANK() OVER (ORDER BY revenue DESC) as revenue_rank,
    RANK() OVER (ORDER BY revenue / NULLIF(customers, 0) DESC) as ltv_rank,
    
    -- Performance Tier
    CASE 
        WHEN revenue > (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue) FROM state_performance) 
            THEN 'Tier 1: Top Market'
        WHEN revenue > (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) FROM state_performance) 
            THEN 'Tier 2: Strong Market'
        WHEN revenue > (SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue) FROM state_performance) 
            THEN 'Tier 3: Growing Market'
        ELSE 'Tier 4: Emerging Market'
    END as market_tier
FROM state_performance
ORDER BY revenue DESC
LIMIT 15;

-- ============================================================================
-- PART 5: Email Opt-In Impact Analysis
-- ============================================================================

WITH opt_in_comparison AS (
    SELECT
        CASE WHEN cm.email_opt_in = TRUE THEN 'Email Subscriber' ELSE 'Non-Subscriber' END as subscriber_status,
        COUNT(DISTINCT cm.customer_id) as customers,
        COUNT(DISTINCT t.transaction_id) as transactions,
        SUM(t.net_revenue) as revenue,
        AVG(t.net_revenue) as avg_order_value
    FROM clean_customer_master cm
    LEFT JOIN clean_customer_transactions t ON cm.customer_id = t.customer_id
    GROUP BY subscriber_status
)
SELECT
    subscriber_status,
    customers,
    transactions,
    ROUND(revenue, 2) as total_revenue,
    ROUND(revenue / NULLIF(customers, 0), 2) as ltv_per_customer,
    ROUND(transactions::NUMERIC / NULLIF(customers, 0), 1) as avg_orders_per_customer,
    ROUND(avg_order_value, 2) as avg_order_value,
    ROUND((revenue / SUM(revenue) OVER ()) * 100, 1) as pct_of_total_revenue
FROM opt_in_comparison
ORDER BY ltv_per_customer DESC;

-- Calculate the LTV Lift from Email Opt-In
SELECT ''; -- Separator
SELECT '=== EMAIL OPT-IN VALUE ===' as metric;

WITH subscriber_value AS (
    SELECT
        AVG(CASE WHEN cm.email_opt_in = TRUE THEN t.net_revenue END) as subscriber_ltv,
        AVG(CASE WHEN cm.email_opt_in = FALSE THEN t.net_revenue END) as non_subscriber_ltv
    FROM clean_customer_master cm
    LEFT JOIN clean_customer_transactions t ON cm.customer_id = t.customer_id
)
SELECT
    ROUND(subscriber_ltv, 2) as avg_subscriber_ltv,
    ROUND(non_subscriber_ltv, 2) as avg_non_subscriber_ltv,
    ROUND(subscriber_ltv - non_subscriber_ltv, 2) as ltv_lift,
    ROUND(((subscriber_ltv - non_subscriber_ltv) / NULLIF(non_subscriber_ltv, 0)) * 100, 1) as ltv_lift_percentage,
    'Email subscribers are more valuable' as insight
FROM subscriber_value;

============================================================================
KEY SEGMENTATION INSIGHTS
============================================================================

SELECT '=== TARGETING RECOMMENDATIONS ===' as recommendations;

WITH segment_summary AS (
    SELECT
        cm.customer_segment,
        COUNT(DISTINCT cm.customer_id) as customers,
        SUM(t.net_revenue) as revenue
    FROM clean_customer_master cm
    LEFT JOIN clean_customer_transactions t ON cm.customer_id = t.customer_id
    GROUP BY cm.customer_segment
)
SELECT
    customer_segment,
    customers,
    ROUND(revenue, 2) as total_revenue,
    ROUND(revenue / NULLIF(customers, 0), 2) as ltv,
    CASE 
        WHEN customer_segment = 'High Value' THEN 'VIP treatment: Exclusive offers, loyalty rewards'
        WHEN customer_segment = 'Medium Value' THEN 'Upsell opportunities: Premium products, bundles'
        WHEN customer_segment = 'At Risk' THEN 'Win-back campaigns: Special discounts, surveys'
        WHEN customer_segment = 'New' THEN 'Welcome series: Onboarding, first purchase incentives'
        WHEN customer_segment = 'Churned' THEN 'Reactivation: Deep discounts, "we miss you" campaigns'
        ELSE 'Monitor and segment further'
    END as recommended_strategy
FROM segment_summary
ORDER BY revenue DESC;