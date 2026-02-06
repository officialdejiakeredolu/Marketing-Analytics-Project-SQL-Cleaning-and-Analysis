-- ============================================================================
-- ANALYSIS 1: CHANNEL ROI & PERFORMANCE COMPARISON
-- Business Questions:
-- 1. Which marketing channel has the highest ROI?
-- 2. What's the cost per acquisition (CPA) by channel?
-- 3. Which channel drives the most revenue per dollar spent (ROAS)?
-- 4. How do engagement rates compare across channels?
-- ============================================================================

-- NOTE: Email is likely undercredited based on typical industry benchmarks

WITH email_performance AS (
    -- Email channel metrics
    SELECT
        'Email' as channel,
        COUNT(DISTINCT e.campaign_id) as campaigns,
        SUM(e.emails_sent) as total_reach,
        SUM(e.clicks) as total_engagements,
        SUM(e.cost) as total_spend,
        -- Calculate revenue attributed to email campaigns
        COALESCE(SUM(t.net_revenue), 0) as total_revenue,
        COUNT(DISTINCT t.transaction_id) as conversions
    FROM clean_email_campaigns e
    LEFT JOIN clean_customer_transactions t 
        ON e.campaign_id = t.campaign_reference
    WHERE e.campaign_id IS NOT NULL
),
paid_ads_performance AS (
    -- Paid ads channel metrics
    SELECT
        'Paid Ads' as channel,
        COUNT(DISTINCT p.ad_id) as campaigns,
        SUM(p.impressions) as total_reach,
        SUM(p.clicks) as total_engagements,
        SUM(p.spend) as total_spend,
        SUM(p.revenue) as total_revenue,
        SUM(p.conversions) as conversions
    FROM clean_paid_ads p
    WHERE p.ad_id IS NOT NULL
),
social_performance AS (
    -- Social media organic metrics (no direct revenue attribution)
    SELECT
        'Social Organic' as channel,
        COUNT(DISTINCT s.post_id) as campaigns,
        SUM(s.impressions) as total_reach,
        SUM(s.total_engagement) as total_engagements,
        0::NUMERIC as total_spend,
        -- Attribute revenue from social referral source
        COALESCE(SUM(t.net_revenue), 0) as total_revenue,
        COUNT(DISTINCT t.transaction_id) as conversions
    FROM clean_social_media_organic s
    LEFT JOIN clean_customer_transactions t 
        ON t.referral_source = 'Social'
        AND t.transaction_date >= s.post_date
        AND t.transaction_date <= s.post_date + INTERVAL '7 days'
),
unified_performance AS (
    -- Combine all channels
    SELECT * FROM email_performance
    UNION ALL
    SELECT * FROM paid_ads_performance
    UNION ALL
    SELECT * FROM social_performance
)
SELECT
    channel,
    campaigns as total_campaigns,
    total_reach,
    total_engagements,
    ROUND(total_spend, 2) as total_spend,
    ROUND(total_revenue, 2) as total_revenue,
    conversions,
    
    -- Key Performance Metrics
    ROUND((total_engagements::NUMERIC / NULLIF(total_reach, 0)) * 100, 2) as engagement_rate_pct,
    ROUND(total_spend / NULLIF(conversions, 0), 2) as cost_per_acquisition,
    ROUND(total_revenue / NULLIF(total_spend, 0), 2) as roas,
    ROUND(((total_revenue - total_spend) / NULLIF(total_spend, 0)) * 100, 2) as roi_pct,
    ROUND(total_revenue / NULLIF(conversions, 0), 2) as revenue_per_conversion,
    ROUND(total_spend / NULLIF(total_reach, 0), 4) as cost_per_impression,
    
    -- Efficiency Score (composite metric: higher is better)
    ROUND(
        (COALESCE(total_revenue / NULLIF(total_spend, 0), 0) * 0.4) +
        ((total_engagements::NUMERIC / NULLIF(total_reach, 0)) * 100 * 0.3) +
        (COALESCE((total_revenue - total_spend) / NULLIF(total_spend, 0), 0) * 0.3)
    , 2) as efficiency_score
FROM unified_performance
ORDER BY roi_pct DESC NULLS LAST;

-- ============================================================================
-- INSIGHT SUMMARY: Top and Bottom Performers
-- NOTE: Email is likely undercredited based on typical industry benchmarks
-- ============================================================================

WITH unified_performance AS (
    SELECT 'Email' as channel, SUM(t.net_revenue) as revenue, SUM(e.cost) as spend
    FROM clean_email_campaigns e
    LEFT JOIN clean_customer_transactions t ON e.campaign_id = t.campaign_reference
    UNION ALL
    SELECT 'Paid Ads', SUM(revenue), SUM(spend)
    FROM clean_paid_ads
    UNION ALL
    SELECT 'Social Organic', SUM(t.net_revenue), 0
    FROM clean_social_media_organic s
    LEFT JOIN clean_customer_transactions t ON t.referral_source = 'Social'
),
ranked AS (
    SELECT 
        channel,
        revenue,
        spend,
        ((revenue - spend) / NULLIF(spend, 0)) * 100 as roi_pct,
        RANK() OVER (ORDER BY ((revenue - spend) / NULLIF(spend, 0)) DESC) as roi_rank
    FROM unified_performance
)
SELECT
    CASE 
        WHEN roi_rank = 1 THEN 'BEST PERFORMER'
        WHEN roi_rank = (SELECT MAX(roi_rank) FROM ranked) THEN 'NEEDS IMPROVEMENT'
        ELSE 'Good Performance'
    END as performance_status,
    channel,
    ROUND(revenue, 2) as total_revenue,
    ROUND(spend, 2) as total_spend,
    ROUND(roi_pct, 2) as roi_percentage
FROM ranked
ORDER BY roi_rank;

-- ============================================================================
-- RECOMMENDATIONS OUTPUT
-- NOTE: Email is likely undercredited based on typical industry benchmarks
-- ============================================================================

SELECT '=== RECOMMENDED ACTIONS ===' as recommendations;

WITH performance_data AS (
    SELECT 'Email' as channel, SUM(t.net_revenue) as revenue, SUM(e.cost) as spend
    FROM clean_email_campaigns e
    LEFT JOIN clean_customer_transactions t ON e.campaign_id = t.campaign_reference
    UNION ALL
    SELECT 'Paid Ads', SUM(revenue), SUM(spend) FROM clean_paid_ads
    UNION ALL
    SELECT 'Social Organic', SUM(t.net_revenue), 0
    FROM clean_social_media_organic s
    LEFT JOIN clean_customer_transactions t ON t.referral_source = 'Social'
)
SELECT
    channel,
    CASE 
        WHEN ((revenue - spend) / NULLIF(spend, 0)) > 2 
            THEN 'Increase budget - Strong ROI above 200%'
        WHEN ((revenue - spend) / NULLIF(spend, 0)) BETWEEN 1 AND 2 
            THEN 'Maintain budget - Healthy ROI (100-200%)'
        WHEN ((revenue - spend) / NULLIF(spend, 0)) BETWEEN 0 AND 1 
            THEN 'Optimize campaigns - Low ROI (0-100%)'
        WHEN spend > 0 AND ((revenue - spend) / NULLIF(spend, 0)) < 0 
            THEN 'Reduce spend or pause - Negative ROI'
        ELSE 'Review attribution - Limited data'
    END as recommended_action
FROM performance_data
ORDER BY ((revenue - spend) / NULLIF(spend, 0)) DESC NULLS LAST;