WITH mrkt_costs_corrected AS (
  -- Correcting the source field by converting to lowercase to ensure consistent data format.
  -- Some sources in the marketing data table had mixed case (e.g., 'Google' and 'google'), 
  -- so we standardize to lowercase for accurate matching.
  SELECT
    LOWER(source) AS source,
    medium,
    campaign,
    date,
    costs_rub
  FROM `GD1.marketing_costs`
),

transactions_with_acq_info AS (
    -- Joining transaction data with user acquisition data to match each transaction to the user's first interaction details.
    -- The `sessions_acquisition` table contains one record per user, detailing their first session, while the `transactions_rub` table 
    -- can have multiple transaction records per user. We join on UUID to correctly associate transactions with the acquisition data.
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
  -- Aggregating data by cohort based on the first transaction date, source, medium, and campaign.
  -- Cohort represents a group of users who first interacted with the brand on a specific date.
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
  -- Calculating LTV for a 30-day cohort by combining marketing costs and transaction data.
  -- We use LEFT JOIN to retain all records from the marketing costs data (left table) even if there are no corresponding 
  -- transaction records in the cohort data (right table). This ensures we capture all marketing costs, including those without transactions.
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

-- Final SELECT to output the LTV results for 30 days.
SELECT *
FROM ltv_30_days
ORDER BY cohort_date, source, medium, campaign;
