WITH state_quarter AS (
    SELECT 
        state,
        year,
        quarter,
        SUM(amount) AS total_amount
    FROM at
    GROUP BY state, year, quarter
),
qoq AS (
    SELECT 
        state,
        year,
        quarter,
        total_amount AS current_quarter_amount,
        LAG(total_amount) OVER (PARTITION BY state ORDER BY year, quarter) AS previous_quarter_amount
    FROM state_quarter
)
SELECT 
    state,
    year,
    quarter,
    previous_quarter_amount,
    current_quarter_amount,
    CASE 
        WHEN previous_quarter_amount IS NULL OR previous_quarter_amount = 0 THEN NULL
        ELSE (current_quarter_amount - previous_quarter_amount) * 100.0 / previous_quarter_amount
    END AS "QoQ %"
FROM qoq
ORDER BY state, year, quarter;
                            
-- 2. Write a query to calculate the QoQ growth % in registered_users for each state.
WITH quarter_registered_users AS(
									SELECT 
										state, 
										year,
                                        quarter,
                                        SUM(registered_users) AS current_quarter_user
									FROM au
                                    GROUP BY state, year, quarter 
                                        ),
QoQ AS (
		SELECT state, 
				year,
				quarter,
                current_quarter_user,
                LAG(current_quarter_user) OVER (PARTITION BY staTe ORDER BY year , quarter) AS previous_quarter_user 
                
		FROM quarter_registered_users)
SELECT
	state,
    year,
    quarter,
    previous_quarter_user,
    current_quarter_user,
    CASE 	
		WHEN previous_quarter_user IS NULL OR previous_quarter_user = 0 
		THEN NULL 
		ELSE (current_quarter_user - previous_quarter_user )*100/previous_quarter_user 
	END AS "QoQ"
    FROM QoQ
ORDER BY state, year, quarter;
				
    
    -- 3. Write a query to flag states where transaction growth % diverges from user growth % in the same quarter.
 WITH state_qtr AS (
    SELECT 
        a.state, a.year, a.quarter,
        SUM(a.amount) AS total_amount,
        u.registered_users
    FROM at a
    JOIN au u 
        ON a.state = u.state AND a.year = u.year AND a.quarter = u.quarter
    GROUP BY a.state, a.year, a.quarter, u.registered_users
),
growth AS (
    SELECT 
        state, year, quarter, total_amount, registered_users,
        LAG(total_amount) OVER (PARTITION BY state ORDER BY year, quarter) AS prev_amount,
        LAG(registered_users) OVER (PARTITION BY state ORDER BY year, quarter) AS prev_users
    FROM state_qtr
)
SELECT 
    state, year, quarter,
    ROUND((total_amount - prev_amount) * 100.0 / NULLIF(prev_amount,0), 2) AS txn_growth_pct,
    ROUND((registered_users - prev_users) * 100.0 / NULLIF(prev_users,0), 2) AS user_growth_pct,
    ROUND(
        (total_amount - prev_amount) * 100.0 / NULLIF(prev_amount,0)
        - (registered_users - prev_users) * 100.0 / NULLIF(prev_users,0), 
        2
    ) AS growth_divergence_pct
FROM growth
WHERE prev_amount IS NOT NULL AND prev_users IS NOT NULL
ORDER BY ABS(growth_divergence_pct) DESC;


-- 4. Write a query to calculate transactions-per-registered-user for each state per quarter, and rank states from highest to lowest.
WITH txn_per_user AS (
    SELECT 
        a.state, a.year, a.quarter,
        SUM(a.count) AS total_txn,
        u.registered_users,
        ROUND(SUM(a.count) * 1.0 / NULLIF(u.registered_users,0), 2) AS txn_per_user
    FROM at a
    JOIN au u 
        ON a.state = u.state AND a.year = u.year AND a.quarter = u.quarter
    GROUP BY a.state, a.year, a.quarter, u.registered_users
)
SELECT 
    state, year, quarter, txn_per_user,
    RANK() OVER (PARTITION BY year, quarter ORDER BY txn_per_user DESC) AS engagement_rank
FROM txn_per_user
ORDER BY year, quarter, engagement_rank;

-- 5. Write a query to bucket states into quartiles based on transactions-per-user, and label each tier as "High Engagement" / "Moderate" / "Low" / "Registered but Inactive".
WITH txn_per_user AS (
    SELECT 
        a.state, a.year, a.quarter,
        ROUND(SUM(a.count) * 1.0 / NULLIF(u.registered_users,0), 2) AS txn_per_user
    FROM at a
    JOIN au u 
        ON a.state = u.state AND a.year = u.year AND a.quarter = u.quarter
    GROUP BY a.state, a.year, a.quarter, u.registered_users
),
quartiles AS (
    SELECT 
        state, year, quarter, txn_per_user,
        NTILE(4) OVER (PARTITION BY year, quarter ORDER BY txn_per_user) AS quartile
    FROM txn_per_user
)
SELECT 
    state, year, quarter, txn_per_user,
    CASE quartile
        WHEN 4 THEN 'High Engagement'
        WHEN 3 THEN 'Moderate'
        WHEN 2 THEN 'Low'
        WHEN 1 THEN 'Registered but Inactive'
    END AS engagement_tier
FROM quartiles
ORDER BY year, quarter, quartile DESC;	 

-- 6. Write a query to calculate each district's % share of its state's total transaction amount.
SELECT 
    state, district, year, quarter,
    SUM(amount) AS district_amount,
    ROUND(
        SUM(amount) * 100.0 / SUM(SUM(amount)) OVER (PARTITION BY state, year, quarter),
        2
    ) AS pct_share_of_state
FROM mt
GROUP BY state, district, year, quarter
ORDER BY state, year, quarter, pct_share_of_state DESC;

-- 7. Write a query to find the top 5 districts by YoY transaction amount growth within each state, per year.
WITH district_year AS (
    SELECT 
        state, district, year,
        SUM(amount) AS total_amount
    FROM mt
    GROUP BY state, district, year
),
yoy AS (
    SELECT 
        state, district, year, total_amount,
        LAG(total_amount) OVER (PARTITION BY state, district ORDER BY year) AS prev_year_amount
    FROM district_year
),
yoy_growth AS (
    SELECT 
        state, district, year, total_amount, prev_year_amount,
        ROUND((total_amount - prev_year_amount) * 100.0 / NULLIF(prev_year_amount,0), 2) AS yoy_growth_pct
    FROM yoy
    WHERE prev_year_amount IS NOT NULL
),
ranked AS (
    SELECT 
        *,
        RANK() OVER (PARTITION BY state, year ORDER BY yoy_growth_pct DESC) AS growth_rank
    FROM yoy_growth
)
SELECT * FROM ranked
WHERE growth_rank <= 5
ORDER BY state, year, growth_rank;


-- 8. Write a query to identify districts with high registered_users but bottom-quartile txn_count.
WITH type_share AS (
    SELECT 
        state, year, quarter, transaction_type,
        SUM(amount) AS type_amount,
        ROUND(
            SUM(amount) * 100.0 / SUM(SUM(amount)) OVER (PARTITION BY state, year, quarter),
            2
        ) AS pct_share
    FROM at
    GROUP BY state, year, quarter, transaction_type
),
bounds AS (
    SELECT 
        state, transaction_type,
        MIN(year*10 + quarter) AS earliest_period,
        MAX(year*10 + quarter) AS latest_period
    FROM type_share
    GROUP BY state, transaction_type
)
SELECT 
    ts_early.state, ts_early.transaction_type,
    ts_early.pct_share AS earliest_share,
    ts_late.pct_share AS latest_share,
    ROUND(ts_late.pct_share - ts_early.pct_share, 2) AS share_shift
FROM bounds b
JOIN type_share ts_early 
    ON b.state = ts_early.state AND b.transaction_type = ts_early.transaction_type 
    AND (ts_early.year*10 + ts_early.quarter) = b.earliest_period
JOIN type_share ts_late 
    ON b.state = ts_late.state AND b.transaction_type = ts_late.transaction_type 
    AND (ts_late.year*10 + ts_late.quarter) = b.latest_period
ORDER BY ABS(share_shift) DESC;


-- 9. Write a query to calculate each transaction_type's % share of a state's total transactions per quarter, and compare how that share shifts from the earliest to the latest quarter.
WITH type_share AS (
    SELECT 
        state, year, quarter, transaction_type,
        SUM(amount) AS type_amount,
        ROUND(
            SUM(amount) * 100.0 / SUM(SUM(amount)) OVER (PARTITION BY state, year, quarter),
            2
        ) AS pct_share
    FROM at
    GROUP BY state, year, quarter, transaction_type
),
bounds AS (
    SELECT 
        state, transaction_type,
        MIN(year*10 + quarter) AS earliest_period,
        MAX(year*10 + quarter) AS latest_period
    FROM type_share
    GROUP BY state, transaction_type
)
SELECT 
    ts_early.state, ts_early.transaction_type,
    ts_early.pct_share AS earliest_share,
    ts_late.pct_share AS latest_share,
    ROUND(ts_late.pct_share - ts_early.pct_share, 2) AS share_shift
FROM bounds b
JOIN type_share ts_early 
    ON b.state = ts_early.state AND b.transaction_type = ts_early.transaction_type 
    AND (ts_early.year*10 + ts_early.quarter) = b.earliest_period
JOIN type_share ts_late 
    ON b.state = ts_late.state AND b.transaction_type = ts_late.transaction_type 
    AND (ts_late.year*10 + ts_late.quarter) = b.latest_period
ORDER BY ABS(share_shift) DESC;


-- 10. Write a query to confirm that district-level user/transaction sums reconcile with the corresponding state-level agg table totals.
WITH district_rollup AS (
    SELECT 
        state, year, quarter,
        SUM(count) AS district_txn_sum,
        SUM(amount) AS district_amount_sum
    FROM mt
    GROUP BY state, year, quarter
),
state_level AS (
    SELECT 
        state, year, quarter,
        SUM(count) AS state_txn_sum,
        SUM(amount) AS state_amount_sum
    FROM at
    GROUP BY state, year, quarter
)
SELECT 
    d.state, d.year, d.quarter,
    d.district_txn_sum, s.state_txn_sum,
    d.district_amount_sum, s.state_amount_sum,
    (d.district_txn_sum - s.state_txn_sum) AS txn_diff,
    (d.district_amount_sum - s.state_amount_sum) AS amount_diff
FROM district_rollup d
JOIN state_level s 
    ON d.state = s.state AND d.year = s.year AND d.quarter = s.quarter
WHERE d.district_txn_sum <> s.state_txn_sum 
   OR d.district_amount_sum <> s.state_amount_sum
ORDER BY ABS(amount_diff) DESC;