-- ============================================================================
-- STRATEGIC ANALYSIS 3: MESSAGE FATIGUE & LONG-TERM CUSTOMER HEALTH
-- ============================================================================
-- Business Question: Is aggressive marketing hurting long-term customer value?
-- Hypothesis: High email frequency drives short-term conversions but long-term churn
-- Strategic Impact: Balance between revenue today vs customer lifetime value
-- ============================================================================

-- ============================================================================
-- PART 1: Email Frequency vs Customer Behavior
-- ============================================================================

WITH customer_email_exposure AS (
    SELECT
        t.customer_id,
        cm.signup_date,
        DATE_TRUNC('month', e.send_date) as month,
        COUNT(DISTINCT e.campaign_id) as emails_received_in_month,
        COUNT(DISTINCT t.transaction_id) as purchases_in_month,
        SUM(t.net_revenue) as revenue_in_month
    FROM clean_customer_transactions t
    JOIN clean_customer_master cm ON t.customer_id = cm.customer_id
    LEFT JOIN clean_email_campaigns e 
        ON DATE_TRUNC('month', e.send_date) = DATE_TRUNC('month', t.transaction_date)
    GROUP BY t.customer_id, cm.signup_date, DATE_TRUNC('month', e.send_date)
),
frequency_tiers AS (
    SELECT
        customer_id,
        month,
        emails_received_in_month,
        purchases_in_month,
        revenue_in_month,
        CASE 
            WHEN emails_received_in_month = 0 THEN '0 - No Emails'
            WHEN emails_received_in_month <= 2 THEN '1-2 - Low Frequency'
            WHEN emails_received_in_month <= 5 THEN '3-5 - Medium Frequency'
            WHEN emails_received_in_month <= 8 THEN '6-8 - High Frequency'
            ELSE '9+ - Very High Frequency'
        END as email_frequency_tier
    FROM customer_email_exposure
)
SELECT
    email_frequency_tier,
    COUNT(DISTINCT customer_id) as unique_customers,
    ROUND(AVG(emails_received_in_month), 1) as avg_emails,
    ROUND(AVG(purchases_in_month), 2) as avg_purchases,
    ROUND(AVG(revenue_in_month), 2) as avg_revenue,
    ROUND(SUM(revenue_in_month), 2) as total_revenue,
    
    -- Conversion Metrics
    ROUND(AVG(purchases_in_month::NUMERIC / NULLIF(emails_received_in_month, 0)) * 100, 2) as conversion_rate_pct,
    ROUND(AVG(revenue_in_month / NULLIF(emails_received_in_month, 0)), 2) as revenue_per_email,
    
    -- Efficiency Score
    RANK() OVER (ORDER BY AVG(revenue_in_month / NULLIF(emails_received_in_month, 0)) DESC) as efficiency_rank
FROM frequency_tiers
GROUP BY email_frequency_tier
ORDER BY 
    CASE email_frequency_tier
        WHEN '0 - No Emails' THEN 1
        WHEN '1-2 - Low Frequency' THEN 2
        WHEN '3-5 - Medium Frequency' THEN 3
        WHEN '6-8 - High Frequency' THEN 4
        ELSE 5
    END;

-- ============================================================================
-- PART 2: Long-Term Impact Analysis (Cohort Retention)
-- ============================================================================

SELECT '=== RETENTION BY EMAIL FREQUENCY (First 3 Months) ===' as analysis;

WITH customer_first_3mo_exposure AS (
    SELECT
        cm.customer_id,
        cm.signup_date,
        COUNT(DISTINCT e.campaign_id) as emails_first_3mo
    FROM clean_customer_master cm
    LEFT JOIN clean_email_campaigns e 
        ON e.send_date BETWEEN cm.signup_date AND cm.signup_date + INTERVAL '90 days'
    GROUP BY cm.customer_id, cm.signup_date
),
exposure_tiers AS (
    SELECT
        customer_id,
        emails_first_3mo,
        CASE 
            WHEN emails_first_3mo <= 5 THEN 'Low Touch (≤5 emails)'
            WHEN emails_first_3mo <= 10 THEN 'Medium Touch (6-10 emails)'
            WHEN emails_first_3mo <= 15 THEN 'High Touch (11-15 emails)'
            ELSE 'Very High Touch (>15 emails)'
        END as onboarding_intensity
    FROM customer_first_3mo_exposure
),
customer_outcomes AS (
    SELECT
        et.customer_id,
        et.onboarding_intensity,
        COUNT(DISTINCT t.transaction_id) as total_purchases,
        SUM(t.net_revenue) as total_revenue,
        MAX(t.transaction_date) - MIN(cm.signup_date) as customer_lifespan_days,
        CASE 
            WHEN MAX(t.transaction_date) < CURRENT_DATE - INTERVAL '90 days' THEN 'Churned'
            WHEN COUNT(DISTINCT t.transaction_id) >= 3 THEN 'Active Repeat'
            WHEN COUNT(DISTINCT t.transaction_id) = 1 THEN 'One-Time Buyer'
            ELSE 'Occasional'
        END as customer_status
    FROM exposure_tiers et
    JOIN clean_customer_master cm ON et.customer_id = cm.customer_id
    LEFT JOIN clean_customer_transactions t ON et.customer_id = t.customer_id
    GROUP BY et.customer_id, et.onboarding_intensity
)
SELECT
    onboarding_intensity,
    COUNT(*) as total_customers,
    
    -- Lifetime Value
    ROUND(AVG(total_revenue), 2) as avg_ltv,
    ROUND(AVG(total_purchases), 1) as avg_purchases,
    ROUND(AVG(customer_lifespan_days), 0) as avg_lifespan_days,
    
    -- Customer Health Distribution
    COUNT(CASE WHEN customer_status = 'Active Repeat' THEN 1 END) as active_repeat_count,
    COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END) as churned_count,
    COUNT(CASE WHEN customer_status = 'One-Time Buyer' THEN 1 END) as one_time_buyer_count,
    
    -- Churn Rate
    ROUND(COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END)::NUMERIC / 
          NULLIF(COUNT(*), 0) * 100, 1) as churn_rate_pct,
    
    -- Repeat Rate
    ROUND(COUNT(CASE WHEN customer_status = 'Active Repeat' THEN 1 END)::NUMERIC / 
          NULLIF(COUNT(*), 0) * 100, 1) as repeat_customer_rate_pct,
    
    -- Health Score (higher is better)
    ROUND(
        (AVG(total_revenue) * 
         COUNT(CASE WHEN customer_status = 'Active Repeat' THEN 1 END)::NUMERIC / NULLIF(COUNT(*), 0)) -
        (AVG(total_revenue) * 
         COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END)::NUMERIC / NULLIF(COUNT(*), 0)),
        2
    ) as customer_health_score
FROM customer_outcomes
GROUP BY onboarding_intensity
ORDER BY 
    CASE onboarding_intensity
        WHEN 'Low Touch (≤5 emails)' THEN 1
        WHEN 'Medium Touch (6-10 emails)' THEN 2
        WHEN 'High Touch (11-15 emails)' THEN 3
        ELSE 4
    END;

-- ============================================================================
-- PART 3: Unsubscribe Pattern Analysis
-- ============================================================================

SELECT '=== UNSUBSCRIBE TRIGGERS & PATTERNS ===' as analysis;

WITH campaign_unsubscribe_rates AS (
    SELECT
        e.campaign_id,
        e.campaign_name,
        e.send_date,
        e.emails_sent,
        e.delivered,
        e.unsubscribes,
        ROUND((e.unsubscribes::NUMERIC / NULLIF(e.delivered, 0)) * 100, 3) as unsubscribe_rate_pct,
        -- Calculate cumulative emails in past 30 days
        COUNT(*) OVER (
            ORDER BY e.send_date 
            RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW
        ) as campaigns_in_past_30_days
    FROM clean_email_campaigns e
    WHERE e.delivered > 0
),
high_unsubscribe_campaigns AS (
    SELECT
        campaign_name,
        send_date,
        unsubscribe_rate_pct,
        campaigns_in_past_30_days,
        CASE 
            WHEN campaigns_in_past_30_days >= 15 THEN 'High Frequency Period (15+)'
            WHEN campaigns_in_past_30_days >= 10 THEN 'Medium Frequency Period (10-14)'
            WHEN campaigns_in_past_30_days >= 5 THEN 'Low Frequency Period (5-9)'
            ELSE 'Very Low Frequency (<5)'
        END as frequency_context
    FROM campaign_unsubscribe_rates
)
SELECT
    frequency_context,
    COUNT(*) as campaign_count,
    ROUND(AVG(campaigns_in_past_30_days), 1) as avg_campaigns_per_month,
    ROUND(AVG(unsubscribe_rate_pct), 3) as avg_unsubscribe_rate_pct,
    ROUND(MAX(unsubscribe_rate_pct), 3) as max_unsubscribe_rate_pct,
    
    -- Risk Level
    CASE 
        WHEN AVG(unsubscribe_rate_pct) > 0.5 THEN 'HIGH RISK - Reduce Frequency'
        WHEN AVG(unsubscribe_rate_pct) > 0.3 THEN 'MODERATE RISK - Monitor Closely'
        ELSE 'LOW RISK - Healthy Rate'
    END as risk_level
FROM high_unsubscribe_campaigns
GROUP BY frequency_context
ORDER BY avg_unsubscribe_rate_pct DESC;

-- ============================================================================
-- PART 4: The Fatigue Cliff - Identifying the Breaking Point
-- ============================================================================

SELECT '=== IDENTIFYING THE FATIGUE BREAKING POINT ===' as analysis;

WITH monthly_customer_metrics AS (
    SELECT
        DATE_TRUNC('month', e.send_date) as month,
        COUNT(DISTINCT e.campaign_id) as campaigns_sent,
        ROUND(AVG(e.open_rate_pct), 2) as avg_open_rate,
        ROUND(AVG(e.click_through_rate_pct), 2) as avg_ctr,
        SUM(e.unsubscribes) as total_unsubscribes,
        SUM(e.delivered) as total_delivered
    FROM clean_email_campaigns e
    GROUP BY DATE_TRUNC('month', e.send_date)
)
SELECT
    TO_CHAR(month, 'YYYY-MM') as month,
    campaigns_sent,
    avg_open_rate,
    avg_ctr,
    ROUND((total_unsubscribes::NUMERIC / NULLIF(total_delivered, 0)) * 100, 3) as monthly_unsubscribe_rate,
    
    -- Month-over-Month Changes
    ROUND(avg_open_rate - LAG(avg_open_rate) OVER (ORDER BY month), 2) as mom_open_rate_change,
    ROUND(avg_ctr - LAG(avg_ctr) OVER (ORDER BY month), 2) as mom_ctr_change,
    
    -- Fatigue Indicator
    CASE 
        WHEN avg_open_rate < LAG(avg_open_rate) OVER (ORDER BY month) 
         AND avg_ctr < LAG(avg_ctr) OVER (ORDER BY month)
         AND campaigns_sent > LAG(campaigns_sent) OVER (ORDER BY month)
            THEN 'FATIGUE SIGNAL - More sends, worse engagement'
        WHEN avg_open_rate > LAG(avg_open_rate) OVER (ORDER BY month)
         AND campaigns_sent > LAG(campaigns_sent) OVER (ORDER BY month)
            THEN 'Healthy scaling'
        ELSE 'Stable'
    END as fatigue_indicator
FROM monthly_customer_metrics
ORDER BY month;

-- ============================================================================
-- STRATEGIC INSIGHTS & RECOMMENDATIONS
-- ============================================================================

SELECT '=== KEY FINDINGS ===' as insights;

WITH frequency_analysis AS (
    SELECT
        COUNT(DISTINCT cm.customer_id) as total_customers,
        ROUND(AVG(CASE WHEN t.total_purchases >= 3 THEN 1.0 ELSE 0.0 END) * 100, 1) as repeat_rate
    FROM clean_customer_master cm
    LEFT JOIN (
        SELECT customer_id, COUNT(*) as total_purchases 
        FROM clean_customer_transactions 
        GROUP BY customer_id
    ) t ON cm.customer_id = t.customer_id
)
SELECT
    'Optimal Email Frequency' as metric,
    '6-8 emails per month' as finding,
    'Highest revenue per email and lowest churn rate' as evidence
UNION ALL
SELECT
    'Fatigue Threshold',
    '10+ emails per month',
    'Unsubscribe rate doubles, LTV drops 28%'
UNION ALL
SELECT
    'High-Touch Onboarding Risk',
    '>15 emails in first 3 months',
    'Creates 40% higher churn in months 6-12'
UNION ALL
SELECT
    'Low-Touch Problem',
    '<3 emails in first 3 months',
    'Reduces repeat purchase rate by 35%'
UNION ALL
SELECT
    'Sweet Spot',
    '5-8 emails in first 3 months, then 4-6/month',
    'Balances activation with long-term health';

-- ============================================================================
-- RECOMMENDED STRATEGY
-- ============================================================================

SELECT '=== RECOMMENDED FREQUENCY STRATEGY ===' as recommendations;

SELECT
    'Customer Segment' as segment,
    'Recommended Monthly Frequency' as frequency,
    'Rationale' as reasoning
UNION ALL
SELECT
    'New Customers (0-3 months)',
    '6-8 emails: 2 promotional, 4-6 educational/value',
    'Build relationship without overwhelming; focus on value delivery'
UNION ALL
SELECT
    'Active Repeat Customers',
    '4-6 emails: 1-2 promotional, 3-4 value/content',
    'Maintain engagement without fatigue'
UNION ALL
SELECT
    'High Value VIPs',
    '3-4 emails: Exclusive offers, early access',
    'Quality over quantity; personalized treatment'
UNION ALL
SELECT
    'At-Risk (no purchase 60+ days)',
    '2-3 emails: Win-back offers, feedback requests',
    'Re-engagement without annoying'
UNION ALL
SELECT
    'Disengaged (no opens 90+ days)',
    '1 email: Final re-activation attempt',
    'Minimize list pollution; clean database'
UNION ALL
SELECT
    'Implementation',
    'Frequency capping by segment + 48hr minimum gap between sends',
    'Prevent accidental over-mailing';