-- ============================================================================
-- CLEAN PAID ADS DATA
-- Purpose: Clean and transform paid advertising data
-- Techniques: Platform name standardization, currency cleaning, metric calculations
-- ============================================================================

DROP TABLE IF EXISTS clean_paid_ads CASCADE;
CREATE TABLE clean_paid_ads AS
WITH cleaned AS (
    SELECT
        TRIM(ad_id) as ad_id,
        -- Standardize date formats
        CASE 
            WHEN date ~ E'^\\d{4}-\\d{2}-\\d{2}$' THEN date::DATE
            WHEN date ~ E'^\\d{2}-\\d{2}-\\d{4}$' THEN TO_DATE(date, 'MM-DD-YYYY')
            ELSE NULL
        END as ad_date,
        -- Standardize platform names (case-insensitive, handle variations)
        CASE 
            WHEN UPPER(REPLACE(platform, '_', ' ')) LIKE '%GOOGLE%' THEN 'Google Ads'
            WHEN UPPER(platform) IN ('FACEBOOK', 'FB') THEN 'Facebook'
            WHEN UPPER(platform) = 'INSTAGRAM' THEN 'Instagram'
            WHEN UPPER(platform) = 'LINKEDIN' THEN 'LinkedIn'
            ELSE INITCAP(TRIM(platform))
        END as platform,
        TRIM(ad_type) as ad_type,
        FLOOR(NULLIF(TRIM(impressions), '')::NUMERIC)::INTEGER as impressions,
        FLOOR(NULLIF(TRIM(clicks), '')::NUMERIC)::INTEGER as clicks,
        NULLIF(TRIM(spend), '')::NUMERIC(10,2) as spend,
        -- Clean revenue: remove $ symbol and convert to numeric
        CASE 
            WHEN revenue ~ E'^\\$' THEN REPLACE(revenue, '$', '')::NUMERIC(10,2)
            WHEN NULLIF(TRIM(revenue), '') IS NOT NULL THEN revenue::NUMERIC(10,2)
            ELSE NULL
        END as revenue,
        -- Convert empty strings to NULL for conversions
        CASE 
            WHEN TRIM(conversions) = '' THEN NULL
            ELSE FLOOR(NULLIF(TRIM(conversions), '')::NUMERIC)::INTEGER
        END as conversions
    FROM staging_paid_ads
)
SELECT
    ad_id,
    ad_date,
    platform,
    ad_type,
    impressions,
    clicks,
    spend,
    revenue,
    conversions,
    -- Calculate derived metrics
    ROUND(COALESCE(clicks::NUMERIC / NULLIF(impressions, 0), 0) * 100, 2) as ctr_pct,
    ROUND(COALESCE(spend / NULLIF(clicks, 0), 0), 2) as cpc,
    ROUND(COALESCE(revenue / NULLIF(spend, 0), 0), 2) as roas,
    ROUND(COALESCE((revenue - spend) / NULLIF(spend, 0), 0) * 100, 2) as roi_pct
FROM cleaned
WHERE ad_id IS NOT NULL;

-- Create indexes
CREATE INDEX idx_paid_ads_date ON clean_paid_ads(ad_date);
CREATE INDEX idx_paid_ads_platform ON clean_paid_ads(platform);

-- Verify results
SELECT 
    'Clean Paid Ads' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT platform) as unique_platforms,
    MIN(ad_date) as earliest_date,
    MAX(ad_date) as latest_date
FROM clean_paid_ads;

-- Final Cleaned Table
SELECT * FROM clean_paid_ads