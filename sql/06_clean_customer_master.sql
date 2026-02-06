-- ============================================================================
-- CLEAN CUSTOMER MASTER DATA
-- Purpose: Clean and transform customer master data
-- Techniques: Deduplication, age validation, boolean standardization
-- ============================================================================

DROP TABLE IF EXISTS clean_customer_master CASCADE;
CREATE TABLE clean_customer_master AS
WITH deduplicated AS (
    -- Deduplicate customers, keeping most recent/complete record
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY TRIM(customer_id) 
               ORDER BY 
                   CASE WHEN age IS NOT NULL THEN 1 ELSE 0 END DESC,
                   CASE WHEN state IS NOT NULL THEN 1 ELSE 0 END DESC,
                   signup_date DESC
           ) as rn
    FROM staging_customer_master
),
cleaned AS (
    SELECT
        TRIM(customer_id) as customer_id,
        signup_date::DATE as signup_date,
        -- Clean age: remove unrealistic values
        CASE 
            WHEN FLOOR(NULLIF(TRIM(age), '')::NUMERIC)::INTEGER BETWEEN 18 AND 100 THEN FLOOR(NULLIF(TRIM(age), '')::NUMERIC)::INTEGER
            ELSE NULL
        END as age,
        UPPER(TRIM(state)) as state,
        TRIM(customer_segment) as customer_segment,
        -- Standardize boolean values
        CASE 
            WHEN UPPER(TRIM(COALESCE(email_opt_in::TEXT, 'false'))) IN ('TRUE', 'YES', '1', 'T', 'Y') THEN TRUE
            ELSE FALSE
        END as email_opt_in,
        FLOOR(NULLIF(TRIM(lifetime_orders), '')::NUMERIC)::INTEGER as lifetime_orders
    FROM deduplicated
    WHERE rn = 1
)
SELECT
    customer_id,
    signup_date,
    age,
    state,
    customer_segment,
    email_opt_in,
    lifetime_orders,
    -- Calculate customer tenure
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, signup_date)) as customer_tenure_years,
    -- Age group segmentation
    CASE 
        WHEN age BETWEEN 18 AND 24 THEN '18-24'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        WHEN age BETWEEN 55 AND 64 THEN '55-64'
        WHEN age >= 65 THEN '65+'
        ELSE 'Unknown'
    END as age_group
FROM cleaned
WHERE customer_id IS NOT NULL;

-- Create indexes
CREATE INDEX idx_customer_id ON clean_customer_master(customer_id);
CREATE INDEX idx_customer_segment ON clean_customer_master(customer_segment);
CREATE INDEX idx_customer_state ON clean_customer_master(state);

-- Verify results
SELECT 
    'Clean Customer Master' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT customer_id) as unique_customers,
    COUNT(*) - COUNT(age) as missing_age,
    COUNT(*) - COUNT(state) as missing_state,
    COUNT(*) FILTER (WHERE email_opt_in = TRUE) as opted_in_count,
    MIN(signup_date) as earliest_signup,
    MAX(signup_date) as latest_signup
FROM clean_customer_master;

-- Final Cleaned Table
SELECT * FROM clean_customer_master 