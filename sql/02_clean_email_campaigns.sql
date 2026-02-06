-- ============================================================================
-- STEP 2: CLEAN EMAIL CAMPAIGNS DATA
-- ============================================================================
-- Purpose: Clean and transform email campaign data
-- Techniques: CTEs, Window Functions, Regex, Data Type Conversions
-- NOTE: This DROP/CREATE pattern is for development.
-- In production, would use staging tables or incremental updates for better version control and to avoid data loss and support concurrent users.

DROP TABLE IF EXISTS clean_email_campaigns CASCADE;
CREATE TABLE clean_email_campaigns AS
WITH deduplicated AS (
    -- Remove duplicates using ROW_NUMBER window function
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY TRIM(campaign_id), campaign_name, send_date 
               ORDER BY emails_sent DESC
           ) as rn
    FROM staging_email_campaigns
),
cleaned AS (
    SELECT
        TRIM(campaign_id) as campaign_id,
        TRIM(campaign_name) as campaign_name,
        -- Standardize date formats to YYYY-MM-DD
        CASE 
            WHEN send_date ~ E'^\\d{4}-\\d{2}-\\d{2}$' THEN send_date::DATE
            WHEN send_date ~ E'^\\d{2}/\\d{2}/\\d{4}$' THEN TO_DATE(send_date, 'MM/DD/YYYY')
            WHEN send_date ~ E'^\\d{2}-\\d{2}-\\d{4}$' THEN TO_DATE(send_date, 'DD-MM-YYYY')
            ELSE NULL
        END as send_date,
        -- Convert to integers, handling NULLs, empty strings, and decimals
        FLOOR(NULLIF(TRIM(emails_sent), '')::NUMERIC)::INTEGER as emails_sent,
        FLOOR(NULLIF(TRIM(delivered), '')::NUMERIC)::INTEGER as delivered,
        FLOOR(NULLIF(TRIM(opens), '')::NUMERIC)::INTEGER as opens,
        FLOOR(NULLIF(TRIM(clicks), '')::NUMERIC)::INTEGER as clicks,
        FLOOR(NULLIF(TRIM(unsubscribes), '')::NUMERIC)::INTEGER as unsubscribes,
        NULLIF(TRIM(cost), '')::NUMERIC(10,2) as cost
    FROM deduplicated
    WHERE rn = 1  -- Keep only first occurrence
)
SELECT
    campaign_id,
    campaign_name,
    send_date,
    emails_sent,
    -- Fix logical error: delivered can't exceed sent
    CASE 
        WHEN delivered > emails_sent THEN emails_sent
        ELSE delivered
    END as delivered,
    -- Opens can't exceed delivered
    CASE 
        WHEN opens > COALESCE(delivered, emails_sent) THEN COALESCE(delivered, emails_sent)
        ELSE opens
    END as opens,
    -- Clicks can't exceed opens
    CASE 
        WHEN clicks > COALESCE(opens, 0) THEN opens
        ELSE clicks
    END as clicks,
    unsubscribes,
    cost,
    -- Calculate derived metrics
    ROUND(COALESCE(opens::NUMERIC / NULLIF(delivered, 0), 0) * 100, 2) as open_rate_pct,
    ROUND(COALESCE(clicks::NUMERIC / NULLIF(opens, 0), 0) * 100, 2) as click_through_rate_pct,
    ROUND(COALESCE(cost / NULLIF(emails_sent, 0), 0), 4) as cost_per_email
FROM cleaned
WHERE campaign_id IS NOT NULL;

-- Create index for joins
CREATE INDEX idx_email_campaign_id ON clean_email_campaigns(campaign_id);
CREATE INDEX idx_email_send_date ON clean_email_campaigns(send_date);

-- Final Cleaned Table
SELECT * FROM clean_email_campaigns;