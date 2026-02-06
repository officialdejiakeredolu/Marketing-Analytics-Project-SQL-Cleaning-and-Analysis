-- ============================================================================
-- ANALYSIS 3: CAMPAIGN PERFORMANCE & OPTIMIZATION
-- Business Questions:
-- 1. Which email campaign types perform best?
-- 2. Which paid ad types deliver the best ROI?
-- 3. What's the relationship between discount and order value?
-- 4. Which campaigns are underperforming and wasting budget?
-- ============================================================================

-- -- ============================================================================
-- -- PART 1: Email Campaign Performance by Type
-- -- ============================================================================

WITH email_campaign_analysis AS (
    SELECT
        e.campaign_name,
        COUNT(DISTINCT e.campaign_id) as campaigns_run,
        SUM(e.emails_sent) as total_emails_sent,
        SUM(e.delivered) as total_delivered,
        SUM(e.opens) as total_opens,
        SUM(e.clicks) as total_clicks,
        SUM(e.unsubscribes) as total_unsubscribes,
        SUM(e.cost) as total_cost,
        COUNT(DISTINCT t.transaction_id) as conversions,
        COALESCE(SUM(t.net_revenue), 0) as revenue_generated
    FROM clean_email_campaigns e
    LEFT JOIN clean_customer_transactions t 
        ON e.campaign_id = t.campaign_reference
    GROUP BY e.campaign_name
)
SELECT
    campaign_name,
    campaigns_run,
    total_emails_sent,
    total_opens,
    total_clicks,
    conversions,
    ROUND(total_cost, 2) as total_spend,
    ROUND(revenue_generated, 2) as revenue,
    
    -- Performance Metrics
    ROUND((total_opens::NUMERIC / NULLIF(total_delivered, 0)) * 100, 2) as open_rate_pct,
    ROUND((total_clicks::NUMERIC / NULLIF(total_opens, 0)) * 100, 2) as click_rate_pct,
    ROUND((conversions::NUMERIC / NULLIF(total_clicks, 0)) * 100, 2) as conversion_rate_pct,
    ROUND((total_unsubscribes::NUMERIC / NULLIF(total_delivered, 0)) * 100, 3) as unsubscribe_rate_pct,
    
    -- Financial Metrics
    ROUND(total_cost / NULLIF(conversions, 0), 2) as cost_per_conversion,
    ROUND(revenue_generated / NULLIF(total_cost, 0), 2) as roas,
    ROUND(((revenue_generated - total_cost) / NULLIF(total_cost, 0)) * 100, 2) as roi_pct,
    
    -- Ranking
    RANK() OVER (ORDER BY revenue_generated DESC) as revenue_rank,
    RANK() OVER (ORDER BY ((revenue_generated - total_cost) / NULLIF(total_cost, 0)) DESC) as roi_rank
FROM email_campaign_analysis
ORDER BY revenue_generated DESC;

-- ============================================================================
-- PART 2: Paid Ad Performance by Platform and Type
-- ============================================================================

SELECT
    platform,
    ad_type,
    COUNT(DISTINCT ad_id) as total_ads,
    SUM(impressions) as total_impressions,
    SUM(clicks) as total_clicks,
    SUM(conversions) as total_conversions,
    ROUND(SUM(spend), 2) as total_spend,
    ROUND(SUM(revenue), 2) as total_revenue,
    
    -- Performance Metrics
    ROUND((SUM(clicks)::NUMERIC / NULLIF(SUM(impressions), 0)) * 100, 2) as ctr_pct,
    ROUND((SUM(conversions)::NUMERIC / NULLIF(SUM(clicks), 0)) * 100, 2) as conversion_rate_pct,
    ROUND(SUM(spend) / NULLIF(SUM(clicks), 0), 2) as avg_cpc,
    ROUND(SUM(spend) / NULLIF(SUM(conversions), 0), 2) as cost_per_conversion,
    ROUND(SUM(revenue) / NULLIF(SUM(spend), 0), 2) as roas,
    ROUND(((SUM(revenue) - SUM(spend)) / NULLIF(SUM(spend), 0)) * 100, 2) as roi_pct,
    
    -- Performance Grade
    CASE 
        WHEN ((SUM(revenue) - SUM(spend)) / NULLIF(SUM(spend), 0)) > 2 THEN 'A - Excellent'
        WHEN ((SUM(revenue) - SUM(spend)) / NULLIF(SUM(spend), 0)) BETWEEN 1 AND 2 THEN 'B - Good'
        WHEN ((SUM(revenue) - SUM(spend)) / NULLIF(SUM(spend), 0)) BETWEEN 0 AND 1 THEN 'C - Fair'
        WHEN ((SUM(revenue) - SUM(spend)) / NULLIF(SUM(spend), 0)) < 0 THEN 'F - Poor'
        ELSE 'N/A'
    END as performance_grade
FROM clean_paid_ads
WHERE platform IS NOT NULL AND ad_type IS NOT NULL
GROUP BY platform, ad_type
ORDER BY roi_pct DESC NULLS LAST;

-- ============================================================================
-- PART 3: Discount Impact Analysis
-- ============================================================================

WITH discount_analysis AS (
    SELECT
        CASE 
            WHEN discount_applied = 0 THEN 'No Discount'
            WHEN discount_applied <= 10 THEN 'Small Discount (≤$10)'
            WHEN discount_applied <= 25 THEN 'Medium Discount ($10-$25)'
            WHEN discount_applied <= 50 THEN 'Large Discount ($25-$50)'
            ELSE 'Very Large Discount (>$50)'
        END as discount_tier,
        COUNT(*) as transactions,
        COUNT(DISTINCT customer_id) as unique_customers,
        SUM(items_purchased) as total_items,
        ROUND(AVG(items_purchased), 1) as avg_items_per_order,
        ROUND(SUM(order_value), 2) as gross_revenue,
        ROUND(SUM(discount_applied), 2) as total_discounts,
        ROUND(SUM(net_revenue), 2) as net_revenue,
        ROUND(AVG(order_value), 2) as avg_order_value,
        ROUND(AVG(net_revenue), 2) as avg_net_revenue
    FROM clean_customer_transactions
    GROUP BY discount_tier
)
SELECT
    discount_tier,
    transactions,
    unique_customers,
    total_items,
    avg_items_per_order,
    ROUND(gross_revenue, 2) as gross_revenue,
    ROUND(total_discounts, 2) as total_discounts_given,
    ROUND(net_revenue, 2) as net_revenue,
    avg_order_value,
    avg_net_revenue,
    ROUND((total_discounts / NULLIF(gross_revenue, 0)) * 100, 1) as discount_rate_pct,
    ROUND((net_revenue / NULLIF(transactions, 0)), 2) as revenue_per_transaction,
    -- Efficiency: Net Revenue per Discount Dollar
    ROUND(net_revenue / NULLIF(total_discounts, 0), 2) as revenue_per_discount_dollar
FROM discount_analysis
ORDER BY 
    CASE discount_tier
        WHEN 'No Discount' THEN 1
        WHEN 'Small Discount (≤$10)' THEN 2
        WHEN 'Medium Discount ($10-$25)' THEN 3
        WHEN 'Large Discount ($25-$50)' THEN 4
        ELSE 5
    END;

-- ============================================================================
-- PART 4: Underperforming Campaigns (Budget Waste Identification)
-- ============================================================================

SELECT '=== UNDERPERFORMING EMAIL CAMPAIGNS ===' as alert;

WITH email_waste AS (
    SELECT
        e.campaign_id,
        e.campaign_name,
        e.send_date,
        e.emails_sent,
        e.clicks,
        e.cost as spend,
        COUNT(t.transaction_id) as conversions,
        COALESCE(SUM(t.net_revenue), 0) as revenue,
        e.cost - COALESCE(SUM(t.net_revenue), 0) as budget_waste
    FROM clean_email_campaigns e
    LEFT JOIN clean_customer_transactions t 
        ON e.campaign_id = t.campaign_reference
    GROUP BY e.campaign_id, e.campaign_name, e.send_date, e.emails_sent, e.clicks, e.cost
    HAVING e.cost > 0 
       AND (COALESCE(SUM(t.net_revenue), 0) / NULLIF(e.cost, 0)) < 0.5  -- ROI below 50%
)
SELECT
    campaign_id,
    campaign_name,
    send_date,
    emails_sent,
    clicks,
    conversions,
    ROUND(spend, 2) as spend,
    ROUND(revenue, 2) as revenue,
    ROUND(budget_waste, 2) as money_lost,
    ROUND((revenue / NULLIF(spend, 0)) * 100, 0) as roi_pct,
    'Review targeting or pause' as recommendation
FROM email_waste
ORDER BY budget_waste DESC
LIMIT 10;

SELECT ''; -- Separator

SELECT '=== UNDERPERFORMING PAID ADS ===' as alert;

WITH paid_waste AS (
    SELECT
        platform,
        ad_type,
        COUNT(*) as underperforming_ads,
        ROUND(SUM(spend), 2) as wasted_spend,
        ROUND(SUM(revenue), 2) as poor_revenue,
        ROUND(AVG((revenue - spend) / NULLIF(spend, 0)) * 100, 1) as avg_roi_pct
    FROM clean_paid_ads
    WHERE spend > 0 
      AND (revenue / NULLIF(spend, 0)) < 0.5  -- ROAS below 0.5
    GROUP BY platform, ad_type
)
SELECT
    platform,
    ad_type,
    underperforming_ads,
    wasted_spend,
    poor_revenue,
    avg_roi_pct,
    CASE 
        WHEN avg_roi_pct < -50 THEN 'URGENT: Pause immediately'
        WHEN avg_roi_pct < 0 THEN 'HIGH: Reduce budget 50%'
        ELSE 'MEDIUM: Optimize targeting/creative'
    END as priority_action
FROM paid_waste
ORDER BY wasted_spend DESC;

-- ============================================================================
-- PART 5: Top Performing Campaigns (Double Down Opportunities)
-- ============================================================================

SELECT '=== TOP PERFORMING CAMPAIGNS TO SCALE ===' as opportunity;

WITH top_performers AS (
    SELECT
        e.campaign_id,
        e.campaign_name,
        e.cost as spend,
        COALESCE(SUM(t.net_revenue), 0) as revenue,
        COUNT(t.transaction_id) as conversions
    FROM clean_email_campaigns e
    LEFT JOIN clean_customer_transactions t 
        ON e.campaign_id = t.campaign_reference
    GROUP BY e.campaign_id, e.campaign_name, e.cost
    HAVING e.cost > 0 
       AND (COALESCE(SUM(t.net_revenue), 0) / NULLIF(e.cost, 0)) > 3  -- ROI above 300%
)
SELECT
    campaign_name,
    conversions,
    ROUND(spend, 2) as current_spend,
    ROUND(revenue, 2) as current_revenue,
    ROUND(((revenue - spend) / NULLIF(spend, 0)) * 100, 0) as roi_pct,
    ROUND(spend * 1.5, 2) as recommended_new_budget,
    ROUND(revenue * 1.5, 2) as projected_revenue,
    'Scale up by 50%' as recommendation
FROM top_performers
ORDER BY roi_pct DESC
LIMIT 10;

-- ============================================================================
-- KEY OPTIMIZATION INSIGHTS
-- ============================================================================

SELECT '=== CAMPAIGN OPTIMIZATION SUMMARY ===' as summary;

WITH campaign_profitability AS (
    SELECT
        e.campaign_id,
        e.cost,
        COALESCE(SUM(t.net_revenue), 0) as revenue
    FROM clean_email_campaigns e
    LEFT JOIN clean_customer_transactions t 
        ON e.campaign_id = t.campaign_reference
    GROUP BY e.campaign_id, e.cost
)
SELECT
    'Total Campaigns' as metric,
    COUNT(DISTINCT campaign_id)::TEXT as value
FROM clean_email_campaigns
UNION ALL
SELECT
    'Profitable Campaigns',
    COUNT(*)::TEXT
FROM campaign_profitability
WHERE revenue > cost
UNION ALL
SELECT
    'Unprofitable Campaigns',
    COUNT(*)::TEXT
FROM campaign_profitability
WHERE revenue <= cost AND cost > 0;