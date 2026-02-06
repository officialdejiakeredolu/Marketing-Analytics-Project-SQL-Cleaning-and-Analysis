-- ============================================================================
-- 01_CREATE_STAGING_TABLES.SQL
-- ============================================================================
-- Purpose: Create staging tables with flexible VARCHAR columns to accept messy data
-- Author: Deji Akeredolu
-- ============================================================================

-- Create staging tables with flexible VARCHAR types to accept messy data

DROP TABLE IF EXISTS staging_email_campaigns CASCADE;
CREATE TABLE staging_email_campaigns (
    campaign_id VARCHAR(50),
    campaign_name VARCHAR(100),
    send_date VARCHAR(50),
    emails_sent VARCHAR(50),
    delivered VARCHAR(50),
    opens VARCHAR(50),
    clicks VARCHAR(50),
    unsubscribes VARCHAR(50),
    cost VARCHAR(50)
);

DROP TABLE IF EXISTS staging_paid_ads CASCADE;
CREATE TABLE staging_paid_ads (
    ad_id VARCHAR(50),
    date VARCHAR(50),
    platform VARCHAR(50),
    ad_type VARCHAR(50),
    impressions VARCHAR(50),
    clicks VARCHAR(50),
    spend VARCHAR(50),
    revenue VARCHAR(50),
    conversions VARCHAR(50)
);

DROP TABLE IF EXISTS staging_social_media_organic CASCADE;
CREATE TABLE staging_social_media_organic (
    post_id VARCHAR(50),
    post_date VARCHAR(50),
    platform VARCHAR(50),
    post_type VARCHAR(50),
    impressions VARCHAR(50),
    engagement_string VARCHAR(200),
    likes VARCHAR(50),
    comments VARCHAR(50),
    shares VARCHAR(50),
    link_clicks VARCHAR(50)
);

DROP TABLE IF EXISTS staging_customer_transactions CASCADE;
CREATE TABLE staging_customer_transactions (
    transaction_id VARCHAR(50),
    customer_id VARCHAR(50),
    transaction_date VARCHAR(50),
    order_value VARCHAR(50),
    items_purchased VARCHAR(50),
    referral_source VARCHAR(50),
    campaign_reference VARCHAR(50),
    discount_applied VARCHAR(50)
);

DROP TABLE IF EXISTS staging_customer_master CASCADE;
CREATE TABLE staging_customer_master (
    customer_id VARCHAR(50),
    signup_date VARCHAR(50),
    age VARCHAR(50),
    state VARCHAR(10),
    customer_segment VARCHAR(50),
    email_opt_in VARCHAR(20),
    lifetime_orders VARCHAR(50)
);

-- Verify tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE 'staging_%'
ORDER BY table_name;