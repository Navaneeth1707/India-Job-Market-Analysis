# India Job Market Analysis — Insights Write-Up

Analysis of 949 LinkedIn job postings from the Indian job market, cleaned and analyzed in MySQL.

## 1. Approach & Data Cleaning

This project analyzes 949 LinkedIn job postings from the Indian job market, imported into MySQL for cleaning and analysis. Before any analysis could begin, several data quality issues needed to be resolved:

**Import challenges**: The initial import attempt via MySQL Workbench's Table Data Import Wizard repeatedly and silently truncated at 10 rows, regardless of configuration. After ruling out data-content causes (encoding, field length, null values, and CSV structure were all verified clean), the import was completed instead using `LOAD DATA LOCAL INFILE`, which required enabling `local_infile` on both the client and server sides — a common real-world MySQL configuration step.

**Data quality issues identified and resolved**:
- Blank CSV fields had been loaded as empty strings rather than SQL NULLs — standardized across `publishedAt`, `contractType`, `workType`, `sector`, and `state` (92 / 89 / 89 / 89 / 78 affected rows respectively)
- The `experienceLevel` column was contaminated with contract-type values ("Full-time", "Part-time") in 88 rows; these were moved to the correct `contractType` column and the `experienceLevel` field set to NULL for those rows, since the true experience level was not recoverable
- `city` and `state` contained the invalid placeholder value "India" (a country, not a city/state) in 30 and 34 rows respectively; these were converted to NULL
- City names were fragmented across multiple spellings referring to the same location (e.g. "Bengaluru" / "Bangalore Urban" / "Bengaluru East"; "Gurugram" / "Gurgaon"; "Mumbai" / "Mumbai Metropolitan Region") and were consolidated into single canonical values, while genuinely distinct locations (e.g. "Navi Mumbai") were deliberately left separate
- `publishedAt` was converted from text to a proper `DATE` type to enable time-based trend analysis

## 2. Key Findings

**Top hiring cities**: Bengaluru leads by a wide margin, accounting for 251 of 919 postings with a known city (27%) — more than double the next closest city, Mumbai (132). Gurugram (92), Pune (62), and Hyderabad (54) round out the top five, reflecting India's established tech hub geography.

**In-demand skills**: Keyword analysis of job descriptions shows Communication (524 mentions) and Excel (442) as the most frequently requested skills overall, reflecting the broad, cross-functional nature of the dataset. Among technical skills, Python (144) leads, ahead of AWS (133), SQL (112), and Machine Learning (105). Explicit mentions of BI tools were comparatively rare (Tableau: 34, Power BI: 23) — likely understated, since many postings describe these tools generically (e.g. "reporting tools," "data visualization") rather than naming them directly.

**Experience level distribution**: Mid-Senior level postings dominate the market at 41.2%, followed by Entry level (24.9%) and Associate (16.3%). Combined, Mid-Senior and Associate roles make up nearly 58% of all postings with a known experience level, indicating the market skews toward more experienced hires relative to entry-level opportunities.

**Top hiring companies**: Tata Cummins (20 postings), Freshworks (17), and Google (12) lead in posting volume. One entry in the top 10 ("Dubai Jobs, Gulf Jobs...") represents a recruiting agency listing rather than a direct employer — a limitation of the source data worth noting rather than treating as a genuine top employer.

**Application trends over time**: Postings were relatively stable in single-to-low-double digits per month from March through November 2023, before spiking sharply to 585 postings in January 2024 alone (61% of the entire dataset). This spike most likely reflects data collection timing rather than an actual hiring surge — LinkedIn postings expire and are removed over time, so a dataset scraped around January 2024 would naturally show heavy concentration near the scrape date. Average applications per posting remained relatively stable (roughly 95–165) across most months, suggesting posting *volume* varied more than per-posting competitiveness.

**Most in-demand skill per major city**: Ranking each city's most-mentioned skill (restricted to cities with at least 20 postings, to avoid drawing conclusions from tiny samples) shows Communication as the top explicitly-mentioned skill in 7 of the 8 major hiring cities — Bengaluru, Mumbai, Gurugram, Pune, Hyderabad, Noida, and Delhi. Chennai is the one exception, where Excel is the top explicitly-mentioned skill instead.

## 3. Limitations & Caveats

**Data collection recency bias**: The heavy concentration of postings in January 2024 likely reflects when the dataset was scraped rather than a genuine hiring surge, since expired/older LinkedIn postings would no longer be visible at scrape time. Trend conclusions should be read with this in mind rather than as a reliable seasonal pattern.

**Skill-keyword matching is a proxy, not a precise measure**: Skills were identified via substring search (`LIKE '%keyword%'`) within free-text descriptions, since no structured skills field existed in the source data. This approach undercounts skills described generically (e.g. BI tools referred to as "reporting tools") and required a specific fix to avoid false positives — "Java" is a substring of "JavaScript," so a naive count would have inflated Java's true demand by more than double. A proper NLP/tokenization approach would be more robust at larger scale, but keyword matching was a reasonable, explainable approach for this dataset size.

**Company names aren't always the actual employer**: At least one top-10 "company" is a recruiting/staffing agency listing rather than a direct employer, a reminder that company-level aggregation on scraped job data can conflate agencies with employers.

**Import tooling reliability**: MySQL Workbench's Table Data Import Wizard repeatedly and silently truncated the import at 10 of 949 rows across multiple configurations, with no error message surfaced. After ruling out data-content causes (encoding, field length, nulls, CSV structure were all verified clean against the raw file), the import was completed reliably using `LOAD DATA LOCAL INFILE` instead — a reminder that GUI import tools can fail silently on complex text data, and that a lower-level, more transparent method is worth having as a fallback.
