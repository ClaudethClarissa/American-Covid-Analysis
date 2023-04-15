-------------Looking the full Covid deaths dataset for America-----------------

--We bring the Covid deaths table
SELECT * FROM PortfolioProject1..CovidDeaths
WHERE continent LIKE '%America%'  --Some data in location has the continent name but in the continent column is shown as null
ORDER BY 3,4; --ordering by location and date


--We bring the Covid vaccination table
SELECT * FROM PortfolioProject1..CovidVaccinations
WHERE continent LIKE '%America%' --Some data in location has the continent name but in the continent column is shown as null
ORDER BY 3,4; --ordering by location and date

------------------------------------------------------------------------------

------------------------------------------------------------------------------

-------- WE CREATE A TABLE WITH THE RELEVANT VALUES OF THE ORIGINAL ----------

------------------------------------------------------------------------------

------------------------------------------------------------------------------


-- Delete the table if it already exists
DROP TABLE IF EXISTS Covid_Infection;
-- Create a new table
CREATE TABLE Covid_Infection (
  continent NVARCHAR(255),
  country NVARCHAR(255),
  date_only DATE,
  country_population FLOAT,
  total_cases FLOAT,
  total_deaths FLOAT,
  total_vaccinations FLOAT,
  new_vaccinations FLOAT,
  new_deaths FLOAT,
  people_fully_vaccinated_per_hundred FLOAT
);

--Inserting the data of oure previous datasets into our new table
INSERT INTO Covid_Infection (continent, country, date_only, country_population, total_cases, total_deaths, total_vaccinations, new_vaccinations,new_deaths,
people_fully_vaccinated_per_hundred)
--Telling which data in specific we want to insert
SELECT deaths.continent, deaths.location, CAST(deaths.date as date), 
 deaths.population, CONVERT(float, deaths.total_cases), CONVERT(float, deaths.total_deaths),
 CONVERT(float, vac.total_vaccinations), CONVERT(FLOAT, vac.new_vaccinations), CONVERT(FLOAT, deaths.new_deaths), CONVERT(FLOAT, vac.people_fully_vaccinated_per_hundred)
--Bringing these data from covid deaths and covid vaccination datasets
FROM PortfolioProject1..CovidDeaths deaths JOIN PortfolioProject1..CovidVaccinations vac
ON (deaths.continent = vac.continent AND deaths.location = vac.location AND deaths.date = vac.date) 
WHERE deaths.continent LIKE '%America%'

------------Looking our new table--------------
SELECT * FROM Covid_Infection
ORDER BY 2,3;


-------------Loking at Total Deaths vs Total Cases---------------
--Adding a new column to Covid_Infection table----------------------
--The column 'death_percentage' shows what percentage of Covid infected people died 
ALTER TABLE Covid_Infection
ADD death_percentage float

UPDATE Covid_Infection
SET death_percentage = (

SELECT (CAST(total_deaths AS FLOAT)/CAST(total_cases AS FLOAT))*100
FROM Covid_Infection AS ci
WHERE ci.country = Covid_Infection.country AND ci.date_only = Covid_Infection.date_only --AND cd.continent LIKE '%America%'
);


-------------Loking at Total Cases vs Population--------------------
--Adding a new column to Covid_Infection table----------------------
--The column 'cases_per_population' shows what percentage of the population was infected
ALTER TABLE Covid_Infection
ADD cases_per_population float

UPDATE Covid_Infection
SET cases_per_population = (

SELECT (CAST(total_cases AS FLOAT)/CAST(country_population AS FLOAT))*100
FROM Covid_Infection as ci
WHERE ci.country = Covid_Infection.country AND ci.date_only = Covid_Infection.date_only --AND cd.continent LIKE '%America%'
);


------------------------------------------------------------------------------
-----------------  CLEANING THE DATA -----------------------------------------
------------------------------------------------------------------------------

--Changing all the NULL values for float 0.0 values. 
UPDATE Covid_Infection
SET country_population = COALESCE(country_population, 0.0),
	total_cases = COALESCE(total_cases, 0.0),	
	total_deaths = COALESCE(total_deaths, 0.0),
	total_vaccinations = COALESCE(total_vaccinations, 0.0),
	new_vaccinations = COALESCE(new_vaccinations, 0.0),
	new_deaths = COALESCE(new_deaths, 0.0),
	people_fully_vaccinated_per_hundred = COALESCE(people_fully_vaccinated_per_hundred, 0.0);

----- Looking for wrong death values---------
	
	SELECT country , date_only, death_percentage, cases_per_population 
	FROM Covid_Infection
	--As death_percentage and cases_per_populations are percentages, is not possible to have 
	--values greater than 100, so we look for this kind of values in this query
	WHERE (death_percentage > 100) OR (cases_per_population > 100);


---------------------------------------------------
----Counting how many rows we have
SELECT COUNT(*) as total_rows
FROM Covid_Infection;

---------------------------------------------------
----Counting how many unique rows we have (we do this to verify that we do not have repeted rows)
SELECT DISTINCT COUNT(*) as total_uniques_rows
FROM Covid_Infection;

----------------------------------------------------
------------Looking our final table
SELECT * FROM Covid_Infection
ORDER BY 2,3;


-----------------------------------------------------------------------------
----------------------  AMERICA GENERAL VALUES  -----------------------------
-----------------------------------------------------------------------------


--Looking which countries have the highest infectation rates compared to population
SELECT country, country_population, MAX(cases_per_population) AS Max_covid_percentage 
FROM Covid_Infection
GROUP BY country, country_population
ORDER BY Max_covid_percentage DESC; 

--Looking which country has the highest infectation rate compared to population
SELECT country,total_cases, MAX(total_deaths) AS Max_deaths
FROM Covid_Infection
WHERE total_deaths = (SELECT MAX(total_deaths) FROM Covid_Infection)
GROUP BY country, total_cases, total_deaths
ORDER BY Max_deaths DESC, total_cases DESC;

--Counting the number of deaths in each country
SELECT country, SUM(new_deaths) as Total_Death_Count
FROM Covid_Infection
GROUP BY country
ORDER BY Total_Death_Count

--Countries with their total number of new vaccinations performed, ordered from highest to lowest,
--showing only the data for the last recorded day for each country.
SELECT continent, country, date_only, country_population, total_new_vaccinations
FROM (
  SELECT continent, country, date_only, country_population, new_vaccinations,
  SUM(new_vaccinations) OVER (PARTITION BY country ORDER BY country, date_only) AS total_new_vaccinations,
  ROW_NUMBER() OVER (PARTITION BY country ORDER BY date_only DESC) AS row_num
  FROM Covid_Infection
) t
WHERE row_num = 1
ORDER BY total_new_vaccinations DESC




