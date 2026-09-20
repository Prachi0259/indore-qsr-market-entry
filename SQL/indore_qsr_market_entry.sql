/* ============================================================
   PROJECT 2: INDORE QSR MARKET ENTRY
   SQL ANALYSIS
   ============================================================ */

CREATE DATABASE IF NOT EXISTS indore_qsr_market;
USE indore_qsr_market;

-- 1. RAW DATA
DROP TABLE IF EXISTS zomato_indore_raw;

CREATE TABLE zomato_indore_raw (
    sr_no VARCHAR(50),
    name VARCHAR(255),
    locality VARCHAR(255),
    latitude VARCHAR(50),
    longitude VARCHAR(50),
    cuisines TEXT,
    average_cost_for_two VARCHAR(50),
    aggregate_rating VARCHAR(50),
    votes VARCHAR(50),
    rating_text VARCHAR(100),
    online_order VARCHAR(50),
    book_table VARCHAR(50),
    rest_type VARCHAR(150),
    dish_liked TEXT,
    reviews_list LONGTEXT,
    listed_in_type VARCHAR(100)
);

LOAD DATA LOCAL INFILE
'C:/Users/prachi/Downloads/zomato_indore_utf8_clean_staging.csv'
INTO TABLE zomato_indore_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    sr_no, name, locality, latitude, longitude, cuisines,
    average_cost_for_two, aggregate_rating, votes, rating_text,
    online_order, book_table, rest_type, dish_liked,
    reviews_list, listed_in_type
);

-- 2. CLEAN DATA
DROP TABLE IF EXISTS zomato_indore_clean;

CREATE TABLE zomato_indore_clean AS
SELECT
    CAST(NULLIF(TRIM(sr_no), '') AS UNSIGNED) AS sr_no,
    TRIM(name) AS restaurant_name,
    TRIM(locality) AS locality,
    CAST(NULLIF(TRIM(latitude), '') AS DECIMAL(12,8)) AS latitude,
    CAST(NULLIF(TRIM(longitude), '') AS DECIMAL(12,8)) AS longitude,
    TRIM(cuisines) AS cuisines,
    CAST(NULLIF(TRIM(average_cost_for_two), '') AS DECIMAL(10,2)) AS average_cost_for_two,
    CAST(NULLIF(TRIM(aggregate_rating), '') AS DECIMAL(3,1)) AS aggregate_rating,
    CAST(NULLIF(TRIM(votes), '') AS UNSIGNED) AS votes,
    NULLIF(TRIM(rating_text), '') AS rating_text,
    NULLIF(TRIM(online_order), '') AS online_order,
    NULLIF(TRIM(book_table), '') AS book_table,
    NULLIF(TRIM(rest_type), '') AS rest_type,
    NULLIF(TRIM(dish_liked), '') AS dish_liked,
    NULLIF(TRIM(listed_in_type), '') AS listed_in_type
FROM zomato_indore_raw
WHERE TRIM(name) <> '';

-- 3. BRANCH-LEVEL DATA
DROP TABLE IF EXISTS zomato_indore_branches;

CREATE TABLE zomato_indore_branches AS
SELECT
    restaurant_name,
    locality,
    latitude,
    longitude,
    MAX(cuisines) AS cuisines,
    MAX(average_cost_for_two) AS average_cost_for_two,
    MAX(aggregate_rating) AS aggregate_rating,
    MAX(votes) AS votes,
    MAX(rating_text) AS rating_text,
    MAX(online_order) AS online_order,
    MAX(book_table) AS book_table,
    MAX(rest_type) AS rest_type,
    MAX(dish_liked) AS dish_liked,
    MAX(listed_in_type) AS listed_in_type,
    CASE
        WHEN longitude BETWEEN 75.5 AND 76.1
         AND latitude BETWEEN 22.4 AND 23.0
        THEN 1 ELSE 0
    END AS geo_valid
FROM zomato_indore_clean
GROUP BY restaurant_name, locality, latitude, longitude;

-- 4. MARKET OVERVIEW
DROP VIEW IF EXISTS vw_qsr_market;

CREATE VIEW vw_qsr_market AS
SELECT
    COUNT(*) AS total_branches,
    SUM(rest_type LIKE '%Quick Bites%') AS qsr_branches,
    SUM(
        rest_type LIKE '%Quick Bites%'
        OR rest_type IN ('Takeaway','Takeaway, Delivery','Delivery',
                         'Cafe','Food Truck','Kiosk')
    ) AS broader_qsr_relevant,
    ROUND(AVG(aggregate_rating),2) AS avg_market_rating,
    ROUND(AVG(votes),0) AS avg_market_votes,
    SUM(votes) AS total_market_votes
FROM zomato_indore_branches
WHERE geo_valid = 1;

-- 5. PRICE STRUCTURE
DROP VIEW IF EXISTS vw_qsr_price;

CREATE VIEW vw_qsr_price AS
SELECT
    CASE
        WHEN average_cost_for_two < 250 THEN 'Below 250'
        WHEN average_cost_for_two BETWEEN 250 AND 450 THEN '250-450'
        WHEN average_cost_for_two BETWEEN 451 AND 600 THEN '451-600'
        WHEN average_cost_for_two BETWEEN 601 AND 900 THEN '601-900'
        WHEN average_cost_for_two > 900 THEN 'Above 900'
        ELSE 'Unknown'
    END AS price_band,
    COUNT(*) AS branch_count,
    ROUND(
        COUNT(*) * 100.0 /
        NULLIF((
            SELECT COUNT(*)
            FROM zomato_indore_branches
            WHERE rest_type LIKE '%Quick Bites%' AND geo_valid = 1
        ),0),2
    ) AS market_share_pct
FROM zomato_indore_branches
WHERE rest_type LIKE '%Quick Bites%'
  AND geo_valid = 1
GROUP BY
    CASE
        WHEN average_cost_for_two < 250 THEN 'Below 250'
        WHEN average_cost_for_two BETWEEN 250 AND 450 THEN '250-450'
        WHEN average_cost_for_two BETWEEN 451 AND 600 THEN '451-600'
        WHEN average_cost_for_two BETWEEN 601 AND 900 THEN '601-900'
        WHEN average_cost_for_two > 900 THEN 'Above 900'
        ELSE 'Unknown'
    END;

-- 6. LOCALITY ANALYSIS
DROP VIEW IF EXISTS vw_qsr_locality;

CREATE VIEW vw_qsr_locality AS
SELECT
    locality,
    COUNT(*) AS qsr_branches,
    SUM(average_cost_for_two BETWEEN 250 AND 450) AS direct_price_band_competitors,
    SUM(average_cost_for_two BETWEEN 500 AND 900) AS target_spend_proxy_competitors,
    ROUND(AVG(aggregate_rating),2) AS avg_rating,
    ROUND(AVG(votes),0) AS avg_votes,
    SUM(votes) AS total_votes,
    SUM(online_order = 'Yes') AS online_order_branches,
    ROUND(
        SUM(online_order = 'Yes') * 100.0 /
        NULLIF(SUM(online_order IN ('Yes','No')),0),1
    ) AS online_order_pct
FROM zomato_indore_branches
WHERE rest_type LIKE '%Quick Bites%'
  AND geo_valid = 1
GROUP BY locality
HAVING COUNT(*) >= 2;

-- 7. PROPOSITION CLASSIFICATION
DROP TABLE IF EXISTS zomato_proposition;

CREATE TABLE zomato_proposition AS
SELECT
    restaurant_name,
    locality,
    cuisines,
    average_cost_for_two,
    aggregate_rating,
    votes,
    online_order,
    rest_type,
    CASE
        WHEN LOWER(cuisines) REGEXP 'burger|fast food|omelette'
             AND LOWER(cuisines) NOT REGEXP 'momos|chinese'
            THEN 'Burgers / Fast Food'
        WHEN LOWER(cuisines) REGEXP 'pizza'
            THEN 'Pizza'
        WHEN LOWER(cuisines) REGEXP 'chinese|momos|tibetan'
            THEN 'Chinese / Momos'
        WHEN LOWER(cuisines) REGEXP 'sandwich|roll|wrap'
            THEN 'Sandwich / Rolls / Wraps'
        WHEN LOWER(cuisines) REGEXP 'biryani|mughlai|kebab'
            THEN 'Biryani / Mughlai'
        WHEN LOWER(cuisines) REGEXP 'south indian'
            THEN 'South Indian'
        WHEN LOWER(cuisines) REGEXP
             'north indian|gujarati|rajasthani|malwa|indian|dhaba'
            THEN 'Indian / Regional'
        WHEN LOWER(cuisines) REGEXP
             'dessert|ice cream|bakery|waffle|cake'
            THEN 'Desserts / Bakery'
        WHEN LOWER(cuisines) REGEXP
             'cafe|beverage|tea|coffee|juice|lassi'
            THEN 'Cafe / Beverages'
        WHEN LOWER(cuisines) REGEXP
             'street food|chaat|mithai|snack|paan'
            THEN 'Street Food / Snacks'
        ELSE 'Other'
    END AS proposition_category
FROM zomato_indore_branches
WHERE rest_type LIKE '%Quick Bites%'
  AND geo_valid = 1;

-- 8. PROPOSITION MARKET
DROP VIEW IF EXISTS vw_qsr_proposition;

CREATE VIEW vw_qsr_proposition AS
SELECT
    proposition_category,
    COUNT(*) AS restaurant_records,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),2) AS market_share_pct,
    ROUND(AVG(average_cost_for_two),0) AS avg_cost_for_two,
    ROUND(AVG(aggregate_rating),2) AS avg_rating,
    SUM(votes) AS total_votes,
    ROUND(AVG(votes),0) AS avg_votes,
    SUM(average_cost_for_two BETWEEN 250 AND 450) AS direct_price_band_competitors,
    SUM(average_cost_for_two BETWEEN 500 AND 900) AS target_price_proxy_competitors
FROM zomato_proposition
GROUP BY proposition_category;

-- 9. LOCALITY × PROPOSITION
DROP TABLE IF EXISTS proposition_locality_analysis;

CREATE TABLE proposition_locality_analysis AS
SELECT
    locality,
    proposition_category,
    COUNT(*) AS competitor_count,
    SUM(votes) AS total_votes,
    ROUND(AVG(votes),0) AS avg_votes,
    ROUND(AVG(aggregate_rating),2) AS avg_rating,
    ROUND(AVG(average_cost_for_two),0) AS avg_cost_for_two,
    SUM(average_cost_for_two BETWEEN 250 AND 450) AS direct_price_band_competitors,
    SUM(average_cost_for_two BETWEEN 500 AND 900) AS target_spend_competitors,
    SUM(online_order = 'Yes') AS online_order_competitors
FROM zomato_proposition
GROUP BY locality, proposition_category
HAVING COUNT(*) >= 2;

-- 10. OPPORTUNITY SCORE
DROP TABLE IF EXISTS opportunity_index;

CREATE TABLE opportunity_index AS
WITH scores AS (
    SELECT
        locality,
        proposition_category,
        competitor_count,
        total_votes,
        avg_votes,
        avg_rating,
        avg_cost_for_two,
        direct_price_band_competitors,
        target_spend_competitors,
        online_order_competitors,
        100 * total_votes /
        NULLIF(MAX(total_votes) OVER (
            PARTITION BY proposition_category
        ),0) AS engagement_score,
        100 * (
            1 - competitor_count /
            NULLIF(MAX(competitor_count) OVER (
                PARTITION BY proposition_category
            ),0)
        ) AS supply_whitespace_score,
        100 * (
            1 - target_spend_competitors /
            NULLIF(MAX(target_spend_competitors) OVER (
                PARTITION BY proposition_category
            ),0)
        ) AS price_whitespace_score
    FROM proposition_locality_analysis
)
SELECT
    locality,
    proposition_category,
    competitor_count,
    total_votes,
    avg_votes,
    avg_rating,
    avg_cost_for_two,
    direct_price_band_competitors,
    target_spend_competitors,
    online_order_competitors,
    ROUND(engagement_score,2) AS engagement_score,
    ROUND(supply_whitespace_score,2) AS supply_whitespace_score,
    ROUND(price_whitespace_score,2) AS price_whitespace_score,
    ROUND(
        0.50 * engagement_score
        + 0.30 * supply_whitespace_score
        + 0.20 * COALESCE(price_whitespace_score,0),
        2
    ) AS opportunity_score
FROM scores;

-- 11. QUALIFIED OPPORTUNITIES
DROP TABLE IF EXISTS qualified_opportunities;

CREATE TABLE qualified_opportunities AS
WITH ranked_votes AS (
    SELECT
        total_votes,
        ROW_NUMBER() OVER (ORDER BY total_votes) AS rn,
        COUNT(*) OVER () AS total_rows
    FROM opportunity_index
)
SELECT
    o.*,
    CASE
        WHEN o.opportunity_score >= 70 THEN 'High'
        WHEN o.opportunity_score >= 50 THEN 'Medium'
        ELSE 'Lower'
    END AS opportunity_band
FROM opportunity_index o
WHERE o.total_votes >= (
    SELECT total_votes
    FROM ranked_votes
    WHERE rn = CEIL(total_rows * 0.25)
);

-- 12. MAIN POWER BI OPPORTUNITY VIEW
DROP VIEW IF EXISTS vw_qsr_opportunity;

CREATE VIEW vw_qsr_opportunity AS
SELECT
    ROW_NUMBER() OVER (ORDER BY opportunity_score DESC) AS opportunity_rank,
    locality,
    proposition_category,
    competitor_count,
    total_votes,
    avg_votes,
    avg_rating,
    avg_cost_for_two,
    direct_price_band_competitors,
    target_spend_competitors,
    online_order_competitors,
    engagement_score,
    supply_whitespace_score,
    price_whitespace_score,
    opportunity_score,
    opportunity_band,
    CASE
        WHEN target_spend_competitors >= competitor_count * 0.40
            THEN 'Strong target-price presence'
        WHEN target_spend_competitors >= competitor_count * 0.20
            THEN 'Moderate target-price presence'
        ELSE 'Limited target-price presence'
    END AS price_market_fit
FROM qualified_opportunities;

-- 13. PROPOSITION OPPORTUNITY SUMMARY
DROP VIEW IF EXISTS vw_qsr_proposition_opportunity;

CREATE VIEW vw_qsr_proposition_opportunity AS
SELECT
    proposition_category,
    COUNT(*) AS qualified_locality_combinations,
    ROUND(AVG(opportunity_score),2) AS avg_opportunity_score,
    ROUND(MAX(opportunity_score),2) AS max_opportunity_score,
    SUM(competitor_count) AS total_competitors,
    SUM(total_votes) AS total_votes,
    ROUND(AVG(avg_rating),2) AS avg_rating,
    ROUND(AVG(avg_cost_for_two),0) AS avg_cost_for_two
FROM qualified_opportunities
GROUP BY proposition_category;

-- 14. LOCALITY OPPORTUNITY SUMMARY
DROP VIEW IF EXISTS vw_qsr_locality_opportunity;

CREATE VIEW vw_qsr_locality_opportunity AS
SELECT
    locality,
    COUNT(DISTINCT proposition_category) AS propositions_present,
    SUM(competitor_count) AS total_competitors,
    SUM(total_votes) AS total_votes,
    ROUND(AVG(avg_rating),2) AS avg_rating,
    ROUND(AVG(opportunity_score),2) AS avg_opportunity_score,
    ROUND(MAX(opportunity_score),2) AS max_opportunity_score
FROM qualified_opportunities
GROUP BY locality;

-- 15. BRAND X PRICE ANALYSIS
DROP VIEW IF EXISTS vw_brandx_price;

CREATE VIEW vw_brandx_price AS
SELECT
    proposition_category,
    COUNT(*) AS total_competitors,
    SUM(average_cost_for_two BETWEEN 250 AND 450)
        AS direct_dataset_250_450,
    SUM(average_cost_for_two BETWEEN 500 AND 900)
        AS brandx_target_proxy_500_900,
    ROUND(
        SUM(average_cost_for_two BETWEEN 500 AND 900)
        * 100.0 / COUNT(*),2
    ) AS target_price_proxy_pct,
    ROUND(AVG(average_cost_for_two),0) AS avg_cost_for_two,
    ROUND(AVG(aggregate_rating),2) AS avg_rating,
    SUM(votes) AS total_votes
FROM zomato_proposition
GROUP BY proposition_category;

-- 16. FINAL EXECUTIVE OUTPUT
SELECT
    opportunity_rank,
    locality,
    proposition_category,
    competitor_count,
    total_votes,
    avg_votes,
    avg_rating,
    avg_cost_for_two,
    target_spend_competitors,
    opportunity_score,
    opportunity_band,
    price_market_fit
FROM vw_qsr_opportunity
ORDER BY opportunity_rank
LIMIT 10;

-- 17. EXECUTIVE SNAPSHOT
SELECT
    COUNT(*) AS qualified_opportunities,
    COUNT(DISTINCT locality) AS localities_analyzed,
    COUNT(DISTINCT proposition_category) AS propositions_analyzed,
    ROUND(AVG(opportunity_score),2) AS average_opportunity_score,
    ROUND(MAX(opportunity_score),2) AS maximum_opportunity_score,
    SUM(total_votes) AS qualified_market_votes,
    SUM(competitor_count) AS qualified_competitors
FROM qualified_opportunities;
