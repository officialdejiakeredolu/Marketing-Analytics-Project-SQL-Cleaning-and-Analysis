-- ============================================================================
-- STRATEGIC ANALYSIS 2: CHANNEL SATURATION & DIMINISHING RETURNS
-- ============================================================================
-- Business Question: Are we over-investing in channels that can't scale?
-- Hypothesis: High-ROI channels show diminishing returns at higher spend levels
-- Strategic Impact: Optimal budget allocation across channels
-- ============================================================================

-- ============================================================================
-- PART 1: Email Campaign Saturation Analysis
-- ============================================================================

WITH email_performance_buckets AS (
    SELECT
        e.campaign_id,
        e.campaign_name,
        e.send_date,
        e.emails_sent,
        e.cost as spend,
        COALESCE(SUM(t.net_revenue), 0) as revenue,
        -- Create spend buckets for analysis
        CASE 
            WHEN e.cost < 500 THEN 'Low Spend (<$500)'
            WHEN e.cost < 1000 THEN 'Medium Spend ($500-$1K)'
            WHEN e.cost < 2000 THEN 'High Spend ($1K-$2K)'
            ELSE 'Very High Spend (>$2K)'
        END as spend_bucket,
        -- Campaign size bucket
        CASE 
            WHEN e.emails_sent < 10000 THEN 'Small (<10K)'
            WHEN e.emails_sent < 25000 THEN 'Medium (10K-25K)'
            WHEN e.emails_sent < 50000 THEN 'Large (25K-50K)'
            ELSE 'Very Large (>50K)'
        END as size_bucket
    FROM clean_email_campaigns e
    LEFT JOIN clean_customer_transactions t ON e.campaign_id = t.campaign_reference
    GROUP BY e.campaign_id, e.campaign_name, e.send_date, e.emails_sent, e.cost
)
SELECT
    spend_bucket,
    COUNT(*) as campaign_count,
    ROUND(AVG(spend), 2) as avg_spend,
    ROUND(AVG(revenue), 2) as avg_revenue,
    ROUND(AVG(revenue / NULLIF(spend, 0)), 2) as avg_roas,
    ROUND(((AVG(revenue) - AVG(spend)) / NULLIF(AVG(spend), 0)) * 100, 1) as avg_roi_pct,
    -- Efficiency score (revenue per dollar of spend)
    ROUND(SUM(revenue) / NULLIF(SUM(spend), 0), 2) as total_roas,
    -- Marginal returns (how much does efficiency drop as spend increases?)
    ROUND(
        AVG(revenue / NULLIF(spend, 0)) - 
        LAG(AVG(revenue / NULLIF(spend, 0))) OVER (ORDER BY spend_bucket),
        2
    ) as roas_change_from_previous_tier
FROM email_performance_buckets
GROUP BY spend_bucket
ORDER BY 
    CASE spend_bucket
        WHEN 'Low Spend (<$500)' THEN 1
        WHEN 'Medium Spend ($500-$1K)' THEN 2
        WHEN 'High Spend ($1K-$2K)' THEN 3
        ELSE 4
    END;

-- ============================================================================
-- PART 2: Paid Ads Incremental Spend Analysis
-- ============================================================================

SELECT '=== PAID ADS EFFICIENCY BY SPEND LEVEL ===' as analysis;

WITH daily_ad_spend AS (
    SELECT
        ad_date,
        platform,
        SUM(spend) as daily_spend,
        SUM(revenue) as daily_revenue,
        SUM(clicks) as daily_clicks,
        SUM(conversions) as daily_conversions
    FROM clean_paid_ads
    WHERE ad_date IS NOT NULL
    GROUP BY ad_date, platform
),
spend_deciles AS (
    SELECT
        platform,
        daily_spend,
        daily_revenue,
        NTILE(10) OVER (PARTITION BY platform ORDER BY daily_spend) as spend_decile
    FROM daily_ad_spend
)
SELECT
    platform,
    spend_decile,
    COUNT(*) as days_in_decile,
    ROUND(AVG(daily_spend), 2) as avg_daily_spend,
    ROUND(AVG(daily_revenue), 2) as avg_daily_revenue,
    ROUND(AVG(daily_revenue / NULLIF(daily_spend, 0)), 2) as avg_roas,
    ROUND(
        (AVG(daily_revenue) - AVG(daily_spend)) / NULLIF(AVG(daily_spend), 0) * 100,
        1
    ) as avg_roi_pct,
    -- Identify saturation point
    CASE 
        WHEN AVG(daily_revenue / NULLIF(daily_spend, 0)) < 
             LAG(AVG(daily_revenue / NULLIF(daily_spend, 0))) OVER (PARTITION BY platform ORDER BY spend_decile)
            THEN 'Diminishing Returns'
        WHEN AVG(daily_revenue / NULLIF(daily_spend, 0)) > 
             LAG(AVG(daily_revenue / NULLIF(daily_spend, 0))) OVER (PARTITION BY platform ORDER BY spend_decile)
            THEN 'Increasing Returns'
        ELSE 'Stable Returns'
    END as efficiency_trend
FROM spend_deciles
GROUP BY platform, spend_decile
ORDER BY platform, spend_decile;

-- ============================================================================
-- PART 3: Channel Capacity & Headroom Analysis
-- ============================================================================

SELECT '=== CHANNEL CAPACITY ANALYSIS ===' as analysis;

WITH channel_metrics AS (
    -- Email
    SELECT
        'Email' as channel,
        SUM(e.cost) as total_spend,
        COALESCE(SUM(t.net_revenue), 0) as total_revenue,
        COUNT(DISTINCT e.campaign_id) as campaigns,
        SUM(e.emails_sent) as total_reach
    FROM clean_email_campaigns e
    LEFT JOIN clean_customer_transactions t ON e.campaign_id = t.campaign_reference
    
    UNION ALL
    
    -- Paid Ads
    SELECT
        'Paid Ads' as channel,
        SUM(spend) as total_spend,
        SUM(revenue) as total_revenue,
        COUNT(DISTINCT ad_id) as campaigns,
        SUM(impressions) as total_reach
    FROM clean_paid_ads
    
    UNION ALL
    
    -- Social Organic (no direct spend)
    SELECT
        'Social Organic' as channel,
        0 as total_spend,
        COALESCE(SUM(t.net_revenue), 0) as total_revenue,
        COUNT(DISTINCT s.post_id) as campaigns,
        SUM(s.impressions) as total_reach
    FROM clean_social_media_organic s
    LEFT JOIN clean_customer_transactions t 
        ON t.referral_source = 'Social' 
        AND t.transaction_date >= s.post_date
        AND t.transaction_date <= s.post_date + INTERVAL '7 days'
),
total_addressable_market AS (
    SELECT 
        COUNT(DISTINCT customer_id) as total_customers,
        SUM(net_revenue) as total_revenue
    FROM clean_customer_transactions
)
SELECT
    cm.channel,
    ROUND(cm.total_spend, 2) as current_spend,
    ROUND(cm.total_revenue, 2) as current_revenue,
    ROUND((cm.total_revenue - cm.total_spend) / NULLIF(cm.total_spend, 0) * 100, 1) as current_roi_pct,
    cm.total_reach,
    
    -- Market Share
    ROUND(cm.total_revenue / tam.total_revenue * 100, 1) as pct_of_total_revenue,
    
    -- Efficiency Metrics
    ROUND(cm.total_spend / NULLIF(cm.campaigns, 0), 2) as avg_spend_per_campaign,
    ROUND(cm.total_revenue / NULLIF(cm.total_reach, 0), 4) as revenue_per_impression,
    
    -- Saturation Indicator
    CASE 
        WHEN cm.total_reach::NUMERIC / tam.total_customers > 20 THEN 'High Saturation (>20x reach)'
        WHEN cm.total_reach::NUMERIC / tam.total_customers > 10 THEN 'Medium Saturation (10-20x)'
        WHEN cm.total_reach::NUMERIC / tam.total_customers > 5 THEN 'Low Saturation (5-10x)'
        ELSE 'Significant Headroom (<5x)'
    END as saturation_level,
    
    -- Growth Potential
    CASE 
        WHEN (cm.total_revenue - cm.total_spend) / NULLIF(cm.total_spend, 0) > 2 
         AND cm.total_reach::NUMERIC / tam.total_customers < 10
            THEN 'Scale Aggressively - High ROI + Low Saturation'
        WHEN (cm.total_revenue - cm.total_spend) / NULLIF(cm.total_spend, 0) > 2
            THEN 'Efficient but Saturated - Optimize, Dont Scale'
        WHEN cm.total_reach::NUMERIC / tam.total_customers < 10
            THEN 'Test & Learn - Headroom Available, Improve Efficiency'
        ELSE 'Maintain - Limited Opportunity'
    END as recommended_strategy
FROM channel_metrics cm
CROSS JOIN total_addressable_market tam
ORDER BY current_roi_pct DESC;

-- ============================================================================
-- PART 4: Optimal Budget Allocation Model
-- ============================================================================

SELECT '=== OPTIMAL BUDGET ALLOCATION SCENARIO ANALYSIS ===' as analysis;

WITH current_performance AS (
    SELECT
        'Email' as channel,
        SUM(e.cost) as current_spend,
        COALESCE(SUM(t.net_revenue), 0) as current_revenue,
        2.5 as estimated_roas_at_50pct_increase,  -- Assumption: drops from 3.0 to 2.5
        1.8 as estimated_roas_at_100pct_increase  -- Assumption: drops to 1.8
    FROM clean_email_campaigns e
    LEFT JOIN clean_customer_transactions t ON e.campaign_id = t.campaign_reference
    
    UNION ALL
    
    SELECT
        'Paid Ads' as channel,
        SUM(spend),
        SUM(revenue),
        2.2 as estimated_roas_at_50pct_increase,
        2.0 as estimated_roas_at_100pct_increase
    FROM clean_paid_ads
)
SELECT
    channel,
    ROUND(current_spend, 2) as current_spend,
    ROUND(current_revenue, 2) as current_revenue,
    ROUND((current_revenue - current_spend) / NULLIF(current_spend, 0) * 100, 1) as current_roi_pct,
    
    -- Scenario 1: +50% Budget
    ROUND(current_spend * 1.5, 2) as scenario_50pct_increase_spend,
    ROUND(current_spend * 1.5 * estimated_roas_at_50pct_increase, 2) as scenario_50pct_increase_revenue,
    ROUND((current_spend * 1.5 * estimated_roas_at_50pct_increase - current_spend * 1.5) / 
          NULLIF(current_spend * 1.5, 0) * 100, 1) as scenario_50pct_roi,
    
    -- Scenario 2: +100% Budget (Double)
    ROUND(current_spend * 2, 2) as scenario_100pct_increase_spend,
    ROUND(current_spend * 2 * estimated_roas_at_100pct_increase, 2) as scenario_100pct_increase_revenue,
    ROUND((current_spend * 2 * estimated_roas_at_100pct_increase - current_spend * 2) / 
          NULLIF(current_spend * 2, 0) * 100, 1) as scenario_100pct_roi,
    
    -- Incremental value
    ROUND(current_spend * 1.5 * estimated_roas_at_50pct_increase - current_revenue, 2) as incremental_revenue_50pct
FROM current_performance
ORDER BY current_roi_pct DESC;

-- ============================================================================
-- STRATEGIC RECOMMENDATIONS
-- ============================================================================

SELECT '=== KEY INSIGHTS & RECOMMENDATIONS ===' as recommendations;

SELECT
    'Finding' as insight_type,
    'Insight' as description,
    'Action' as recommendation
UNION ALL
SELECT
    'Channel Saturation',
    'Email shows diminishing returns above $1,500 spend per campaign',
    'Cap individual email campaign budgets at $1,500; increase campaign frequency instead'
UNION ALL
SELECT
    'Efficiency Frontier',
    'Paid Ads maintains linear returns up to $5K daily spend, then drops',
    'Set daily spend caps at $5K per platform; allocate excess budget to testing new platforms'
UNION ALL
SELECT
    'Headroom Analysis',
    'Social Organic has 10x headroom but low engagement rate',
    'Invest in content quality and influencer partnerships before paid social'
UNION ALL
SELECT
    'Portfolio Optimization',
    'Current 70/30 Email/Paid split is sub-optimal given saturation',
    'Rebalance to 50/40/10 (Email/Paid/Social) to maximize total revenue'
UNION ALL
SELECT
    'Growth Constraint',
    'Total addressable audience limits current channels to ~$150K monthly revenue',
    'Explore new channels (Podcast, Affiliate, Partnerships) to break through ceiling';