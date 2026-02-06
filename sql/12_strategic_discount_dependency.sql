-- ============================================================================
-- STRATEGIC ANALYSIS 1: DISCOUNT DEPENDENCY & CUSTOMER VALUE DEGRADATION
-- ============================================================================
-- Business Question: Are we training customers to only buy on discount?
-- Hypothesis: Heavy discount usage creates lower-value, discount-dependent customers
-- Strategic Impact: Informs pricing strategy and promotional calendar
-- ============================================================================

-- ============================================================================
-- PART 1: Customer Acquisition - Discount vs Non-Discount
-- ============================================================================

WITH first_purchase_analysis AS (
    SELECT
        t.customer_id,
        MIN(t.transaction_date) as first_purchase_date,
        MIN(t.order_value) as first_order_value,
        MIN(t.discount_applied) as first_discount,
        CASE 
            WHEN MIN(t.discount_applied) > 0 THEN 'Discount Acquisition'
            ELSE 'Full Price Acquisition'
        END as acquisition_type,
        -- Classify discount tier
        CASE 
            WHEN MIN(t.discount_applied) = 0 THEN 'No Discount'
            WHEN MIN(t.discount_applied) <= 10 THEN 'Low Discount (≤$10)'
            WHEN MIN(t.discount_applied) <= 25 THEN 'Medium Discount ($10-$25)'
            ELSE 'High Discount (>$25)'
        END as acquisition_discount_tier
    FROM clean_customer_transactions t
    GROUP BY t.customer_id
),
customer_lifetime_metrics AS (
    SELECT
        t.customer_id,
        COUNT(DISTINCT t.transaction_id) as lifetime_purchases,
        SUM(t.net_revenue) as lifetime_revenue,
        AVG(t.net_revenue) as avg_order_value,
        SUM(t.discount_applied) as total_discounts_used,
        -- Calculate discount dependency
        COUNT(CASE WHEN t.discount_applied > 0 THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(*), 0) * 100 as pct_purchases_with_discount,
        MAX(t.transaction_date) - MIN(t.transaction_date) as customer_lifespan_days,
        -- Calculate time since last purchase (for churn analysis)
        (SELECT MAX(transaction_date) FROM clean_customer_transactions) - MAX(t.transaction_date) as days_since_last_purchase
    FROM clean_customer_transactions t
    GROUP BY t.customer_id
)
SELECT
    fp.acquisition_type,
    fp.acquisition_discount_tier,
    COUNT(DISTINCT fp.customer_id) as total_customers,
    
    -- First Purchase Metrics
    ROUND(AVG(fp.first_order_value), 2) as avg_first_order_value,
    ROUND(AVG(fp.first_discount), 2) as avg_first_discount,
    
    -- Lifetime Value Metrics
    ROUND(AVG(clm.lifetime_revenue), 2) as avg_lifetime_value,
    ROUND(AVG(clm.lifetime_purchases), 1) as avg_lifetime_purchases,
    ROUND(AVG(clm.avg_order_value), 2) as avg_order_value,
    
    -- Discount Dependency
    ROUND(AVG(clm.pct_purchases_with_discount), 1) as avg_pct_discount_purchases,
    ROUND(AVG(clm.total_discounts_used), 2) as avg_total_discounts,
    
    -- Customer Health Metrics
    ROUND(AVG(clm.customer_lifespan_days), 0) as avg_lifespan_days,
    ROUND(AVG(clm.days_since_last_purchase), 0) as avg_days_since_last_purchase,
    COUNT(CASE WHEN clm.days_since_last_purchase > 90 THEN 1 END) as likely_churned_customers,
    ROUND(COUNT(CASE WHEN clm.days_since_last_purchase > 90 THEN 1 END)::NUMERIC / 
        NULLIF(COUNT(DISTINCT fp.customer_id), 0) * 100, 1) as churn_rate_pct,
    
    -- Efficiency Metrics
    ROUND(AVG(clm.lifetime_revenue) / NULLIF(AVG(fp.first_discount), 0), 2) as ltv_per_discount_dollar
FROM first_purchase_analysis fp
JOIN customer_lifetime_metrics clm ON fp.customer_id = clm.customer_id
GROUP BY fp.acquisition_type, fp.acquisition_discount_tier
ORDER BY 
    CASE fp.acquisition_discount_tier
        WHEN 'No Discount' THEN 1
        WHEN 'Low Discount (≤$10)' THEN 2
        WHEN 'Medium Discount ($10-$25)' THEN 3
        ELSE 4
    END;

-- ============================================================================
-- PART 2: Discount Escalation - Are Customers Demanding Bigger Discounts?
-- ============================================================================

SELECT '=== DISCOUNT ESCALATION ANALYSIS ===' as analysis;

WITH customer_discount_progression AS (
    SELECT
        t.customer_id,
        t.transaction_date,
        t.discount_applied,
        t.net_revenue,
        ROW_NUMBER() OVER (PARTITION BY t.customer_id ORDER BY t.transaction_date) as purchase_number,
        AVG(t.discount_applied) OVER (
            PARTITION BY t.customer_id 
            ORDER BY t.transaction_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as running_avg_discount
    FROM clean_customer_transactions t
    WHERE t.customer_id IN (
        SELECT customer_id 
        FROM clean_customer_transactions 
        GROUP BY customer_id 
        HAVING COUNT(*) >= 3  -- Only customers with 3+ purchases
    )
),
first_vs_latest AS (
    SELECT
        customer_id,
        MAX(CASE WHEN purchase_number = 1 THEN discount_applied END) as first_purchase_discount,
        MAX(CASE WHEN purchase_number = (SELECT MAX(purchase_number) FROM customer_discount_progression cdp2 WHERE cdp2.customer_id = customer_discount_progression.customer_id) 
            THEN discount_applied END) as latest_purchase_discount,
        MAX(purchase_number) as total_purchases
    FROM customer_discount_progression
    GROUP BY customer_id
)
SELECT
    CASE 
        WHEN latest_purchase_discount > first_purchase_discount * 1.5 THEN 'Discount Escalation (>50% increase)'
        WHEN latest_purchase_discount > first_purchase_discount THEN 'Moderate Escalation'
        WHEN latest_purchase_discount = first_purchase_discount THEN 'Stable Discount Expectation'
        ELSE 'Decreasing Discount Need'
    END as discount_behavior,
    COUNT(*) as customer_count,
    ROUND(AVG(first_purchase_discount), 2) as avg_first_discount,
    ROUND(AVG(latest_purchase_discount), 2) as avg_latest_discount,
    ROUND(AVG(latest_purchase_discount - first_purchase_discount), 2) as avg_discount_change,
    ROUND(AVG(total_purchases), 1) as avg_purchases
FROM first_vs_latest
GROUP BY discount_behavior
ORDER BY customer_count DESC;

-- ============================================================================
-- PART 3: Full Price vs Discount Customer Retention Curves
-- ============================================================================

SELECT '=== RETENTION ANALYSIS: FULL PRICE VS DISCOUNT CUSTOMERS ===' as analysis;

WITH customer_cohorts AS (
    SELECT
        t.customer_id,
        MIN(t.transaction_date) as cohort_date,
        CASE 
            WHEN MIN(t.discount_applied) > 0 THEN 'Discount Cohort'
            ELSE 'Full Price Cohort'
        END as cohort_type
    FROM clean_customer_transactions t
    GROUP BY t.customer_id
),
monthly_activity AS (
    SELECT
        cc.customer_id,
        cc.cohort_type,
        DATE_TRUNC('month', cc.cohort_date) as cohort_month,
        DATE_TRUNC('month', t.transaction_date) as activity_month,
        EXTRACT(MONTH FROM AGE(t.transaction_date, cc.cohort_date)) as months_since_first_purchase
    FROM customer_cohorts cc
    JOIN clean_customer_transactions t ON cc.customer_id = t.customer_id
)
SELECT
    cohort_type,
    months_since_first_purchase,
    COUNT(DISTINCT customer_id) as active_customers,
    ROUND(COUNT(DISTINCT customer_id)::NUMERIC / 
        (SELECT COUNT(DISTINCT customer_id) 
         FROM customer_cohorts 
         WHERE cohort_type = ma.cohort_type) * 100, 1) as retention_rate_pct
FROM monthly_activity ma
WHERE months_since_first_purchase <= 12
GROUP BY cohort_type, months_since_first_purchase
ORDER BY cohort_type, months_since_first_purchase;

-- ============================================================================
-- PART 4: Strategic Insights & Recommendations
-- ============================================================================

SELECT '=== KEY STRATEGIC INSIGHTS ===' as insights;

WITH acquisition_comparison AS (
    SELECT
        CASE WHEN MIN(t.discount_applied) > 0 THEN 'Discount' ELSE 'Full Price' END as acq_type,
        t.customer_id,
        SUM(t.net_revenue) as ltv,
        COUNT(*) as purchases,
        AVG(t.discount_applied) as avg_discount_per_order
    FROM clean_customer_transactions t
    GROUP BY customer_id
)
SELECT
    'Discount Acquisition LTV Impact' as metric,
    ROUND(AVG(CASE WHEN acq_type = 'Full Price' THEN ltv END), 2) as full_price_avg_ltv,
    ROUND(AVG(CASE WHEN acq_type = 'Discount' THEN ltv END), 2) as discount_avg_ltv,
    ROUND(
        (AVG(CASE WHEN acq_type = 'Full Price' THEN ltv END) - 
         AVG(CASE WHEN acq_type = 'Discount' THEN ltv END)) /
        NULLIF(AVG(CASE WHEN acq_type = 'Discount' THEN ltv END), 0) * 100,
        1
    ) as ltv_premium_pct
FROM acquisition_comparison
UNION ALL
SELECT
    'Repeat Purchase Rate',
    ROUND(AVG(CASE WHEN acq_type = 'Full Price' AND purchases > 1 THEN 100.0 ELSE 0 END), 1),
    ROUND(AVG(CASE WHEN acq_type = 'Discount' AND purchases > 1 THEN 100.0 ELSE 0 END), 1),
    ROUND(
        AVG(CASE WHEN acq_type = 'Full Price' AND purchases > 1 THEN 100.0 ELSE 0 END) - 
        AVG(CASE WHEN acq_type = 'Discount' AND purchases > 1 THEN 100.0 ELSE 0 END),
        1
    )
FROM acquisition_comparison;

-- ============================================================================
-- BUSINESS RECOMMENDATIONS
-- ============================================================================

SELECT '=== RECOMMENDED ACTIONS ===' as recommendations;

SELECT
    'Strategy' as area,
    'Recommendation' as action,
    'Expected Impact' as impact
UNION ALL
SELECT
    'New Customer Acquisition',
    'Reduce discount offers for new customers by 30%. Test value-based messaging.',
    'Increase LTV/CAC ratio by 15-25% based on cohort analysis'
UNION ALL
SELECT
    'Promotional Calendar',
    'Limit discounts to strategic moments: Welcome (10%), Reactivation (20%), VIP exclusive',
    'Reduce discount dependency while maintaining conversion rates'
UNION ALL
SELECT
    'Customer Segmentation',
    'Identify "discount addicts" and exclude from promotional emails',
    'Prevent further discount conditioning; reallocate marketing spend'
UNION ALL
SELECT
    'Full-Price Customer Strategy',
    'Double-down on channels/messaging that attract full-price customers',
    'Shift customer mix toward higher-LTV cohorts'
UNION ALL
SELECT
    'Measurement',
    'Track "Discount Dependency Score" as key health metric alongside LTV',
    'Early warning system for degrading customer quality';