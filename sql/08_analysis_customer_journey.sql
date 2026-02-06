-- ============================================================================
-- ANALYSIS 2: CUSTOMER JOURNEY & ATTRIBUTION ANALYSIS
-- Business Questions:
-- 1. What's the typical customer journey from first touch to conversion?
-- 2. How many touchpoints before conversion?
-- 3. First-touch vs last-touch attribution comparison
-- 4. Which channels are best at acquisition vs retention?
-- ============================================================================

-- ============================================================================
-- PART 1: Customer Journey - Time to First Purchase
-- NOTE: Customers with conversion date earleir than signup date were filtered out
-- ============================================================================

WITH first_conversion AS (
    SELECT
        t.customer_id,
        cm.signup_date,
        MIN(t.transaction_date) as first_purchase_date,
        MIN(t.transaction_date) - cm.signup_date as days_to_first_purchase,
        MIN(t.referral_source) as first_purchase_channel,
        MIN(t.net_revenue) as first_order_value
    FROM clean_customer_transactions t
    JOIN clean_customer_master cm ON t.customer_id = cm.customer_id
    WHERE t.transaction_date >= cm.signup_date  -- FIX: Filter for only valid chronological data
    GROUP BY t.customer_id, cm.signup_date
)
SELECT
    'Time to First Purchase Analysis' as metric_type,
    COUNT(*) as total_customers,
    ROUND(AVG(days_to_first_purchase), 1) as avg_days_to_first_purchase,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_first_purchase)::NUMERIC, 0) as median_days_to_first_purchase,
    COUNT(CASE WHEN days_to_first_purchase <= 7 THEN 1 END) as converted_within_week,
    COUNT(CASE WHEN days_to_first_purchase <= 30 THEN 1 END) as converted_within_month,
    COUNT(CASE WHEN days_to_first_purchase <= 90 THEN 1 END) as converted_within_quarter,
    ROUND(COUNT(CASE WHEN days_to_first_purchase <= 7 THEN 1 END)::NUMERIC / COUNT(*) * 100, 1) as pct_convert_within_week,
    ROUND(AVG(first_order_value), 2) as avg_first_order_value
FROM first_conversion;

-- ============================================================================
-- PART 2: Typical Journey Paths (Most Common Channel Sequences)
-- ============================================================================

WITH customer_touchpoints AS (
    SELECT
        t.customer_id,
        t.transaction_date,
        t.referral_source as channel,
        ROW_NUMBER() OVER (PARTITION BY t.customer_id ORDER BY t.transaction_date) as touchpoint_number,
        COUNT(*) OVER (PARTITION BY t.customer_id) as total_touchpoints
    FROM clean_customer_transactions t
    WHERE t.customer_id IS NOT NULL
),
journey_paths AS (
    SELECT
        customer_id,
        total_touchpoints,
        MAX(CASE WHEN touchpoint_number = 1 THEN channel END) as touch_1,
        MAX(CASE WHEN touchpoint_number = 2 THEN channel END) as touch_2,
        MAX(CASE WHEN touchpoint_number = 3 THEN channel END) as touch_3,
        MAX(CASE WHEN touchpoint_number = 4 THEN channel END) as touch_4
    FROM customer_touchpoints
    GROUP BY customer_id, total_touchpoints
)
SELECT
    total_touchpoints as number_of_purchases,
    COUNT(*) as customer_count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100, 1) as pct_of_customers,
    
    -- Most common first channel
    MODE() WITHIN GROUP (ORDER BY touch_1) as most_common_first_channel,
    
    -- Most common second channel (for multi-touch customers)
    MODE() WITHIN GROUP (ORDER BY touch_2) as most_common_second_channel,
    
    -- Example journey path for this group
    touch_1 || 
    COALESCE(' → ' || touch_2, '') || 
    COALESCE(' → ' || touch_3, '') ||
    COALESCE(' → ' || touch_4, '') as example_journey_path
FROM journey_paths
GROUP BY total_touchpoints, touch_1, touch_2, touch_3, touch_4
ORDER BY customer_count DESC
LIMIT 10;

-- Show drop-off at each stage
SELECT
    'Signed Up' as stage,
    COUNT(DISTINCT customer_id) as customers,
    100.0 as pct_remaining
FROM clean_customer_master

UNION ALL

SELECT
    'Made 1st Purchase',
    COUNT(DISTINCT customer_id),
    ROUND(COUNT(DISTINCT customer_id)::NUMERIC / 
          (SELECT COUNT(*) FROM clean_customer_master) * 100, 1)
FROM clean_customer_transactions

UNION ALL

SELECT
    'Made 2nd Purchase',
    COUNT(DISTINCT customer_id),
    ROUND(COUNT(DISTINCT customer_id)::NUMERIC / 
          (SELECT COUNT(*) FROM clean_customer_master) * 100, 1)
FROM (
    SELECT customer_id FROM clean_customer_transactions
    GROUP BY customer_id HAVING COUNT(*) >= 2
) repeat_customers;

-- ============================================================================
-- PART 3: First-Touch vs Last-Touch Attribution
-- ============================================================================

-- First-Touch Attribution
WITH attribution_comparison AS (
    SELECT
        customer_id,
        MAX(CASE WHEN touchpoint_number = 1 THEN channel END) as first_touch_channel,
        MAX(CASE WHEN touchpoint_number = total_touchpoints THEN channel END) as last_touch_channel,
        SUM(net_revenue) as customer_ltv
    FROM (
        SELECT
            t.customer_id,
            t.referral_source as channel,
            t.net_revenue,
            ROW_NUMBER() OVER (PARTITION BY t.customer_id ORDER BY t.transaction_date) as touchpoint_number,
            COUNT(*) OVER (PARTITION BY t.customer_id) as total_touchpoints
        FROM clean_customer_transactions t
        WHERE t.customer_id IS NOT NULL
    ) touchpoints
    GROUP BY customer_id
)
SELECT
    first_touch_channel,
    COUNT(DISTINCT customer_id) as customers_acquired,
    ROUND(SUM(customer_ltv), 2) as first_touch_attributed_revenue,
    ROUND(AVG(customer_ltv), 2) as avg_ltv_per_customer,
    ROUND(SUM(customer_ltv) / SUM(SUM(customer_ltv)) OVER () * 100, 1) as pct_of_total_revenue
FROM attribution_comparison
WHERE first_touch_channel IS NOT NULL
GROUP BY first_touch_channel
ORDER BY first_touch_attributed_revenue DESC;

SELECT ''; -- Separator

-- Last-Touch Attribution
WITH attribution_comparison AS (
    SELECT
        customer_id,
        MAX(CASE WHEN touchpoint_number = 1 THEN channel END) as first_touch_channel,
        MAX(CASE WHEN touchpoint_number = total_touchpoints THEN channel END) as last_touch_channel,
        SUM(net_revenue) as customer_ltv
    FROM (
        SELECT
            t.customer_id,
            t.referral_source as channel,
            t.net_revenue,
            ROW_NUMBER() OVER (PARTITION BY t.customer_id ORDER BY t.transaction_date) as touchpoint_number,
            COUNT(*) OVER (PARTITION BY t.customer_id) as total_touchpoints
        FROM clean_customer_transactions t
        WHERE t.customer_id IS NOT NULL
    ) touchpoints
    GROUP BY customer_id
)
SELECT
    last_touch_channel,
    COUNT(DISTINCT customer_id) as customers_attributed,
    ROUND(SUM(customer_ltv), 2) as last_touch_attributed_revenue,
    ROUND(AVG(customer_ltv), 2) as avg_ltv_per_customer,
    ROUND(SUM(customer_ltv) / SUM(SUM(customer_ltv)) OVER () * 100, 1) as pct_of_total_revenue
FROM attribution_comparison
WHERE last_touch_channel IS NOT NULL
GROUP BY last_touch_channel
ORDER BY last_touch_attributed_revenue DESC;

-- ============================================================================
-- PART 4: Channel Role Analysis (Acquisition vs Retention)
-- ============================================================================

WITH customer_purchase_patterns AS (
    SELECT
        t.customer_id,
        t.referral_source as channel,
        t.transaction_date,
        t.net_revenue,
        ROW_NUMBER() OVER (PARTITION BY t.customer_id ORDER BY t.transaction_date) as purchase_sequence,
        COUNT(*) OVER (PARTITION BY t.customer_id) as total_purchases
    FROM clean_customer_transactions t
    WHERE t.customer_id IS NOT NULL
)
SELECT
    channel,
    COUNT(DISTINCT CASE WHEN purchase_sequence = 1 THEN customer_id END) as new_customers_acquired,
    COUNT(DISTINCT CASE WHEN purchase_sequence > 1 THEN customer_id END) as repeat_customers,
    ROUND(SUM(CASE WHEN purchase_sequence = 1 THEN net_revenue ELSE 0 END), 2) as acquisition_revenue,
    ROUND(SUM(CASE WHEN purchase_sequence > 1 THEN net_revenue ELSE 0 END), 2) as retention_revenue,
    ROUND(
        (COUNT(DISTINCT CASE WHEN purchase_sequence > 1 THEN customer_id END)::NUMERIC / 
         NULLIF(COUNT(DISTINCT CASE WHEN purchase_sequence = 1 THEN customer_id END), 0)) * 100, 
        1
    ) as repeat_purchase_rate_pct,
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN purchase_sequence = 1 THEN customer_id END) > 
             COUNT(DISTINCT CASE WHEN purchase_sequence > 1 THEN customer_id END) * 2 
            THEN 'Acquisition Channel'
        WHEN COUNT(DISTINCT CASE WHEN purchase_sequence > 1 THEN customer_id END) > 
             COUNT(DISTINCT CASE WHEN purchase_sequence = 1 THEN customer_id END)
            THEN 'Retention Channel'
        ELSE 'Balanced Channel'
    END as channel_strength
FROM customer_purchase_patterns
WHERE channel IS NOT NULL
GROUP BY channel
ORDER BY new_customers_acquired DESC;

-- ============================================================================
-- PART 5: Time to Conversion Analysis
-- ============================================================================

WITH first_purchase_timing AS (
    SELECT
        t.customer_id,
        t.referral_source as acquisition_channel,
        cm.signup_date,
        MIN(t.transaction_date) as first_purchase_date,
        MIN(t.transaction_date) - cm.signup_date as days_to_first_purchase,
        MIN(t.net_revenue) as first_order_value
    FROM clean_customer_transactions t
    JOIN clean_customer_master cm ON t.customer_id = cm.customer_id
    WHERE t.customer_id IS NOT NULL
      AND t.transaction_date >= cm.signup_date -- FIX: Only valid chronological data
    GROUP BY t.customer_id, t.referral_source, cm.signup_date
)
SELECT
    acquisition_channel,
    COUNT(DISTINCT customer_id) as customers,
    ROUND(AVG(days_to_first_purchase), 0) as avg_days_to_first_purchase,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_first_purchase)::NUMERIC, 0) as median_days_to_first_purchase,
    ROUND(MIN(days_to_first_purchase), 0) as fastest_conversion_days,
    ROUND(MAX(days_to_first_purchase), 0) as slowest_conversion_days,
    ROUND(AVG(first_order_value), 2) as avg_first_order_value,
    CASE 
        WHEN AVG(days_to_first_purchase) < 7 THEN 'Fast Converter (<1 week)'
        WHEN AVG(days_to_first_purchase) < 30 THEN 'Medium Converter (1-4 weeks)'
        ELSE 'Slow Converter (>1 month)'
    END as conversion_speed
FROM first_purchase_timing
WHERE acquisition_channel IS NOT NULL
GROUP BY acquisition_channel
ORDER BY avg_days_to_first_purchase;

-- ============================================================================
-- KEY INSIGHTS SUMMARY
-- ============================================================================

SELECT '=== KEY JOURNEY INSIGHTS ===' as insights;

WITH journey_stats AS (
    SELECT
        t.customer_id,
        COUNT(DISTINCT t.transaction_id) as purchases,
        MAX(CASE WHEN rn = 1 THEN t.referral_source END) as first_channel,
        SUM(t.net_revenue) as ltv
    FROM (
        SELECT 
            customer_id,
            transaction_id,
            referral_source,
            net_revenue,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY transaction_date) as rn
        FROM clean_customer_transactions
    ) t
    GROUP BY t.customer_id
)
SELECT
    'Multi-Touch Customers' as insight,
    COUNT(*) as count,
    ROUND(AVG(ltv), 2) as avg_ltv
FROM journey_stats
WHERE purchases > 1
UNION ALL
SELECT
    'Single-Touch Customers',
    COUNT(*),
    ROUND(AVG(ltv), 2)
FROM journey_stats
WHERE purchases = 1
UNION ALL
SELECT
    'Customers with 3+ Touchpoints',
    COUNT(*),
    ROUND(AVG(ltv), 2)
FROM journey_stats
WHERE purchases >= 3;
