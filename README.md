# Marketing-Analytics-Project-SQL-Cleaning-and-Analysis
## Marketing analytics portfolio project to showcase SQL acumen, domain knowledge, and data curiosity.

**Summary:**  
End-to-end marketing analytics project using PostgreSQL to clean, unify, and analyze multi-channel marketing data (email, paid ads, organic social). The project focuses on realistic data quality issues, attribution tradeoffs, and translating SQL outputs into business decisions.

**Key Skills Demonstrated**
- Advanced SQL (CTEs, window functions, regex, attribution logic, aggregations)
- Data cleaning & validation at scale
- Marketing analytics (ROI, LTV, churn, saturation)
- Business-oriented insight generation

**Tech Stack:** PostgreSQL, pgAdmin 4, VSCode (python for hypotheticla data generation)

 Table of Contents

1. [Business Context](#business-context)
2. [Dataset Overview](#dataset-overview)
3. [Key Questions](#key-questions)
4. [Approach & Assumptions](#approach--assumptions)
5. [Example Queries](#example-queries)
6. [Key Insights & Business Recommendations](#key-insights--business-recommendations)
7. [How to Run Locally](#how-to-run-locally)


## Business Context

A marketing team collects data across multiple channels (email campaigns, paid ads, and organic social media) but the data lives in separate systems with inconsistent formats, missing values, and duplicate records. Before any meaningful analysis can happen, the data needs to be cleaned, standardized, and unified.
This project simulates a real-world scenario where a data analyst must:

Ingest and clean five messy datasets from different marketing platforms
Standardize inconsistent formats (dates, categories, booleans, currency)
Deduplicate records and fix logical errors
Join data across tables to build a unified view of marketing performance
Answer strategic business questions that go beyond surface-level metrics

The goal is not just to calculate metrics, it's to uncover why certain metrics look the way they do and what the business should do differently.

## Dataset Overview

### Dataset Tables

| Table Name                     | Description                           | Approx. Rows |
|--------------------------------|---------------------------------------|--------------|
| staging_email_campaigns        | Raw email campaign metrics             | ~55          |
| staging_paid_ads               | Raw paid advertising data              | ~200         |
| staging_social_media_organic   | Raw organic social posts               | ~150         |
| staging_customer_transactions  | Raw customer purchase records          | ~500         |
| staging_customer_master        | Raw customer demographics              | ~820         |


### Schemas
<details>
<summary><strong>Clean Table Schemas (After Cleaning)</strong></summary>

### `clean_email_campaigns`

| Column | Type | Description |
|------|------|-------------|
| campaign_id | VARCHAR | Unique campaign identifier |
| campaign_name | VARCHAR | Campaign type (Newsletter, Promotional, etc.) |
| send_date | DATE | Standardized send date |
| emails_sent | INTEGER | Total emails sent |
| delivered | INTEGER | Emails delivered (capped at emails_sent) |
| opens | INTEGER | Emails opened |
| clicks | INTEGER | Links clicked |
| unsubscribes | INTEGER | Unsubscribe count |
| cost | NUMERIC | Campaign cost |
| open_rate_pct | NUMERIC | Open rate percentage |
| click_through_rate_pct | NUMERIC | CTR percentage |
| cost_per_email | NUMERIC | Cost efficiency metric |

---

### `clean_paid_ads`

| Column | Type | Description |
|------|------|-------------|
| ad_id | VARCHAR | Unique ad identifier |
| ad_date | DATE | Standardized ad date |
| platform | VARCHAR | Standardized platform name |
| ad_type | VARCHAR | Ad type (Search, Display, Video, etc.) |
| impressions | INTEGER | Total impressions |
| clicks | INTEGER | Total clicks |
| spend | NUMERIC | Ad spend |
| revenue | NUMERIC | Attributed revenue (nullable) |
| conversions | INTEGER | Conversion count (nullable) |
| ctr_pct | NUMERIC | Click-through rate |
| cpc | NUMERIC | Cost per click |
| roas | NUMERIC | Return on ad spend |
| roi_pct | NUMERIC | Return on investment percentage |

---

### `clean_social_media_organic`

| Column | Type | Description |
|------|------|-------------|
| post_id | VARCHAR | Unique post identifier |
| post_date | DATE | Post date |
| platform | VARCHAR | Standardized platform name |
| post_type | VARCHAR | Post type (Image, Video, Carousel, etc.) |
| impressions | INTEGER | Total impressions |
| likes | INTEGER | Parsed from nested string or column |
| comments | INTEGER | Parsed from nested string or column |
| shares | INTEGER | Parsed from nested string or column |
| link_clicks | INTEGER | Link clicks (nullable) |
| total_engagement | INTEGER | Sum of likes + comments + shares |
| engagement_rate_pct | NUMERIC | Engagement rate percentage |

---

### `clean_customer_transactions`

| Column | Type | Description |
|------|------|-------------|
| transaction_id | VARCHAR | Unique transaction identifier |
| customer_id | VARCHAR | Customer foreign key |
| transaction_date | DATE | Transaction date |
| order_value | NUMERIC | Gross order value |
| items_purchased | INTEGER | Number of items |
| referral_source | VARCHAR | Standardized referral channel |
| campaign_reference | VARCHAR | Links to email campaign_id (nullable) |
| discount_applied | NUMERIC | Discount amount |
| net_revenue | NUMERIC | Revenue after discount |
| avg_item_value | NUMERIC | Order value per item |

---

### `clean_customer_master`

| Column | Type | Description |
|------|------|-------------|
| customer_id | VARCHAR | Unique customer identifier |
| signup_date | DATE | Account signup date |
| age | INTEGER | Customer age (validated 18–100) |
| state | VARCHAR | Standardized state code |
| customer_segment | VARCHAR | Business-assigned segment |
| email_opt_in | BOOLEAN | Standardized opt-in status |
| lifetime_orders | INTEGER | Total lifetime orders |
| customer_tenure_years | NUMERIC | Years since signup |
| age_group | VARCHAR | Derived age bracket |

</details>

### Data Quality Issues
<details>
<summary><strong>Data Quality Issues & Cleaning Techniques</strong></summary>

| Issue | Tables Affected | SQL Technique Used |
|------|-----------------|--------------------|
| Inconsistent date formats | All tables | Regex pattern matching + `TO_DATE()` |
| Duplicate records | Email, Customer Master | `ROW_NUMBER()` window function |
| Inconsistent category names | Paid Ads, Transactions | `CASE` + `UPPER()` + `REPLACE()` |
| Missing values (NULL / empty) | All tables | `NULLIF()` + `COALESCE()` |
| Decimal strings (`"21347.0"`) | All tables | `FLOOR(::NUMERIC)::INTEGER` |
| Currency symbols (`"$123.45"`) | Paid Ads | `REPLACE()` + regex |
| Logical errors (delivered > sent) | Email | `CASE WHEN` validation |
| Nested JSON-like strings | Social Media | `SUBSTRING()` with regex |
| Inconsistent booleans | Customer Master | `CASE` + `IN ('TRUE','YES','1')` |
| Unrealistic values (age < 18) | Customer Master | `BETWEEN` validation |

</details>

## Key Questions

### Standard Performance Questions
1. **Which marketing channel has the highest ROI?**
2. **What’s the typical customer journey from first touch to conversion?**
3. **Which email campaign types perform best?**
4. **How has performance changed month-over-month?**
5. **Which platforms drive the highest lifetime value (LTV) customers?**
6. **Which channels are best at acquisition vs. retention?**

<details>
<summary><strong>Strategic, Nuanced, and Edge-Case Questions</strong></summary>

1. **Are we training customers to only buy on discount?**  
  Do discount-acquired customers have lower lifetime value?

2. **Are high-ROI channels hitting saturation?**  
  Do we see diminishing returns at higher spend levels?

3. **Is aggressive email marketing hurting long-term customer health?**  
  Does high frequency drive short-term revenue but long-term churn?

4. **Do email campaigns convert because they persuade, or because they target already warm users?**

5. **Are certain customer segments more price-sensitive vs. trust-driven?**

6. **What role does each channel play in the funnel?**  
  (Upstream role vs. downstream role, intent capture, reinforcement, brand strength)

7. **Where does ROI break at scale?**  
  (Ad fatigue, diminishing returns)

8. **What would be recommended if the marketing budget were cut by a certain %?**

</details>

<details>
<summary><strong>Hypothetical insights if I were working with an actual company</strong></summary>

- Email shows high ROI, but mostly among existing customers, suggesting it functions as a retention channel rather than acquisition.

- Channel X has highest ROI today, but it's also our smallest channel with limited scale potential. Channel Y has 20% lower ROI but 10x reachable audience

- To delve deeper: A/B tests, survey users, conduct market/competitor research or work cross functionally with other teams to gather more business context

</details>

## Approach & Assumptions

<details>
<summary><strong>Analytical Approach</strong></summary>
 
- **Staging:** Load raw CSV data into staging tables using `VARCHAR` columns to accept inconsistent formats
- **Cleaning:** Transform staging data into clean tables using CTEs, window functions, and validation logic
- **Analysis:** Perform performance, attribution, and strategic analyses on cleaned data
- **Insights:** Translate analytical outputs into actionable business recommendations

</details>

<details>
<summary><strong>Assumptions</strong></summary>
 
- **Date validity:** Transactions occurring before customer signup dates are filtered out as data-entry errors
- **Revenue completeness:** No return or refund data is available; reported revenue may overstate true profit
- **Sample reliability:** Campaigns with fewer than 1,000 recipients may produce unstable metrics

</details>

<details>
<summary><strong>Key SQL Techniques Used</strong></summary>
 
- **CTEs:** Multi-step cleaning pipelines and readable query structure
- **Window Functions:** `ROW_NUMBER()` (deduplication), `RANK()` (performance ranking), `LAG()` (trend analysis)
- **Regex:** Date format detection, currency symbol removal, nested string parsing
- **CROSS JOIN:** Efficient application of percentile benchmarks across all rows
- **Derived Tables:** Two-stage processing (row-level calculations → aggregation)

</details>

<details>
<summary><strong>Limitations</strong></summary>
 
- **Email tracking:** No spam-folder visibility; open rates may be understated
- **Attribution modeling:** Multi-touch attribution is simplified relative to real-world production models
- **External factors:** Seasonality and macro effects are not explicitly controlled for in ROI calculations

</details>

## Example Queries

Below are two examples. Full queries are available in the `/sql` directory.

```sql
-- Deduplicate customer records using ROW_NUMBER
ROW_NUMBER() OVER (
  PARTITION BY customer_id
  ORDER BY completeness_score DESC
)
```

```sql
-- Calculates month-over-month revenue growth using LAG()
SELECT
    TO_CHAR(month, 'YYYY-MM') AS month,
    ROUND(revenue, 2) AS total_revenue,
    ROUND(
        ((revenue - LAG(revenue) OVER (ORDER BY month)) /
         NULLIF(LAG(revenue) OVER (ORDER BY month), 0)) * 100, 1
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY month;
```

## Key Insights & Business Recommendations

### Answers to Business Questions

1. **Which marketing channel has the highest ROI?**  
   Paid ads delivers the highest ROI based on campaign-level attribution. However, based on typical industry benchmarks, email tends to yield the highest ROI when analyzed at the channel-level attribution. In our analysis, email had diminishing returns past ~$1500 in ad spend per campaign.

2. **What's the typical customer journey from first touch to conversion?**  
   The typical first touchpoint was Paid Search. Most customers were single touch. The average days to first purchase was 109.5 days.

3. **Which email campaign types perform best?**  
   Seasonal Sale campaign performed best with an ROI of -73.93% and ROAS of $0.26.<br>
   Note: email campaigns were undercredited at the campaign attribution level so ROI and ROAS are lower than typical industry benchmarks.

5. **How has performance changed month-over-month?**  
   Revenue was lowest in the first 3 months with an average of $8,800 but picked up significantly by April and stabilized at around $10,500 per month for the rest of the year. August had the highest revenue of $12525.97 and highest month-over-month percentage growth of 45.8%.

6. **Which platforms performed the best?**  
   Instagram search yielded the highest ROI of 5830.83%.

7. **Which channels are best at acquisition vs. retention?**  
   Paid search had the highest number of new customers acquired and repeat customers.

### Customer Behavior & Psychology
- **Email frequency has a performance “sweet spot”**  
  Moderate frequency (4–6 emails per month) produces the best balance of engagement and retention, while high frequency (8+ emails per month) correlates with increased unsubscribes and reduced long-term LTV.

- **Multi-touch customers convert more slowly but generate higher value**  
  Customers exposed to 3+ marketing touchpoints before conversion tend to have higher average order values.

- **Discount-acquired customers have lower lifetime value (LTV)**  
  Customers whose first purchase involved a discount show higher churn rates and lower repeat purchase frequency compared to full-price customers.

### Strategic Recommendations
- **Implement email frequency capping**  
  Segment customers by engagement level and tailor send frequency accordingly.

- **Rebalance channel investment**  
  Email performance shows signs of saturation; increased budget allocation towards Paid Ads may produce more scalable returns.

- **Investigate year over year revenue trends**  
  Look into monthly data for previous years to determine if lower revenue in Q1 is typical.

- **Reduce reliance on discount-driven acquisition**  
  Shift toward value-based messaging and reserve deep discounts primarily for reactivation campaigns.

- **Optimize the signup-to-first-purchase journey**  
  Improving this conversion stage represents a large revenue opportunity.

## How to Run Locally

Follow the steps below to recreate the full data pipeline from raw datasets through final analysis outputs.

### Prerequisites
- PostgreSQL
- pgAdmin 4
<br>


<details>
<summary><strong>Step 1: Download Raw CSV Data</strong></summary><br>

Download the messy source datasets from the Google workbook (save them to your local drive):

https://docs.google.com/spreadsheets/d/1ajbfK5ynyznbRAi4GaxfOyJGiodOtpS7kwvi6iXdK-8/edit?gid=1149910240#gid=1149910240

Export each worksheet as a CSV file.

</details>

<details>
<summary><strong>Step 2: Set Up PostgreSQL Database</strong></summary><br>

Open the Query Tool (Tools -> Query Tool) and run the following script:

```sql
-- Connect to PostgreSQL and create the database
CREATE DATABASE marketing_analytics;
```

</details>

<details>
<summary><strong>Step 3: Create Staging Tables</strong></summary><br>

Run the following script:
sql/01_create_staging_tables.sql

</details>

<details>
<summary><strong>Step 4: Import CSV Data into Staging Tables</strong></summary><br>

For each staging table:

1. Expand Schemas → public → Tables
2. Right-click the staging table → Import/Export Data
3. Toggle Import ON
4. Select the corresponding CSV file
5. Use the following settings:
6. Format: CSV
7.  Header: ON
8. Delimiter: ,
9. Click OK

</details>

<details>
<summary><strong>Step 5: Run Cleaning Scripts</strong></summary><br>

Execute the cleaning scripts in the following order:

[sql/01_create_staging_tables.sql](sql/01_create_staging_tables.sql)<br>
[sql/02_clean_email_campaigns.sql](sql/02_clean_email_campaigns.sql)<br>
[sql/03_clean_paid_ads.sql](sql/03_clean_paid_ads.sql)<br>
[sql/04_clean_social_media_organic.sql](sql/04_clean_social_media_organic.sql)<br>
[sql/05_clean_customer_transactions.sql](sql/05_clean_customer_transactions.sql)<br>
[sql/06_clean_customer_master.sql](sql/06_clean_customer_master.sql)<br>

</details>

<details>
<summary><strong>Step 6: Run Analysis Scripts</strong></summary><br>

Execute the analysis scripts in the following order:

[sql/07_analysis_channel_roi.sql](sql/07_analysis_channel_roi.sql)<br>
[sql/08_analysis_customer_journey.sql](sql/08_analysis_customer_journey.sql)<br>
[sql/09_analysis_campaign_optimization.sql](sql/09_analysis_campaign_optimization.sql)<br>
[sql/10_analysis_segmentation.sql](sql/10_analysis_segmentation.sql)<br>
[sql/11_analysis_time_trends.sql](sql/11_analysis_time_trends.sql)<br>
[sql/12_strategic_discount_dependency.sql](sql/12_strategic_discount_dependency.sql)<br>
[sql/13_strategic_channel_saturation.sql](sql/13_strategic_channel_saturation.sql)<br>
[sql/14_strategic_message_fatigue.sql](sql/14_strategic_message_fatigue.sql)<br>

</details>
