-- ============================================================
-- INDIA JOB MARKET ANALYSIS (SQL)
-- Dataset: LinkedIn_Jobs_Data_India.csv (949 rows)
-- ============================================================


-- ============================================================
-- SECTION 1: SCHEMA CREATION & DATA IMPORT
-- ============================================================

USE india_jobs;

CREATE TABLE jobs_raw (
    row_index INT,
    id BIGINT,
    publishedAt VARCHAR(20),
    title VARCHAR(255),
    companyName VARCHAR(255),
    postedTime VARCHAR(50),
    applicationsCount DECIMAL(10,1),
    description TEXT,
    contractType VARCHAR(50),
    experienceLevel VARCHAR(50),
    workType VARCHAR(255),
    sector VARCHAR(255),
    companyId BIGINT,
    city VARCHAR(100),
    state VARCHAR(100),
    recently_posted_jobs VARCHAR(10)
);

-- Note: requires local_infile enabled on both client (Workbench connection
-- Advanced settings: OPT_LOCAL_INFILE=1) and server (SET GLOBAL local_infile = 1)
LOAD DATA LOCAL INFILE 'D:/workfiles/projects resume 1234567890/India Job Market Analysis (SQL)/raw data/LinkedIn_Jobs_Data_India.csv'
INTO TABLE jobs_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(row_index, id, publishedAt, title, companyName, postedTime,
 applicationsCount, description, contractType, experienceLevel,
 workType, sector, companyId, city, state, recently_posted_jobs);

-- Verify import
SELECT COUNT(*) FROM jobs_raw;  -- expected: 949


-- ============================================================
-- SECTION 2: DATA QUALITY AUDIT
-- (run these to confirm the issues before cleaning)
-- ============================================================

-- 2.1 Check for empty strings (LOAD DATA turns blank CSV fields into '' not NULL)
SELECT
    SUM(CASE WHEN publishedAt = '' THEN 1 ELSE 0 END) AS empty_publishedAt,
    SUM(CASE WHEN contractType = '' THEN 1 ELSE 0 END) AS empty_contractType,
    SUM(CASE WHEN workType = '' THEN 1 ELSE 0 END) AS empty_workType,
    SUM(CASE WHEN sector = '' THEN 1 ELSE 0 END) AS empty_sector,
    SUM(CASE WHEN state = '' THEN 1 ELSE 0 END) AS empty_state
FROM jobs_raw;
-- expected: 92 / 89 / 89 / 89 / 78

-- 2.2 Check experienceLevel contamination with contractType values
SELECT experienceLevel, COUNT(*) AS row_count
FROM jobs_raw
GROUP BY experienceLevel
ORDER BY row_count DESC;
-- expect to see 'Full-time' (87) and 'Part-time' (1) in this list

-- 2.3 Check invalid "India" placeholder in city/state
SELECT
    (SELECT COUNT(*) FROM jobs_raw WHERE city = 'India') AS invalid_city_count,
    (SELECT COUNT(*) FROM jobs_raw WHERE state = 'India') AS invalid_state_count;
-- expected: 30 / 34

-- 2.4 Check city naming variants (Bengaluru/Bangalore, Gurugram/Gurgaon, Mumbai)
SELECT city, COUNT(*) AS row_count
FROM jobs_raw
WHERE city LIKE '%Bengaluru%' OR city LIKE '%Bangalore%'
   OR city LIKE '%Gurugram%' OR city LIKE '%Gurgaon%'
   OR city LIKE '%Mumbai%'
GROUP BY city
ORDER BY row_count DESC;

-- 2.5 Before fixing experienceLevel/contractType overlap, confirm contractType
--     is empty for the contaminated rows (so nothing gets overwritten)
SELECT contractType, experienceLevel, COUNT(*) AS row_count
FROM jobs_raw
WHERE experienceLevel IN ('Full-time', 'Part-time')
GROUP BY contractType, experienceLevel;
-- expected: contractType is NULL for all 88 contaminated rows


-- ============================================================
-- SECTION 3: CLEANING
-- ============================================================

-- 3.1 Convert empty strings to real NULLs
SET SQL_SAFE_UPDATES = 0;

UPDATE jobs_raw
SET publishedAt = NULLIF(publishedAt, ''),
    contractType = NULLIF(contractType, ''),
    workType = NULLIF(workType, ''),
    sector = NULLIF(sector, ''),
    state = NULLIF(state, '');

SET SQL_SAFE_UPDATES = 1;

-- Verify
SELECT
    SUM(CASE WHEN publishedAt IS NULL THEN 1 ELSE 0 END) AS null_publishedAt,
    SUM(CASE WHEN contractType IS NULL THEN 1 ELSE 0 END) AS null_contractType,
    SUM(CASE WHEN workType IS NULL THEN 1 ELSE 0 END) AS null_workType,
    SUM(CASE WHEN sector IS NULL THEN 1 ELSE 0 END) AS null_sector,
    SUM(CASE WHEN state IS NULL THEN 1 ELSE 0 END) AS null_state
FROM jobs_raw;
-- expected: 92 / 89 / 89 / 89 / 78 (now real NULLs)


-- 3.2 Fix experienceLevel / contractType overlap
--     Move "Full-time"/"Part-time" values out of experienceLevel and into
--     contractType (where they belong), then null out experienceLevel for
--     those rows since the true experience level isn't recoverable.
SET SQL_SAFE_UPDATES = 0;

UPDATE jobs_raw
SET contractType = experienceLevel,
    experienceLevel = NULL
WHERE experienceLevel IN ('Full-time', 'Part-time');

SET SQL_SAFE_UPDATES = 1;

-- Verify
SELECT experienceLevel, COUNT(*) AS row_count
FROM jobs_raw
GROUP BY experienceLevel
ORDER BY row_count DESC;
-- 'Full-time'/'Part-time' should no longer appear; NULL count should be 88

SELECT contractType, COUNT(*) AS row_count
FROM jobs_raw
GROUP BY contractType
ORDER BY row_count DESC;
-- Full-time should be 918, Part-time should be 4


-- 3.3 Fix invalid "India" placeholder values in city/state -> NULL
SET SQL_SAFE_UPDATES = 0;

UPDATE jobs_raw
SET city = NULL
WHERE city = 'India';

UPDATE jobs_raw
SET state = NULL
WHERE state = 'India';

SET SQL_SAFE_UPDATES = 1;

-- Verify
SELECT
    (SELECT COUNT(*) FROM jobs_raw WHERE city = 'India') AS remaining_invalid_city,
    (SELECT COUNT(*) FROM jobs_raw WHERE state = 'India') AS remaining_invalid_state,
    (SELECT COUNT(*) FROM jobs_raw WHERE city IS NULL) AS null_city,
    (SELECT COUNT(*) FROM jobs_raw WHERE state IS NULL) AS null_state
FROM jobs_raw
LIMIT 1;
-- expected: 0 / 0 / 30 / 112


-- 3.4 Standardize city naming variants
--     Note: "Navi Mumbai" is deliberately left alone - it's a genuinely
--     distinct satellite city, not a naming variant.
SET SQL_SAFE_UPDATES = 0;

UPDATE jobs_raw
SET city = 'Bengaluru'
WHERE city IN ('Bangalore Urban', 'Bengaluru East', 'Greater Bengaluru Area', 'Bengaluru North', 'Bangalore Urban district');

UPDATE jobs_raw
SET city = 'Gurugram'
WHERE city = 'Gurgaon';

UPDATE jobs_raw
SET city = 'Mumbai'
WHERE city = 'Mumbai Metropolitan Region';

SET SQL_SAFE_UPDATES = 1;

-- Verify
SELECT city, COUNT(*) AS row_count
FROM jobs_raw
WHERE city LIKE '%Bengaluru%' OR city LIKE '%Bangalore%'
   OR city LIKE '%Gurugram%' OR city LIKE '%Gurgaon%'
   OR city LIKE '%Mumbai%'
GROUP BY city
ORDER BY row_count DESC;
-- expected: Bengaluru 251, Mumbai 132, Gurugram 92, Navi Mumbai 10 (unchanged)


-- 3.5 Convert publishedAt (text) to a real DATE column
--     Kept as a new column rather than converting in place, so the
--     original text is preserved as a safety net.
ALTER TABLE jobs_raw ADD COLUMN publishedAt_date DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE jobs_raw
SET publishedAt_date = STR_TO_DATE(publishedAt, '%Y-%m-%d')
WHERE publishedAt IS NOT NULL;

SET SQL_SAFE_UPDATES = 1;

-- Verify no failed conversions
SELECT
    COUNT(*) AS total_non_null_text,
    SUM(CASE WHEN publishedAt_date IS NULL THEN 1 ELSE 0 END) AS failed_conversions
FROM jobs_raw
WHERE publishedAt IS NOT NULL;
-- expected: failed_conversions = 0


-- 3.6 Final full-table sanity check after all cleaning steps
SELECT COUNT(*) AS total_rows,
       SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END) AS null_city,
       SUM(CASE WHEN state IS NULL THEN 1 ELSE 0 END) AS null_state,
       SUM(CASE WHEN experienceLevel IS NULL THEN 1 ELSE 0 END) AS null_experienceLevel,
       SUM(CASE WHEN contractType IS NULL THEN 1 ELSE 0 END) AS null_contractType
FROM jobs_raw;
-- expected: 949 / 30 / 112 / 88 / 1


-- ============================================================
-- SECTION 4: BUSINESS QUESTIONS
-- ============================================================

-- 4.1 Top hiring cities
SELECT city, COUNT(*) AS job_count
FROM jobs_raw
WHERE city IS NOT NULL
GROUP BY city
ORDER BY job_count DESC
LIMIT 10;


-- 4.2 Most in-demand skills (keyword search within description text)
SELECT
    SUM(CASE WHEN description LIKE '%SQL%' THEN 1 ELSE 0 END) AS sql_count,
    SUM(CASE WHEN description LIKE '%Python%' THEN 1 ELSE 0 END) AS python_count,
    SUM(CASE WHEN description LIKE '%Excel%' THEN 1 ELSE 0 END) AS excel_count,
    SUM(CASE WHEN description LIKE '%Power BI%' THEN 1 ELSE 0 END) AS powerbi_count,
    SUM(CASE WHEN description LIKE '%Tableau%' THEN 1 ELSE 0 END) AS tableau_count,
    SUM(CASE WHEN description LIKE '%JavaScript%' THEN 1 ELSE 0 END) AS javascript_count,
    SUM(CASE WHEN description LIKE '%Java%' AND description NOT LIKE '%JavaScript%' THEN 1 ELSE 0 END) AS java_only_count,
    SUM(CASE WHEN description LIKE '%AWS%' THEN 1 ELSE 0 END) AS aws_count,
    SUM(CASE WHEN description LIKE '%Machine Learning%' THEN 1 ELSE 0 END) AS ml_count,
    SUM(CASE WHEN description LIKE '%Communication%' THEN 1 ELSE 0 END) AS communication_count
FROM jobs_raw;
-- Note: Java count uses "NOT LIKE '%JavaScript%'" to avoid counting
-- descriptions that only mention JavaScript (since "Java" is a substring of it)


-- 4.3 Experience level distribution
SELECT experienceLevel, COUNT(*) AS job_count,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM jobs_raw WHERE experienceLevel IS NOT NULL), 1) AS percentage
FROM jobs_raw
WHERE experienceLevel IS NOT NULL
GROUP BY experienceLevel
ORDER BY job_count DESC;


-- 4.4 Top hiring companies
SELECT companyName, COUNT(*) AS job_count
FROM jobs_raw
GROUP BY companyName
ORDER BY job_count DESC
LIMIT 10;
-- Note: one entry ("Dubai Jobs, Gulf Jobs..." ) is a recruiting agency
-- listing, not an actual employer - a limitation of the source data


-- 4.5 Application trends over time (by month)
SELECT
    DATE_FORMAT(publishedAt_date, '%Y-%m') AS month,
    COUNT(*) AS job_postings,
    SUM(applicationsCount) AS total_applications,
    ROUND(AVG(applicationsCount), 1) AS avg_applications_per_posting
FROM jobs_raw
WHERE publishedAt_date IS NOT NULL
GROUP BY DATE_FORMAT(publishedAt_date, '%Y-%m')
ORDER BY month;
-- Note: the sharp spike in Jan 2024 postings likely reflects data
-- collection/scrape timing rather than an actual hiring surge, since
-- older LinkedIn postings expire and would already be removed by
-- the time of scraping


-- 4.6 Most in-demand skill per city (major cities only, >=20 postings)
--     Uses a window function (RANK) to find the top skill within each
--     city, rather than a single global ranking.
WITH city_skills AS (
    SELECT city, 'SQL' AS skill, COUNT(*) AS mentions
    FROM jobs_raw
    WHERE city IS NOT NULL AND description LIKE '%SQL%'
    GROUP BY city

    UNION ALL

    SELECT city, 'Python' AS skill, COUNT(*) AS mentions
    FROM jobs_raw
    WHERE city IS NOT NULL AND description LIKE '%Python%'
    GROUP BY city

    UNION ALL

    SELECT city, 'Excel' AS skill, COUNT(*) AS mentions
    FROM jobs_raw
    WHERE city IS NOT NULL AND description LIKE '%Excel%'
    GROUP BY city

    UNION ALL

    SELECT city, 'AWS' AS skill, COUNT(*) AS mentions
    FROM jobs_raw
    WHERE city IS NOT NULL AND description LIKE '%AWS%'
    GROUP BY city

    UNION ALL

    SELECT city, 'Communication' AS skill, COUNT(*) AS mentions
    FROM jobs_raw
    WHERE city IS NOT NULL AND description LIKE '%Communication%'
    GROUP BY city
),
ranked AS (
    SELECT city, skill, mentions,
           RANK() OVER (PARTITION BY city ORDER BY mentions DESC) AS skill_rank
    FROM city_skills
)
SELECT r.city, r.skill AS top_skill, r.mentions
FROM ranked r
JOIN (
    SELECT city, COUNT(*) AS total_postings
    FROM jobs_raw
    WHERE city IS NOT NULL
    GROUP BY city
) c ON r.city = c.city
WHERE r.skill_rank = 1
  AND c.total_postings >= 20
ORDER BY c.total_postings DESC;
-- finding: Communication leads in 7 of 8 major cities; Chennai is the
-- exception, where Excel is the top explicitly-mentioned skill
