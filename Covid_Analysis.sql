-- American COVID-19 Analysis
-- Microsoft SQL Server (T-SQL)
-- Source tables: PortfolioProject1.dbo.CovidDeaths and PortfolioProject1.dbo.CovidVaccinations
-- Focus: countries in North America and South America.
-- Read-only analysis: source tables are never modified.
-- Note: NULL means unavailable; it must not be replaced with zero.

-- 1. Explore source coverage and missingness.
SELECT continent, COUNT(*) AS death_records,
       COUNT(DISTINCT location) AS locations
FROM PortfolioProject1.dbo.CovidDeaths
WHERE continent IN ('North America', 'South America')
GROUP BY continent
ORDER BY continent;

SELECT d.location, COUNT(*) AS rows_in_deaths,
       COUNT(DISTINCT CAST(d.[date] AS date)) AS distinct_dates,
       SUM(CASE WHEN d.total_cases IS NULL THEN 1 ELSE 0 END) AS missing_total_cases,
       SUM(CASE WHEN d.population IS NULL THEN 1 ELSE 0 END) AS missing_population
FROM PortfolioProject1.dbo.CovidDeaths AS d
WHERE d.continent IN ('North America', 'South America')
GROUP BY d.location
ORDER BY d.location;

-- 2. Build a reusable analysis view from the two source datasets.
-- The join uses location and date, which are the geographic/time record keys.
-- Joining on continent is unnecessary and may discard otherwise valid records.
-- Only locations identified as North/South American countries in CovidDeaths
-- are included; aggregate rows with NULL continent are excluded.
GO
CREATE OR ALTER VIEW dbo.Covid_Infection AS
SELECT
    d.continent,
    d.location AS country,
    CAST(d.[date] AS date) AS date_only,
    TRY_CONVERT(float, d.population) AS country_population,
    TRY_CONVERT(float, d.total_cases) AS total_cases,
    TRY_CONVERT(float, d.total_deaths) AS total_deaths,
    TRY_CONVERT(float, d.new_deaths) AS new_deaths,
    TRY_CONVERT(float, v.total_vaccinations) AS total_vaccinations,
    TRY_CONVERT(float, v.new_vaccinations) AS new_vaccinations,
    TRY_CONVERT(float, v.people_fully_vaccinated_per_hundred) AS people_fully_vaccinated_per_hundred,
    100.0 * TRY_CONVERT(float, d.total_deaths)
        / NULLIF(TRY_CONVERT(float, d.total_cases), 0) AS recorded_deaths_to_cases_pct,
    100.0 * TRY_CONVERT(float, d.total_cases)
        / NULLIF(TRY_CONVERT(float, d.population), 0) AS cumulative_cases_to_population_pct
FROM PortfolioProject1.dbo.CovidDeaths AS d
LEFT JOIN PortfolioProject1.dbo.CovidVaccinations AS v
    ON d.location = v.location
   AND CAST(d.[date] AS date) = CAST(v.[date] AS date)
WHERE d.continent IN ('North America', 'South America');
GO

-- 3. Check source key uniqueness before interpreting joins.
SELECT location, CAST([date] AS date) AS date_only, COUNT(*) AS row_count
FROM PortfolioProject1.dbo.CovidDeaths
WHERE continent IN ('North America', 'South America')
GROUP BY location, CAST([date] AS date)
HAVING COUNT(*) > 1
ORDER BY row_count DESC, location, date_only;

SELECT location, CAST([date] AS date) AS date_only, COUNT(*) AS row_count
FROM PortfolioProject1.dbo.CovidVaccinations
WHERE continent IN ('North America', 'South America')
GROUP BY location, CAST([date] AS date)
HAVING COUNT(*) > 1
ORDER BY row_count DESC, location, date_only;

-- 4. Inspect the final analytical view.
SELECT COUNT(*) AS record_count,
       COUNT(DISTINCT country) AS country_count,
       MIN(date_only) AS first_date,
       MAX(date_only) AS last_date
FROM dbo.Covid_Infection;

SELECT country, date_only, total_cases, total_deaths,
       recorded_deaths_to_cases_pct, cumulative_cases_to_population_pct
FROM dbo.Covid_Infection
WHERE recorded_deaths_to_cases_pct > 100
   OR cumulative_cases_to_population_pct > 100
ORDER BY country, date_only;
-- A cumulative cases/population ratio over 100% can arise from repeated infections
-- and reporting conventions; it does not necessarily mean invalid data.
-- The deaths/cases ratio is NOT a clinical infection-fatality rate.

-- 5. Highest observed cumulative cases relative to population.
SELECT country,
       MAX(cumulative_cases_to_population_pct) AS max_reported_cases_to_population_pct
FROM dbo.Covid_Infection
GROUP BY country
ORDER BY max_reported_cases_to_population_pct DESC;

-- 6. Largest observed cumulative death totals.
SELECT country, MAX(total_deaths) AS max_reported_total_deaths
FROM dbo.Covid_Infection
GROUP BY country
ORDER BY max_reported_total_deaths DESC;

-- 7. Reported new deaths by country (separate from cumulative totals).
-- Negative reporting corrections, where present, remain in this sum.
SELECT country, SUM(new_deaths) AS sum_reported_new_deaths
FROM dbo.Covid_Infection
GROUP BY country
ORDER BY sum_reported_new_deaths DESC;

-- 8. Latest available reported vaccination totals for each country.
-- Do not add cumulative total_vaccinations across dates.
WITH ranked AS (
    SELECT country, continent, date_only, country_population,
           total_vaccinations, people_fully_vaccinated_per_hundred,
           ROW_NUMBER() OVER (
               PARTITION BY country ORDER BY date_only DESC
           ) AS row_num
    FROM dbo.Covid_Infection
    WHERE total_vaccinations IS NOT NULL
)
SELECT continent, country, date_only, country_population,
       total_vaccinations, people_fully_vaccinated_per_hundred
FROM ranked
WHERE row_num = 1
ORDER BY total_vaccinations DESC;

-- 9. Cumulative sum of reported new vaccinations as a separate measure.
-- This may differ from the source's total_vaccinations because of missing daily values
-- and retrospective reporting corrections.
WITH daily AS (
    SELECT country, continent, date_only, new_vaccinations,
           SUM(new_vaccinations) OVER (
               PARTITION BY country ORDER BY date_only
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS cumulative_reported_new_vaccinations
    FROM dbo.Covid_Infection
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY country ORDER BY date_only DESC
    ) AS row_num
    FROM daily
)
SELECT continent, country, date_only, cumulative_reported_new_vaccinations
FROM ranked
WHERE row_num = 1
ORDER BY cumulative_reported_new_vaccinations DESC;
