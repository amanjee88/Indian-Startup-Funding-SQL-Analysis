# Indian Startup Funding Analysis using SQL (MySQL)

**Project 3 — Data Analytics Portfolio**  
**Author:** Aman Yadav  
**Tool:** MySQL / MySQL Workbench  
**Dataset:** Indian Startup Funding  
**Records analyzed:** 3,044  
**Date coverage in downloaded CSV:** 2015-01-07 to 2020-01-13

## Project Overview

This project analyzes Indian startup funding activity using MySQL. The goal was to move from raw, inconsistent CSV data to a cleaned analytical table and then answer business questions about funding trends, industries, cities, investment types, startups, and funding concentration.

The project was intentionally built as a SQL-first portfolio project, with emphasis on data cleaning, aggregation, subqueries, CTEs, window functions, and business interpretation.

## Business Questions

1. What is the overall funding volume and average reported funding amount?
2. How does funding change over time?
3. Which industries receive the most recorded funding?
4. Which cities are associated with the largest recorded funding totals?
5. Which investment types dominate funding volume and deal size?
6. Which startups have the highest recorded funding?
7. How concentrated is funding across industries and startups?
8. Which startups received substantial funding across multiple rounds?
9. Which industries had the highest funding contribution within each year?

## Dataset

The downloaded CSV contains **3,044 startup funding records** with 10 source fields:

- Sr No
- Date
- Startup Name
- Industry Vertical
- SubVertical
- City Location
- Investors Name
- Investment Type
- Amount in USD
- Remarks

The dataset contains historical startup funding records and should therefore be interpreted as a historical dataset rather than a current snapshot of India's startup ecosystem.

## Dataset Source & Attribution

This project uses the **Indian Startup Funding** dataset available on Kaggle:

**Source:** [Indian Startup Funding — Kaggle](https://www.kaggle.com/sudalairajkumar/indian-startup-funding/data)

The dataset contains historical funding records for Indian startups and includes information such as funding date, startup name, industry, city, investors, investment type, and funding amount.

**Dataset creator:** Sudalai Rajkumar  
**Original data acknowledgement:** trak.in  
**License:** CC0: Public Domain

The dataset was used for educational and portfolio analysis. All cleaning and transformations performed in this project are documented in the SQL script.

## Data Preparation

A two-layer approach was used:

```text
Raw CSV
   ↓
startup_funding_staging
   ↓
Data-quality inspection
   ↓
Cleaning / transformation
   ↓
startup_funding_clean
   ↓
SQL analysis
```

### Main data-quality issues identified

- Missing/unknown industry values
- Missing/unknown city values
- Missing investment types
- 971 unavailable funding amounts
- Indian-style comma-separated funding amounts
- Encoded text prefixes such as literal `\xc2\xa0`
- Malformed dates such as `05/072018`, `12/05.2015`, and `22/01//2015`
- Literal `\n` inside one funding-type value
- Category variants such as `Ecommerce` / `E-commerce`
- City variants such as `Bangalore` / `Bengaluru` and `Gurgaon` / `Gurugram`
- Startup-name variants such as `Flipkart.com` / `Flipkart`, `Ola Cabs` / `Olacabs` / `Ola`, and `OyoRooms` / `OYO Rooms`

### Cleaning decisions

Raw staging data was kept untouched. Cleaning was performed in the analytical table.

Examples:

```text
Ecommerce / E-commerce        → E-Commerce
Bangalore / Bengaluru         → Bengaluru
Gurgaon / Gurugram            → Gurugram
Nw Delhi                      → New Delhi
Multiple city values          → Multiple Locations
Seed\nFunding                → Seed Funding
Flipkart.com                  → Flipkart
Ola Cabs / Olacabs            → Ola
OyoRooms                      → OYO Rooms
N/A / unknown / undisclosed   → NULL
```

Funding amounts were converted from text to `DECIMAL(15,2)` after removing formatting characters. Unavailable amounts were treated as `NULL`, not zero.

## Final Data Quality

The final analytical table contains:

| QA Metric | Result |
|---|---:|
| Total rows | 3,044 |
| Unique Sr No | 3,044 |
| Missing dates | 0 |
| Missing startup names | 0 |
| Missing industry | 171 |
| Missing city | 174 |
| Missing investment type | 4 |
| Missing funding amount | 971 |

The project retained all **3,044 records** during cleaning.

## Key Business Insights

### 1. Recorded funding is concentrated among a small number of startups

The overall dataset contains approximately **$38.14 billion** in recorded funding across **2,073 records with a reported amount**. The top four startups — Flipkart, Rapido Bike Taxi, Paytm, and Ola — account for **36.34%** of total recorded funding. The top 15 startups account for **50.40%**.

### 2. E-Commerce and Consumer Internet are major funding contributors

Industry funding share shows:

| Industry | Share of total recorded funding |
|---|---:|
| E-Commerce | 21.66% |
| Consumer Internet | 16.40% |
| Transportation | 10.27% |
| Technology | 5.85% |
| Finance | 5.17% |

These are dataset observations; they do not establish causation.

### 3. Funding concentration varies substantially by year

The top three industries captured:

| Year | Top 3 share of annual recorded funding |
|---|---:|
| 2015 | 21.68% |
| 2016 | 93.42% |
| 2017 | 91.24% |
| 2018 | 65.65% |
| 2019 | 64.92% |
| 2020 | 94.39% |

The 2020 result requires extra caution because the dataset contains only **7 funding records** for that year.

### 4. Bengaluru is the largest city-level funding hub in this dataset

Bengaluru is associated with approximately **$1.85 billion** in recorded funding and **842 funding records**. Mumbai follows with about **$495 million**, while Gurugram and New Delhi are also major recorded funding locations.

Small-sample cities can show distorted averages, so city-average comparisons were also tested with a minimum of 30 reported funding amounts.

### 5. Private Equity dominates recorded funding by investment type

Private Equity has approximately **$26.71 billion** in recorded funding across 1,357 funding records. Later-stage categories show very large average deal sizes despite much smaller numbers of observations; for example, Series B has 20 reported amounts with an average of about **$239.96 million** per reported record.

This shows why deal count, total funding, and average deal size should be viewed together.

### 6. Funding averages are sensitive to large individual deals

The overall average reported funding amount is about **$18.40 million**, but some individual observations are extremely large. Rapido Bike Taxi has one reported funding record of approximately **$3.9 billion**, so its startup-level average equals that single observation.

For this reason, minimum sample-size filters were used when comparing average funding across groups.

### 7. High-value funding is also visible across repeated rounds

After standardizing startup names, OYO Rooms combines `OyoRooms` and `OYO Rooms` into **8 reported funding rounds**, totaling approximately **$897 million** in recorded funding. Similar recurring high-value activity is visible for Flipkart, Paytm, Ola, Udaan, OYO Rooms, BigBasket, and Zomato.

### Detailed Business Insights

For the complete business interpretation, see
[FINAL_BUSINESS_INSIGHTS.md](FINAL_BUSINESS_INSIGHTS.md).

## SQL Skills Demonstrated

This project demonstrates:

- `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`
- Aggregate functions: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`
- `HAVING`
- `CASE`
- String functions: `TRIM`, `LOWER`, `REPLACE`, `LOCATE`, `CONCAT`
- `STR_TO_DATE`
- `DECIMAL` conversion with `CAST`
- Regular expressions for data inspection
- Subqueries
- CTEs (`WITH`)
- Window functions
- `DENSE_RANK()`
- `ROW_NUMBER()`
- Windowed cumulative `SUM()`
- `JOIN`
- `CROSS JOIN`
- Data-quality validation and reconciliation

## Advanced SQL Example

A CTE + window-function analysis was used to identify the highest-funded industry in each year:

```sql
WITH annual_industry AS (
    SELECT
        YEAR(funding_date) AS funding_year,
        industry_vertical,
        SUM(amount_usd) AS total_funding_usd
    FROM startup_funding_clean
    WHERE amount_usd IS NOT NULL
    GROUP BY YEAR(funding_date), industry_vertical
),
ranked_industry AS (
    SELECT
        funding_year,
        industry_vertical,
        total_funding_usd,
        DENSE_RANK() OVER (
            PARTITION BY funding_year
            ORDER BY total_funding_usd DESC
        ) AS funding_rank
    FROM annual_industry
)
SELECT *
FROM ranked_industry
WHERE funding_rank = 1;
```

## Limitations

This dataset has several analytical limitations:

- Some funding amounts are unavailable.
- Some source categories remain fragmented because merging them would require additional business definitions.
- `Investors Name` can contain multiple investors in one text field, so investor-level totals are not a perfectly normalized participation analysis.
- The dataset is historical and has very uneven record counts by year.
- Large individual funding rounds can strongly affect averages and totals.

## Repository Structure

```text
Indian-Startup-Funding-SQL-Analysis/
├── data/
│   └── indian_startup_funding.csv
├── FINAL_BUSINESS_INSIGHTS.md
├── Project3_Indian_Startup_Funding_Analysis.sql
└── README.md
```

## How to Reproduce

1. Install MySQL Server and MySQL Workbench.
2. Clone or download this repository.
3. Place `indian_startup_funding.csv` from the `data/` folder into the MySQL `secure_file_priv` upload directory.
4. Update the `LOAD DATA INFILE` path in the SQL script if your upload directory is different.
5. Run the SQL script in MySQL Workbench.
6. Review the final data-quality QA results to confirm the cleaned dataset contains 3,044 records.
7. Run the analysis queries to reproduce the business findings.

