## LTV Analysis and Data Preparation
This project demonstrates the preparation and cleaning of marketing and transaction data, as well as calculating LTV (Lifetime Value) for a cohort of users using Google BigQuery and SQL. It serves as a simple example of data preparation and transformation, aimed at showcasing the basics of working with marketing data. The goal is to identify effective and inefficient marketing campaigns and analyze their dynamics over time by simplifying the process with temporary tables, making data transformation faster and easier to understand.

### Technologies Used
- **Google BigQuery**: For SQL-based data processing and analysis.
- **SQL**: To clean, transform, and aggregate data.
- **Tableau** *(later for visualization)*: For dynamic reporting and trend analysis.

### Dataset Overview
1. **Marketing Costs Table (`marketing_costs`)**
   - Contains details about daily advertising spend per campaign.
2. **Transactions Table (`transactions_rub`)**
   - Includes transaction details like revenue and discounts.
3. **Sessions Acquisition Table (`sessions_acquisition`)**
   - Tracks user acquisition source and campaign details.

### Key Steps
1. **Data Preparation**
   - Joining transaction data with user acquisition details.
   - Calculating discounts and income for each transaction.
   - Aggregating data by cohorts (first transaction date, source, medium, campaign).

2. **LTV Calculation**
   - Combining marketing costs with income and discount data.
   - **LTV Formula**:  
     **LTV = Income - Discounts - Marketing Costs**

3. **Analysis Preparation**
   - Exporting the final table for visualization and deeper analysis.
  
### Files in this repository:
- **`SQL/queries.sql`**: SQL queries used for data preparation and LTV calculation.
- **`output/LTV_example.csv`**: Example of LTV calculation result (aggregated data for marketing channels and cohorts).

### Example Query
```sql
WITH mrkt_costs_corrected AS (
  SELECT
    LOWER(source) AS source,
    medium,
    campaign,
    date,
    costs_rub
  FROM `GD1.marketing_costs`
),
transactions_with_acq_info AS (
  SELECT
    tr.id AS transaction_id,
    DATE(tr.created_at) AS transaction_date,
    tr.subtotal_rub,
    (tr.subtotal_rub - tr.total_rub) AS discount,
    sa.start_at AS first_transaction_date,
    sa.source,
    sa.medium,
    sa.campaign,
    tr.total_rub
  FROM 
    `GD1.transactions_rub` tr
  JOIN 
    `GD1.sessions_acquisition` sa
  ON 
    tr.uuid = sa.uuid
),
data_per_cohort AS (
  SELECT 
    first_transaction_date AS cohort_date,
    source,
    medium,
    campaign,
    SUM(subtotal_rub) AS income,
    SUM(discount) AS discounts
  FROM 
    transactions_with_acq_info
  GROUP BY 
    cohort_date, 
    source, 
    medium, 
    campaign
),
ltv_30_days AS (
  SELECT 
    dpc.cohort_date,
    dpc.source,
    dpc.medium,
    dpc.campaign,
    dpc.income,
    dpc.discounts,
    mc.costs_rub,
    (dpc.income - dpc.discounts - mc.costs_rub) AS ltv
  FROM 
    mrkt_costs_corrected mc
  LEFT JOIN 
    data_per_cohort dpc
  ON 
    mc.date = dpc.cohort_date
    AND mc.source = dpc.source
    AND mc.medium = dpc.medium
    AND mc.campaign = dpc.campaign
)
SELECT *
FROM ltv_30_days
ORDER BY cohort_date, source, medium, campaign;
