-- DATA CLEANING SECTION: STARTS --

SELECT * FROM worldwide_layoffs;

-- CREATING A NEW TABLE FOR CLEANING

CREATE TABLE worldwide_layoffs_staging
LIKE worldwide_layoffs;

SELECT * FROM worldwide_layoffs_staging;

INSERT worldwide_layoffs_staging
SELECT * FROM worldwide_layoffs;

-- REMOVING DUPLICATES

SELECT *, ROW_NUMBER() OVER(PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, 
`date`, stage, country, fund_raised_millions) AS row_num
FROM worldwide_layoffs_staging;

WITH duplicate_cte AS
(
SELECT *, ROW_NUMBER() OVER(PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, 
`date`, stage, country, funds_raised_millions) AS row_num
FROM worldwide_layoffs_staging
)
SELECT * FROM duplicate_cte
WHERE row_num > 1;

CREATE TABLE `worldwide_layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO worldwide_layoffs_staging2
SELECT *, ROW_NUMBER() OVER(PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, 
`date`, stage, country, funds_raised_millions) AS row_num
FROM worldwide_layoffs_staging;

DELETE FROM worldwide_layoffs_staging2
WHERE row_num > 1;

SELECT * FROM worldwide_layoffs_staging2;

-- STANDARDIZING DATA
-- Selecting each individual column in order to find outliers to fix

-- First column: company
-- Use the trim command to cut off unnecessary spaces in cells
SELECT company, TRIM(company)
FROM worldwide_layoffs_staging2;

UPDATE worldwide_layoffs_staging2
SET company = TRIM(company);

-- Second column: location
SELECT location
FROM worldwide_layoffs_staging2
ORDER BY 1;

-- Third column: industry
-- Identifying unnecessary industry name and categorizing it accordingly
SELECT DISTINCT industry
FROM worldwide_layoffs_staging2
ORDER BY 1;

SELECT *
FROM worldwide_layoffs_staging2
WHERE industry LIKE 'Crypto%';

UPDATE worldwide_layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Forth column: country
-- Unnecessary dot(s) found, use TRIM TRAILING
SELECT country
FROM worldwide_layoffs_staging2
ORDER BY 1;

SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM worldwide_layoffs_staging2;

UPDATE worldwide_layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country);

-- Fifth column: date
-- Updating the date data format
SELECT `date`,
STR_TO_DATE(`date`, '%m/%d/%Y')
FROM worldwide_layoffs_staging2;

UPDATE worldwide_layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE worldwide_layoffs_staging2
MODIFY COLUMN `date` DATE;

-- POPULATING BLANK OR NULL CELLS
SELECT * FROM worldwide_layoffs_staging2
WHERE industry IS NULL
OR industry = '';

SELECT *
FROM worldwide_layoffs_staging2 t1
JOIN worldwide_layoffs_staging2 t2
	ON t1.company = t2.company
WHERE (t1.company IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;

UPDATE worldwide_layoffs_staging2
SET industry = NULL
WHERE industry = '';

UPDATE worldwide_layoffs_staging2 t1
JOIN worldwide_layoffs_staging2 t2
	ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- DELETING ROWS THAT DO NOT HAVE SUFFICIENT DATA
SELECT * FROM worldwide_layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

DELETE FROM worldwide_layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- REMOVING COLUMNS WHICH ARE NO LONGER NECESSARY
SELECT * FROM worldwide_layoffs_staging2;

ALTER TABLE worldwide_layoffs_staging2
DROP COLUMN row_num;

-- DATA CLEANING SECTION: ENDS --

-- EXPLORATORY DATA ANALYSIS: STARTS --

-- Question 1: How many total layoffs occurred from 2021 to 2022?
SELECT SUM(total_laid_off) AS Total_Layoffs
FROM worldwide_layoffs_staging2
WHERE date BETWEEN '2021-01-01' AND '2022-12-31';

-- Question 2: What is the average number of layoffs per month?
SELECT AVG(monthly_layoffs) AS Avg_Layoffs_Per_Month
FROM (
    SELECT DATE_FORMAT(date, '%Y-%m') AS Month, SUM(total_laid_off) AS monthly_layoffs
    FROM worldwide_layoffs_staging2
    WHERE date BETWEEN '2021-01-01' AND '2022-12-31'
    GROUP BY Month
) AS MonthlyLayoffs;

-- Question 3: How do the total layoffs compare between 2021 and 2022?
SELECT YEAR(date) AS Year, SUM(total_laid_off) AS Total_Layoffs
FROM worldwide_layoffs_staging2
WHERE date BETWEEN '2021-01-01' AND '2022-12-31'
GROUP BY Year;

-- Question 4: Which companies had the highest number of layoffs?
SELECT company, SUM(total_laid_off) AS Total_Layoffs
FROM worldwide_layoffs_staging2
GROUP BY company
ORDER BY Total_Layoffs DESC
LIMIT 10;

-- Question 5: What is the average percentage of layoffs per company?
SELECT AVG(percentage_laid_off) AS Avg_Percentage_Layoffs
FROM worldwide_layoffs_staging2;

-- Question 6: Which industries had the highest number of layoffs?
SELECT industry, SUM(total_laid_off) AS Total_Layoffs
FROM worldwide_layoffs_staging2
GROUP BY industry
ORDER BY Total_Layoffs DESC
LIMIT 10;

-- Question 7: What is the average percentage of layoffs in each industry?
SELECT industry, AVG(percentage_laid_off) AS Avg_Percentage_Layoffs
FROM worldwide_layoffs_staging2
GROUP BY industry
ORDER BY Avg_Percentage_Layoffs DESC;

-- Question 8: Which countries had the highest average percentage of layoffs per company?
SELECT country, AVG(percentage_laid_off) AS Avg_Percentage_Layoffs
FROM worldwide_layoffs_staging2
GROUP BY country
ORDER BY Avg_Percentage_Layoffs DESC
LIMIT 10;

-- Question 9: What is the distribution of layoffs across different industries?
SELECT industry, SUM(total_laid_off) AS Total_Layoffs
FROM worldwide_layoffs_staging2
GROUP BY industry
ORDER BY Total_Layoffs DESC;

-- Question 10: Are there companies with multiple rounds of layoffs? If so, what are the patterns?
SELECT company, COUNT(*) AS Layoff_Rounds, SUM(total_laid_off) AS Total_Layoffs
FROM worldwide_layoffs_staging2
GROUP BY company
HAVING Layoff_Rounds > 1
ORDER BY Layoff_Rounds DESC;

-- Question 11: What are the trends in layoffs over time (monthly/quarterly)?
-- Monthly Trend:
SELECT DATE_FORMAT(date, '%Y-%m') AS Month, SUM(total_laid_off) AS Total_Layoffs
FROM worldwide_layoffs_staging2
GROUP BY Month
ORDER BY Month;

-- Quarterly Trend:
SELECT CONCAT(YEAR(date), '-Q', QUARTER(date)) AS Quarter, SUM(total_laid_off) AS Total_Layoffs
FROM worldwide_layoffs_staging2
GROUP BY Quarter
ORDER BY Quarter;

-- Question 12: Are there specific months with higher layoff rates?
SELECT DATE_FORMAT(date, '%M') AS Month, SUM(total_laid_off) AS Total_Layoffs
FROM worldwide_layoffs_staging2
GROUP BY Month
ORDER BY Total_Layoffs DESC;

-- EXPLORATORY DATA ANALYSIS: ENDS --