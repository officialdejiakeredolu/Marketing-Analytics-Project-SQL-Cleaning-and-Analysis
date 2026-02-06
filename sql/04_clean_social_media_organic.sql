-- ============================================================================
-- CLEAN SOCIAL MEDIA ORGANIC DATA
-- Purpose: Clean and transform social media organic data
-- Techniques: Regex parsing of nested strings, engagement metric calculations
-- ============================================================================

DROP TABLE IF EXISTS clean_social_media_organic CASCADE;
CREATE TABLE clean_social_media_organic AS
WITH parsed_engagement AS (
    SELECT
        post_id,
        post_date,
        platform,
        post_type,
        impressions,
        engagement_string,
        likes,
        comments,
        shares,
        link_clicks,
        -- Parse nested engagement string using regex
        CASE 
            WHEN engagement_string IS NOT NULL THEN
                NULLIF(SUBSTRING(engagement_string FROM E'likes:(\\d+)'), '')::INTEGER
            ELSE NULL
        END as parsed_likes,
        CASE 
            WHEN engagement_string IS NOT NULL THEN
                NULLIF(SUBSTRING(engagement_string FROM E'comments:(\\d+)'), '')::INTEGER
            ELSE NULL
        END as parsed_comments,
        CASE 
            WHEN engagement_string IS NOT NULL THEN
                NULLIF(SUBSTRING(engagement_string FROM E'shares:(\\d+)'), '')::INTEGER
            ELSE NULL
        END as parsed_shares
    FROM staging_social_media_organic
)
SELECT
    TRIM(post_id) as post_id,
    post_date::DATE as post_date,
    INITCAP(TRIM(platform)) as platform,
    TRIM(post_type) as post_type,
    FLOOR(NULLIF(TRIM(impressions), '')::NUMERIC)::INTEGER as impressions,
    -- Use parsed values if engagement_string exists, otherwise use individual columns
    COALESCE(parsed_likes, FLOOR(NULLIF(TRIM(likes), '')::NUMERIC)::INTEGER) as likes,
    COALESCE(parsed_comments, FLOOR(NULLIF(TRIM(comments), '')::NUMERIC)::INTEGER) as comments,
    COALESCE(parsed_shares, FLOOR(NULLIF(TRIM(shares), '')::NUMERIC)::INTEGER) as shares,
    FLOOR(NULLIF(TRIM(link_clicks), '')::NUMERIC)::INTEGER as link_clicks,
    -- Calculate total engagement
    COALESCE(parsed_likes, FLOOR(NULLIF(TRIM(likes), '')::NUMERIC)::INTEGER, 0) +
    COALESCE(parsed_comments, FLOOR(NULLIF(TRIM(comments), '')::NUMERIC)::INTEGER, 0) +
    COALESCE(parsed_shares, FLOOR(NULLIF(TRIM(shares), '')::NUMERIC)::INTEGER, 0) as total_engagement,
    -- Calculate engagement rate
    ROUND(
        COALESCE(
            (COALESCE(parsed_likes, FLOOR(NULLIF(TRIM(likes), '')::NUMERIC)::INTEGER, 0) +
             COALESCE(parsed_comments, FLOOR(NULLIF(TRIM(comments), '')::NUMERIC)::INTEGER, 0) +
             COALESCE(parsed_shares, FLOOR(NULLIF(TRIM(shares), '')::NUMERIC)::INTEGER, 0))::NUMERIC 
            / NULLIF(FLOOR(NULLIF(TRIM(impressions), '')::NUMERIC)::INTEGER, 0), 
            0
        ) * 100, 
        2
    ) as engagement_rate_pct
FROM parsed_engagement
WHERE post_id IS NOT NULL;

-- Create indexes
CREATE INDEX idx_social_post_date ON clean_social_media_organic(post_date);
CREATE INDEX idx_social_platform ON clean_social_media_organic(platform);

-- Verify results
SELECT 
    'Clean Social Media' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT platform) as unique_platforms,
    AVG(engagement_rate_pct) as avg_engagement_rate,
    MIN(post_date) as earliest_date,
    MAX(post_date) as latest_date
FROM clean_social_media_organic;

-- Final Cleaned Table
SELECT * FROM clean_social_media_organic