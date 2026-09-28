-- ============================================================
-- PROJECT 3: Indian Startup Funding Analysis
-- Author: Aman Yadav
-- Tool: MySQL 8.x
-- ============================================================

-- ------------------------------------------------------------
-- 1. DATABASE SETUP
-- ------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS indian_startup_funding;
USE indian_startup_funding;

-- ------------------------------------------------------------
-- 2. RAW STAGING TABLE
-- Keep raw values as text because the source contains
-- inconsistent dates, categories, encodings, and amounts.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS startup_funding_staging;

CREATE TABLE IF NOT EXISTS startup_funding_staging (
    sr_no INT,
    funding_date VARCHAR(20),
    startup_name VARCHAR(255),
    industry_vertical VARCHAR(255),
    sub_vertical VARCHAR(255),
    city_location VARCHAR(100),
    investors_name TEXT,
    investment_type VARCHAR(100),
    amount_usd VARCHAR(100),
    remarks TEXT
);

-- ------------------------------------------------------------
-- 3. RAW DATA IMPORT
-- Place the CSV in MySQL's secure_file_priv directory first.
-- Example path used during the project:
-- D:/MySQL/Data/Uploads/indian_startup_funding.csv
-- ------------------------------------------------------------

SET @OLD_SQL_MODE = @@SESSION.SQL_MODE;
SET SESSION SQL_MODE = '';

LOAD DATA INFILE 'D:/MySQL/Data/Uploads/indian_startup_funding.csv'
INTO TABLE startup_funding_staging
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

SET SESSION SQL_MODE = @OLD_SQL_MODE;

-- Verify that the expected number of CSV rows was imported.
SELECT COUNT(*) AS imported_rows
FROM startup_funding_staging;

-- ------------------------------------------------------------
-- 4. CLEAN ANALYTICAL TABLE
-- ------------------------------------------------------------
DROP TABLE IF EXISTS startup_funding_clean;

CREATE TABLE startup_funding_clean AS
WITH prepared AS (
    SELECT
        s.*,
        TRIM(REPLACE(
            funding_date,
            CONCAT(CHAR(92), 'xc2', CHAR(92), 'xa0'),
            ''
        )) AS clean_date,
        TRIM(REPLACE(
            city_location,
            CONCAT(CHAR(92), 'xc2', CHAR(92), 'xa0'),
            ''
        )) AS clean_city,
        TRIM(REPLACE(
            investment_type,
            CONCAT(CHAR(92), 'n'),
            ' '
        )) AS clean_investment_type,
        TRIM(REPLACE(
            amount_usd,
            CONCAT(CHAR(92), 'xc2', CHAR(92), 'xa0'),
            ''
        )) AS clean_amount
    FROM startup_funding_staging AS s
),
normalized AS (
    SELECT
        *,
        CASE
            WHEN clean_date = '05/072018' THEN '05/07/2018'
            WHEN clean_date = '01/07/015' THEN '01/07/2015'
            WHEN clean_date = '10/7/2015' THEN '10/07/2015'
            WHEN clean_date = '22/01//2015' THEN '22/01/2015'
            ELSE REPLACE(clean_date, '.', '/')
        END AS normalized_date
    FROM prepared
)
SELECT
    sr_no,
    STR_TO_DATE(normalized_date, '%d/%m/%Y') AS funding_date,

    NULLIF(TRIM(startup_name), 'nan') AS startup_name,

    CASE
        WHEN LOWER(TRIM(industry_vertical)) IN ('nan', 'n/a') THEN NULL
        WHEN LOWER(TRIM(industry_vertical)) IN ('ecommerce', 'e-commerce')
            THEN 'E-Commerce'
        ELSE TRIM(industry_vertical)
    END AS industry_vertical,

    CASE
        WHEN LOWER(TRIM(sub_vertical)) IN ('nan', 'n/a') THEN NULL
        ELSE TRIM(sub_vertical)
    END AS sub_vertical,

    CASE
        WHEN LOWER(clean_city) IN ('nan', 'n/a') THEN NULL
        WHEN LOCATE('/', clean_city) > 0
          OR LOCATE('&', clean_city) > 0
          OR LOWER(clean_city) LIKE '% and %'
            THEN 'Multiple Locations'
        WHEN LOWER(clean_city) = 'bangalore' THEN 'Bengaluru'
        WHEN LOWER(clean_city) = 'gurgaon' THEN 'Gurugram'
        WHEN LOWER(clean_city) = 'nw delhi' THEN 'New Delhi'
        ELSE clean_city
    END AS city_location,

    CASE
        WHEN LOWER(TRIM(investors_name)) IN ('nan', 'n/a', 'unknown')
            THEN NULL
        ELSE TRIM(investors_name)
    END AS investors_name,

    CASE
        WHEN LOWER(clean_investment_type) IN ('nan', 'n/a', 'unknown')
            THEN NULL
        WHEN REPLACE(LOWER(clean_investment_type), ' ', '') = 'seedfunding'
            THEN 'Seed Funding'
        WHEN REPLACE(LOWER(clean_investment_type), ' ', '') IN
             ('seed/angelfunding', 'angel/seedfunding')
            THEN 'Seed/Angel Funding'
        ELSE clean_investment_type
    END AS investment_type,

    CASE
        WHEN LOWER(clean_amount) IN ('n/a', 'unknown', 'undisclosed', 'nan')
            THEN NULL
        ELSE CAST(
            REPLACE(
                REPLACE(clean_amount, ',', ''),
                '+',
                ''
            ) AS DECIMAL(15,2)
        )
    END AS amount_usd,

    CASE
        WHEN LOWER(TRIM(remarks)) = 'nan' THEN NULL
        ELSE TRIM(remarks)
    END AS remarks

FROM normalized;

ALTER TABLE startup_funding_clean
ADD PRIMARY KEY (sr_no);

-- Post-creation standardization based on verified source values.
SET @OLD_SQL_SAFE_UPDATES = @@SESSION.SQL_SAFE_UPDATES;
SET SESSION SQL_SAFE_UPDATES = 0;

-- Convert blank investment-type entries to NULL.
UPDATE startup_funding_clean
SET investment_type = NULL
WHERE TRIM(investment_type) = '';

-- Standardize verified startup-name variants.
UPDATE startup_funding_clean
SET startup_name = 'Flipkart'
WHERE startup_name = 'Flipkart.com';

UPDATE startup_funding_clean
SET startup_name = 'Ola'
WHERE startup_name IN ('Ola Cabs', 'Olacabs');

-- Standardize verified OYO Rooms name variant.
UPDATE startup_funding_clean
SET startup_name = 'OYO Rooms'
WHERE startup_name = 'OyoRooms';

SET SESSION SQL_SAFE_UPDATES = @OLD_SQL_SAFE_UPDATES;

-- ------------------------------------------------------------
-- 5. FINAL DATA QA
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT sr_no) AS unique_sr_no,
    SUM(funding_date IS NULL) AS missing_dates,
    SUM(startup_name IS NULL) AS missing_startups,
    SUM(industry_vertical IS NULL) AS missing_industries,
    SUM(city_location IS NULL) AS missing_cities,
    SUM(investment_type IS NULL) AS missing_investment_types,
    SUM(amount_usd IS NULL) AS missing_amounts
FROM startup_funding_clean;

-- ------------------------------------------------------------
-- 6. OVERALL FUNDING KPIs
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(amount_usd) AS records_with_funding_amount,
    SUM(amount_usd) AS total_funding_usd,
    AVG(amount_usd) AS average_funding_usd,
    MIN(amount_usd) AS minimum_funding_usd,
    MAX(amount_usd) AS maximum_funding_usd
FROM startup_funding_clean;

-- ------------------------------------------------------------
-- 7. YEARLY FUNDING TREND
-- ------------------------------------------------------------
SELECT
    YEAR(funding_date) AS funding_year,
    COUNT(*) AS funding_records,
    COUNT(amount_usd) AS records_with_amount,
    SUM(amount_usd) AS total_funding_usd,
    AVG(amount_usd) AS average_funding_usd
FROM startup_funding_clean
GROUP BY YEAR(funding_date)
ORDER BY funding_year;

-- ------------------------------------------------------------
-- 8. FUNDING BY INDUSTRY
-- ------------------------------------------------------------
SELECT
    industry_vertical,
    COUNT(*) AS funding_records,
    COUNT(amount_usd) AS records_with_amount,
    ROUND(SUM(amount_usd) / 1000000, 2) AS total_funding_million_usd,
    ROUND(AVG(amount_usd) / 1000000, 2) AS average_funding_million_usd
FROM startup_funding_clean
WHERE industry_vertical IS NOT NULL
GROUP BY industry_vertical
ORDER BY total_funding_million_usd DESC
LIMIT 15;

-- ------------------------------------------------------------
-- 9. CITY FUNDING ANALYSIS WITH SAMPLE-SIZE FILTER
-- ------------------------------------------------------------
SELECT
    city_location,
    COUNT(*) AS funding_records,
    COUNT(amount_usd) AS records_with_amount,
    ROUND(SUM(amount_usd) / 1000000, 2) AS total_funding_million_usd,
    ROUND(AVG(amount_usd) / 1000000, 2) AS average_funding_million_usd
FROM startup_funding_clean
WHERE city_location IS NOT NULL
  AND city_location <> 'Multiple Locations'
GROUP BY city_location
HAVING COUNT(amount_usd) >= 30
ORDER BY average_funding_million_usd DESC;

-- ------------------------------------------------------------
-- 10. INVESTMENT TYPE ANALYSIS
-- ------------------------------------------------------------
SELECT
    investment_type,
    COUNT(*) AS funding_records,
    COUNT(amount_usd) AS records_with_amount,
    ROUND(SUM(amount_usd) / 1000000, 2) AS total_funding_million_usd,
    ROUND(AVG(amount_usd) / 1000000, 2) AS average_funding_million_usd
FROM startup_funding_clean
WHERE investment_type IS NOT NULL
GROUP BY investment_type
HAVING COUNT(amount_usd) >= 5
ORDER BY total_funding_million_usd DESC;

-- ------------------------------------------------------------
-- 11. TOP FUNDED STARTUPS
-- ------------------------------------------------------------
SELECT
    startup_name,
    COUNT(*) AS funding_records,
    COUNT(amount_usd) AS records_with_amount,
    ROUND(SUM(amount_usd) / 1000000, 2) AS total_funding_million_usd,
    ROUND(AVG(amount_usd) / 1000000, 2) AS average_funding_million_usd
FROM startup_funding_clean
WHERE startup_name IS NOT NULL
GROUP BY startup_name
HAVING COUNT(amount_usd) > 0
ORDER BY total_funding_million_usd DESC
LIMIT 15;

-- ------------------------------------------------------------
-- 12. STARTUPS ABOVE OVERALL AVERAGE (SUBQUERY)
-- ------------------------------------------------------------
SELECT
    startup_name,
    COUNT(amount_usd) AS funding_records,
    ROUND(AVG(amount_usd), 2) AS average_funding_usd
FROM startup_funding_clean
WHERE startup_name IS NOT NULL
GROUP BY startup_name
HAVING COUNT(amount_usd) >= 2
   AND AVG(amount_usd) > (
       SELECT AVG(amount_usd)
       FROM startup_funding_clean
       WHERE amount_usd IS NOT NULL
   )
ORDER BY average_funding_usd DESC
LIMIT 15;

-- ------------------------------------------------------------
-- 13. MONTHLY FUNDING TREND
-- ------------------------------------------------------------
SELECT
    YEAR(funding_date) AS funding_year,
    MONTH(funding_date) AS funding_month,
    COUNT(*) AS funding_records,
    COUNT(amount_usd) AS records_with_amount,
    ROUND(SUM(amount_usd) / 1000000, 2) AS total_funding_million_usd
FROM startup_funding_clean
GROUP BY YEAR(funding_date), MONTH(funding_date)
ORDER BY total_funding_million_usd DESC
LIMIT 15;

-- ------------------------------------------------------------
-- 14. INDUSTRY FUNDING SHARE
-- ------------------------------------------------------------
SELECT
    industry_vertical,
    ROUND(SUM(amount_usd) / 1000000, 2) AS total_funding_million_usd,
    ROUND(
        SUM(amount_usd) * 100.0 /
        (
            SELECT SUM(amount_usd)
            FROM startup_funding_clean
            WHERE amount_usd IS NOT NULL
        ),
        2
    ) AS funding_share_percent
FROM startup_funding_clean
WHERE industry_vertical IS NOT NULL
GROUP BY industry_vertical
ORDER BY funding_share_percent DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 15. TOP INDUSTRY BY YEAR (CTE + WINDOW FUNCTION)
-- ------------------------------------------------------------
WITH annual_industry AS (
    SELECT
        YEAR(funding_date) AS funding_year,
        industry_vertical,
        SUM(amount_usd) AS total_funding_usd
    FROM startup_funding_clean
    WHERE funding_date IS NOT NULL
      AND industry_vertical IS NOT NULL
      AND amount_usd IS NOT NULL
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
SELECT
    funding_year,
    industry_vertical,
    ROUND(total_funding_usd / 1000000, 2) AS total_funding_million_usd
FROM ranked_industry
WHERE funding_rank = 1
ORDER BY funding_year;

-- ------------------------------------------------------------
-- BUSINESS QUESTION 1: FUNDING CONCENTRATION BY YEAR
-- Top 3 industries and their share of annual funding.
-- ------------------------------------------------------------

WITH annual_industry AS (
    SELECT
        YEAR(funding_date) AS funding_year,
        industry_vertical,
        SUM(amount_usd) AS industry_funding_usd
    FROM startup_funding_clean
    WHERE funding_date IS NOT NULL
      AND industry_vertical IS NOT NULL
      AND amount_usd IS NOT NULL
    GROUP BY
        YEAR(funding_date),
        industry_vertical
),

ranked_industry AS (
    SELECT
        funding_year,
        industry_vertical,
        industry_funding_usd,
        ROW_NUMBER() OVER (
            PARTITION BY funding_year
            ORDER BY industry_funding_usd DESC
        ) AS industry_rank
    FROM annual_industry
),

annual_totals AS (
    SELECT
        YEAR(funding_date) AS funding_year,
        SUM(amount_usd) AS annual_funding_usd
    FROM startup_funding_clean
    WHERE funding_date IS NOT NULL
      AND amount_usd IS NOT NULL
    GROUP BY YEAR(funding_date)
)

SELECT
    r.funding_year,
    r.industry_vertical,
    r.industry_rank,
    ROUND(
        r.industry_funding_usd / 1000000,
        2
    ) AS industry_funding_million_usd,
    ROUND(
        r.industry_funding_usd * 100.0 /
        a.annual_funding_usd,
        2
    ) AS share_of_annual_funding_percent
FROM ranked_industry AS r
JOIN annual_totals AS a
    ON r.funding_year = a.funding_year
WHERE r.industry_rank <= 3
ORDER BY
    r.funding_year,
    r.industry_rank;

-- ------------------------------------------------------------
-- BUSINESS QUESTION 2: STARTUP FUNDING CONCENTRATION
-- Top startups and their cumulative share of total funding.
-- ------------------------------------------------------------

WITH startup_funding AS (
    SELECT
        startup_name,
        SUM(amount_usd) AS total_funding_usd
    FROM startup_funding_clean
    WHERE startup_name IS NOT NULL
      AND amount_usd IS NOT NULL
    GROUP BY startup_name
),

ranked_startups AS (
    SELECT
        startup_name,
        total_funding_usd,

        DENSE_RANK() OVER (
            ORDER BY total_funding_usd DESC
        ) AS funding_rank,

        SUM(total_funding_usd) OVER (
            ORDER BY total_funding_usd DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS cumulative_funding_usd

    FROM startup_funding
),

overall_funding AS (
    SELECT
        SUM(amount_usd) AS total_funding_usd
    FROM startup_funding_clean
    WHERE amount_usd IS NOT NULL
)

SELECT
    r.funding_rank,
    r.startup_name,

    ROUND(
        r.total_funding_usd / 1000000,
        2
    ) AS total_funding_million_usd,

    ROUND(
        r.total_funding_usd * 100.0
        / o.total_funding_usd,
        2
    ) AS funding_share_percent,

    ROUND(
        r.cumulative_funding_usd * 100.0
        / o.total_funding_usd,
        2
    ) AS cumulative_share_percent

FROM ranked_startups AS r

CROSS JOIN overall_funding AS o

WHERE r.funding_rank <= 15

ORDER BY r.funding_rank;

-- ------------------------------------------------------------
-- BUSINESS QUESTION 3: RECURRING HIGH-VALUE STARTUPS
-- Startups with at least 3 reported funding rounds.
-- ------------------------------------------------------------

SELECT
    startup_name,
    COUNT(amount_usd) AS reported_funding_rounds,

    ROUND(
        SUM(amount_usd) / 1000000,
        2
    ) AS total_funding_million_usd,

    ROUND(
        AVG(amount_usd) / 1000000,
        2
    ) AS average_round_million_usd

FROM startup_funding_clean

WHERE startup_name IS NOT NULL
  AND amount_usd IS NOT NULL

GROUP BY startup_name

HAVING COUNT(amount_usd) >= 3

ORDER BY total_funding_million_usd DESC

LIMIT 15;

-- ------------------------------------------------------------
-- INVESTOR ANALYSIS
-- Investor values may contain multiple investors in one field.
-- Results represent stored investor entries, not normalized
-- individual investor participation.
-- ------------------------------------------------------------

SELECT
    investors_name,
    COUNT(*) AS funding_records,
    COUNT(amount_usd) AS records_with_amount,

    ROUND(
        SUM(amount_usd) / 1000000,
        2
    ) AS total_funding_million_usd,

    ROUND(
        AVG(amount_usd) / 1000000,
        2
    ) AS average_funding_million_usd

FROM startup_funding_clean

WHERE investors_name IS NOT NULL

GROUP BY investors_name

HAVING COUNT(*) >= 5

ORDER BY total_funding_million_usd DESC

LIMIT 15;
