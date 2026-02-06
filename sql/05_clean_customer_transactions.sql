-- ============================================================================
-- CLEAN CUSTOMER TRANSACTIONS DATA
-- Purpose: Clean and transform customer transaction data
-- Techniques: Referral source standardization, net revenue calculation
-- ============================================================================

DROP TABLE IF EXISTS clean_customer_transactions CASCADE;
CREATE TABLE clean_customer_transactions AS
WITH cleaned AS (
    SELECT
        TRIM(transaction_id) as transaction_id,
        TRIM(customer_id) as customer_id,
        transaction_date::DATE as transaction_date,
        NULLIF(TRIM(order_value), '')::NUMERIC(10,2) as order_value,
        FLOOR(NULLIF(TRIM(items_purchased), '')::NUMERIC)::INTEGER as items_purchased,
        -- Standardize referral sources
        CASE 
            WHEN UPPER(TRIM(COALESCE(referral_source, 'unknown'))) IN ('', 'UNKNOWN') THEN 'Unknown'
            WHEN UPPER(TRIM(referral_source)) = 'EMAIL' THEN 'Email'
            WHEN UPPER(REPLACE(TRIM(referral_source), '_', ' ')) LIKE '%PAID%SEARCH%' THEN 'Paid Search'
            WHEN UPPER(TRIM(referral_source)) = 'SOCIAL' THEN 'Social'
            WHEN UPPER(TRIM(referral_source)) = 'ORGANIC' THEN 'Organic'
            WHEN UPPER(TRIM(referral_source)) = 'DIRECT' THEN 'Direct'
            ELSE INITCAP(TRIM(referral_source))
        END as referral_source,
        NULLIF(TRIM(campaign_reference), '') as campaign_reference,
        COALESCE(NULLIF(TRIM(discount_applied), '')::NUMERIC(10,2), 0) as discount_applied
    FROM staging_customer_transactions
)
SELECT
    transaction_id,
    customer_id,
    transaction_date,
    order_value,
    items_purchased,
    referral_source,
    campaign_reference,
    discount_applied,
    -- Calculate net revenue
    order_value - discount_applied as net_revenue,
    -- Calculate average order value per item
    ROUND(order_value / NULLIF(items_purchased, 0), 2) as avg_item_value
FROM cleaned
WHERE transaction_id IS NOT NULL 
  AND customer_id IS NOT NULL;

-- Create indexes for joins
CREATE INDEX idx_trans_customer_id ON clean_customer_transactions(customer_id);
CREATE INDEX idx_trans_date ON clean_customer_transactions(transaction_date);
CREATE INDEX idx_trans_campaign_ref ON clean_customer_transactions(campaign_reference);
CREATE INDEX idx_trans_referral_source ON clean_customer_transactions(referral_source);

-- Verify results
SELECT 
    'Clean Transactions' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT customer_id) as unique_customers,
    COUNT(DISTINCT referral_source) as unique_sources,
    ROUND(SUM(net_revenue), 2) as total_revenue,
    MIN(transaction_date) as earliest_transaction,
    MAX(transaction_date) as latest_transaction
FROM clean_customer_transactions;

-- Final Cleaned Table
SELECT * FROM clean_customer_transactions