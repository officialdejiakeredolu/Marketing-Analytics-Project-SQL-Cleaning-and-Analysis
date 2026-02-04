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
- **Which marketing channel has the highest ROI?**
- **What’s the typical customer journey from first touch to conversion?**
- **Which email campaign types perform best?**
- **How has performance changed month-over-month?**
- **Which platforms drive the highest lifetime value (LTV) customers?**
- **Which channels are best at acquisition vs. retention?**

<details>
<summary><strong>Strategic, Nuanced, and Edge-Case Questions</strong></summary>

- **Are we training customers to only buy on discount?**  
  Do discount-acquired customers have lower lifetime value?

- **Are high-ROI channels hitting saturation?**  
  Do we see diminishing returns at higher spend levels?

- **Is aggressive email marketing hurting long-term customer health?**  
  Does high frequency drive short-term revenue but long-term churn?

- **Do email campaigns convert because they persuade, or because they target already warm users?**

- **Are certain customer segments more price-sensitive vs. trust-driven?**

- **What role does each channel play in the funnel?**  
  (Upstream role vs. downstream role, intent capture, reinforcement, brand strength)

- **Where does ROI break at scale?**  
  (Ad fatigue, diminishing returns)

- **What would be recommended if the marketing budget were cut by a certain %?**

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

### Channel Performance
- **Email delivers the highest ROI among paid channels**, but shows diminishing returns above ~$1,500 per campaign spend
- **Paid Ads scale more predictably**, maintaining relatively linear returns at higher spend levels
- **Organic Social provides strong reach and engagement**, but contributes limited directly attributable revenue

### Customer Behavior & Psychology
- **Discount-acquired customers have lower lifetime value (LTV)**  
  Customers whose first purchase involved a discount show higher churn rates and lower repeat purchase frequency compared to full-price customers

- **Email frequency has a performance “sweet spot”**  
  Moderate frequency (4–6 emails per month) produces the best balance of engagement and retention, while high frequency (8+ emails per month) correlates with increased unsubscribes and reduced long-term LTV

- **Multi-touch customers convert more slowly but generate higher value**  
  Customers exposed to 3+ marketing touchpoints before conversion tend to have higher average order values

### Strategic Recommendations
- **Reduce reliance on discount-driven acquisition**  
  Shift toward value-based messaging and reserve deep discounts primarily for reactivation campaigns

- **Implement email frequency capping**  
  Segment customers by engagement level and tailor send frequency accordingly

- **Rebalance channel investment**  
  Email performance shows signs of saturation; incremental budget allocation toward Paid Ads may produce more scalable returns

- **Optimize the signup-to-first-purchase journey**  
  Improving this conversion stage represents the largest untapped revenue opportunity

## How to Run Locally
