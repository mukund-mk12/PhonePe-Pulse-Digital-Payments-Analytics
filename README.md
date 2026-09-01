# PhonePe-Pulse-Digital-Payments-Analytics

SQL + Excel analytics project on PhonePe Pulse's official open-source dataset, examining how digital payments adoption varies across Indian states and whether registered users actually convert into transaction activity — or leave regions "registered but inactive."

Tools: MySQL · MS Excel (Pivot Tables, Power Query, Slicers)

Summary
Modeled PhonePe Pulse's open-source dataset (agg_trans, agg_user) across 36 Indian states and 16 quarters (2018–2021) — used SQL window functions (LAG, RANK, NTILE) and CTEs
Built an adoption-vs-engagement framework using NTILE quartile segmentation to bucket states into engagement tiers (High/Moderate/Low/Registered-but-Inactive), surfacing high-registration low-usage outliers for targeted intervention campaigns
Built an interactive Excel dashboard (pivot tables, slicers, DAX-free calculated KPIs) visualizing QoQ/YoY growth, transaction-type spend share, and top/bottom-ranked states by engagement
Problem Statement

Digital payment adoption is often measured by registered-user counts, but registration doesn't guarantee usage. This project builds an adoption-vs-engagement framework to identify states where user growth isn't translating into transaction growth — surfacing high-registration, low-usage outliers for targeted intervention.

Dataset
Source: PhonePe Pulse official open-source repository
Tables used: agg_trans (aggregated transactions) + agg_user (aggregated users), joined at state/year/quarter/transaction_type grain
Scope: 36 Indian states, 16 quarters (2018–2021)
2,874 rows after aggregation, exported to CSV and loaded into Excel

Note on scope: agg_user data in the source repo is incomplete beyond 2021 (2022 is partial, 2023–2024 missing), so 2018–2021 was locked as the analysis window — a deliberate, documented limitation rather than a gap in the pipeline.

Approach
SQL (MySQL): CTE-based queries joining and pre-aggregating agg_trans + agg_user by state/year/quarter/transaction_type. Used window functions — LAG (QoQ growth), RANK, NTILE (quartile-based engagement tiering) — before exporting to CSV.
Power Query: Cleaned the CSV on import (trimmed fields, fixed year/quarter stored as text, resolved duplicate registered-user/app-opens values per transaction-type row).
Excel Dashboard: Built entirely on formulas (not DAX) to showcase core Excel technique range — pivot tables, slicers, and calculated KPIs.
