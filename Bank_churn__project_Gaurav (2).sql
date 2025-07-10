-- Change the datatype 'bank_doj' to DATE 
SET SQL_SAFE_UPDATES = 0;

-- Update the 'bank_doj' column to proper DATE format
UPDATE customerinfo
SET bank_doj = STR_TO_DATE(bank_doj, '%d/%m/%Y');

-- Change the column type from VARCHAR to DATE
ALTER TABLE customerinfo
MODIFY COLUMN bank_doj DATE;

--  There are some blank rows in activecustomer table 
DELETE FROM activecustomer
WHERE ActiveID = '';

-- There is exited customer is incorrectly labelled as active, so it should modify as inactive member
UPDATE Churn
SET IsActiveMember = 0
WHERE Exited = 1 AND IsActiveMember = 1;

select * from churn where Exited=1 and IsActiveMember=1; 
-- ==========================================================================

-- Checking the null value in bank_churn table and customerinfo 

-- Bank_churn table   
SELECT 
    *
FROM
    churn
WHERE
    customerid IS NULL
        OR CreditScore IS NULL
        OR Tenure IS NULL
        OR Balance IS NULL
        OR NumOfProducts IS NULL
        OR HasCrCard IS NULL
        OR IsActiveMember IS NULL
        OR Exited IS NULL;  

-- Customerinfo table 
SELECT 
    *
FROM
    customerinfo
WHERE
    CustomerId IS NULL OR surname IS NULL
        OR age IS NULL
        OR genderid IS NULL
        OR EstimatedSalary IS NULL
        OR GeographyID IS NULL
        OR bank_doj IS NULL;
-- ================================================================================================
select * from churn;
select * from customerinfo;
-- There are some special character in surname column so it has updated as blank 
UPDATE customerinfo
SET surname = replace(surname,'?',''); 

select surname, locate('?',surname) from customerinfo
WHERE surname REGEXP '[^a-zA-Z ]' and locate('?',surname)<>0; 
-- ==================================================================================================

-- OBJECTIVE ANSWERS 

-- 1) distribution of account balances across different regions  

SELECT 
    c.GeographyID,
    g.geographylocation,
    ROUND(SUM(ch.Balance), 2) AS Total_balance,
    ROUND(AVG(ch.Balance), 2) AS Average_balance,
    ROUND(MAX(ch.Balance), 2) AS Max_balance,
    ROUND(MIN(ch.Balance), 2) AS MIN_balance
FROM
    customerinfo c
        INNER JOIN
    geography g ON c.GeographyID = g.GeographyID
        LEFT JOIN
    churn ch ON c.CustomerId = ch.CustomerId
GROUP BY c.GeographyID , g.GeographyLocation;


-- 2) top 5 customers with the highest Estimated Salary in the last quarter of the year
 
SELECT 
    CustomerId, Surname, EstimatedSalary Highest_salary
FROM
    customerinfo
WHERE
    QUARTER(bank_doj) = 4
ORDER BY highest_salary DESC
LIMIT 5;

-- 3) average number of products used by customers who have a credit card 
SELECT 
    AVG(NumOfProducts) avg_num_product_with_creditcard
FROM
    churn
WHERE
    HasCrCard = 1;

-- 4) churn rate by gender for the most recent year in the dataset.
with 
	most_recent_year AS (
    select max(year(bank_doj)) recent_year from customerinfo) 

SELECT 
    gen.GenderCategory,
    (SUM(ch.Exited) / COUNT(*)) * 100.00 AS Churn_rate
FROM
    CustomerInfo c
        INNER JOIN
    Gender gen ON c.GenderID = gen.GenderID
        INNER JOIN
    Churn ch ON c.CustomerID = ch.CustomerID
WHERE
    YEAR(bank_doj) = (SELECT 
            *
        FROM
            most_recent_year)
GROUP BY gen.GenderCategory;

-- 5) average credit score of customers who have exited and those who remain.
SELECT 
    ex.ExitCategory, AVG(ch.CreditScore) AS avg_credit_score
FROM
    churn ch
        INNER JOIN
    exitcustomer ex ON ch.Exited = ex.ExitID
GROUP BY ex.ExitCategory; 

-- 6) gender has a higher average estimated salary, and how does it relate to the number of active accounts 

with 
combine_table AS (
SELECT 
    ch.CustomerId,
    ch.IsActiveMember,
    c.GenderID,
    c.EstimatedSalary
FROM
    churn ch
        INNER JOIN
    customerinfo c ON ch.CustomerId = c.CustomerId),
gender_avg_estimated_salary as (
SELECT 
    gen.GenderID,
    gen.GenderCategory,
    ct.IsActiveMember,
    ROUND(AVG(ct.EstimatedSalary)) avg_estimated_salary
FROM
    combine_table ct
        INNER JOIN
    gender gen ON ct.GenderID = gen.GenderID
GROUP BY gen.GenderCategory , gen.GenderID , ct.IsActiveMember
ORDER BY avg_estimated_salary , ct.IsActiveMember)

SELECT 
    GenderCategory Gender,
    GROUP_CONCAT(avg_estimated_salary
        SEPARATOR ' , ') 'Avg Salary For Active , Avg Salary for Non-active'
FROM
    gender_avg_estimated_salary group by GenderCategory;
    

-- 7) customers based on their credit score and identify the segment with the highest exit rate 
WITH 
	Credit_segment AS (
SELECT 
		CASE 
			WHEN CreditScore >=800 THEN 'Excellent'
			WHEN CreditScore BETWEEN 740 AND 800 THEN 'Very good'
			WHEN CreditScore BETWEEN 670 AND 740 THEN 'Good'
			WHEN CreditScore BETWEEN 580 AND 670 THEN 'Fair'
			Else 'Poor' 
		END AS Credit_Score_segment,
		CASE 
			WHEN CreditScore >=800 THEN '>= 800 score'
			WHEN CreditScore BETWEEN 740 AND 800 THEN '740-799 score'
			WHEN CreditScore BETWEEN 670 AND 740 THEN '670-739 score'
			WHEN CreditScore BETWEEN 580 AND 670 THEN '580-669 score'
			Else '< 580 score' 
		END AS Credit_Score_range,        
		ROUND((SUM(Exited)/COUNT(*))*100.00,2) AS Exit_rate
FROM churn
GROUP BY 1,2)
SELECT * 
FROM Credit_segment
ORDER BY
    CASE Credit_Score_segment
        WHEN 'Excellent' THEN 1
        WHEN 'Very good' THEN 2
        WHEN 'Good' THEN 3
        WHEN 'Fair' THEN 4
        WHEN 'Poor' THEN 5
    END;


-- 8) geographic region has the highest number of active customers with a tenure greater than 5 years

SELECT 
    g.GeographyLocation,
    SUM(ch.IsActiveMember) Total_active_customer
FROM
    customerinfo c
        INNER JOIN
    churn ch ON c.CustomerId = ch.CustomerId
        INNER JOIN
    geography g ON g.GeographyID = c.GeographyID
WHERE
    ch.Tenure > 5
GROUP BY 1
ORDER BY Total_active_customer DESC;

-- 9) impact of having a credit card on customer churn, based on the available data

SELECT 
    cc.Category,
    COUNT(DISTINCT ch.CustomerId) Total_customer,
    SUM(ch.Exited) Churned_Customers,
    ROUND((SUM(ch.Exited) / COUNT(DISTINCT ch.CustomerId) * 100.00),
            2) churn_rate
FROM
    churn ch
        INNER JOIN
    creditcard cc ON ch.HasCrCard = cc.CreditID
GROUP BY cc.Category;

-- 10) customers who have exited, what is the most common number of products they have used 
 
SELECT 
    NumOfProducts, COUNT(DISTINCT CustomerId) AS NumCustomers
FROM
    churn
WHERE
    Exited = 1
GROUP BY NumOfProducts
ORDER BY NumCustomers DESC
LIMIT 1;

-- 11) Examine the trend of customers joining over time and identify any seasonal patterns (yearly or monthly) 
 
#Yearly
SELECT 
	YEAR(bank_doj) Year,
    COUNT(DISTINCT CustomerId) Total_customer
FROM customerinfo
GROUP BY YEAR(bank_doj)
ORDER BY Total_customer DESC;

#Monthly
SELECT 
    MONTH(bank_doj) Month,
    COUNT(DISTINCT CustomerId) Total_customer
FROM
    customerinfo
GROUP BY MONTH(bank_doj)
ORDER BY Total_customer DESC;   

#Combine Year and month
SELECT 
	DISTINCT YEAR(bank_doj) Year,
    Month(bank_doj) Month,
    COUNT(CustomerId) OVER(PARTITION BY Month(bank_doj)) Monthly_Total_customer,
    COUNT(CustomerId) OVER(PARTITION BY YEAR(bank_doj)) Yearly_Total_customer
FROM customerinfo
ORDER BY Yearly_Total_customer DESC,Monthly_Total_customer DESC; 

-- 12) the relationship between the number of products and the account balance for customers who have exited

SELECT 
    NumOfProducts,
    ROUND(AVG(Balance), 2) AS AvgBalance,
    COUNT(DISTINCT CustomerId) AS NumCustomers
FROM
    churn
WHERE
    Exited = 1
GROUP BY NumOfProducts
ORDER BY AvgBalance DESC;

-- 15) write a query to find out the gender-wise average income of males and females in each geography id. 
-- Also, rank the gender according to the average value 

    SELECT
        g.GeographyLocation,
        gen.GenderCategory Gender,
        ROUND(AVG(c.EstimatedSalary),2) AS AvgIncome,
        DENSE_RANK() OVER (PARTITION BY g.GeographyLocation ORDER BY AVG(c.EstimatedSalary) DESC) AS GenderRank
    FROM
        customerinfo c
	INNER JOIN gender gen
    ON c.GenderID=gen.GenderID
    INNER JOIN geography g
    ON c.GeographyID=g.GeographyID
    GROUP BY
        g.GeographyLocation, gen.GenderCategory;
        
-- 16) write a query to find out the average tenure of the people who have exited in each age bracket (18-30, 30-50, 50+).
SELECT
    CASE
        WHEN c.Age BETWEEN 18 AND 30 THEN '18-30'
        WHEN c.Age BETWEEN 30 AND 50 THEN '30-50'
        WHEN c.Age >= 50 THEN '50+'
        ELSE 'Unknown'  
    END AS AgeBracket,
    COUNT(DISTINCT c.CustomerId) Total_churn_customer,
    AVG(ch.Tenure) AS AvgTenure
FROM customerinfo c
JOIN churn ch  on ch.CustomerId=c.CustomerId
WHERE Exited = 1
GROUP BY 1
ORDER BY AgeBracket;

-- 17) Is there any direct correlation between salary and the balance of the customers? 
-- And is it different for people who have exited or not 

# Correlation Coefficient for All Customers
SELECT 
    ROUND((COUNT(*) * SUM(EstimatedSalary * Balance) - SUM(EstimatedSalary) * SUM(Balance)) / 
    SQRT((COUNT(*) * SUM(EstimatedSalary * EstimatedSalary) - POW(SUM(EstimatedSalary), 2)) * 
    (COUNT(*) * SUM(Balance * Balance) - POW(SUM(Balance), 2))),4) AS Correlation_AllCustomers
FROM 
    churn ch
    join customerinfo c on c.CustomerId=ch.CustomerId;
 
# Correlation Coefficient for Churned customer 
SELECT 
    ROUND((COUNT(*) * SUM(EstimatedSalary * Balance) - SUM(EstimatedSalary) * SUM(Balance)) / 
    SQRT((COUNT(*) * SUM(EstimatedSalary * EstimatedSalary) - POW(SUM(EstimatedSalary), 2)) * 
    (COUNT(*) * SUM(Balance * Balance) - POW(SUM(Balance), 2))),4) AS Correlation_churned_Customers
FROM 
    churn ch
    join customerinfo c on c.CustomerId=ch.CustomerId
WHERE Exited = 1;

# Correlation Coefficient for not Churned customer 
SELECT 
    ROUND((COUNT(*) * SUM(EstimatedSalary * Balance) - SUM(EstimatedSalary) * SUM(Balance)) / 
    SQRT((COUNT(*) * SUM(EstimatedSalary * EstimatedSalary) - POW(SUM(EstimatedSalary), 2)) * 
    (COUNT(*) * SUM(Balance * Balance) - POW(SUM(Balance), 2))),4) AS Correlation_not_churned_Customers
FROM 
    churn ch
    join customerinfo c on c.CustomerId=ch.CustomerId
WHERE Exited = 0;
 
 
-- 18) Is there any correlation between the salary and the Credit score of customers 
SELECT 
    ROUND((COUNT(*) * SUM(EstimatedSalary * CreditScore) - SUM(EstimatedSalary) * SUM(CreditScore)) / 
    SQRT((COUNT(*) * SUM(EstimatedSalary * EstimatedSalary) - POW(SUM(EstimatedSalary), 2)) * 
    (COUNT(*) * SUM(CreditScore * CreditScore) - POW(SUM(CreditScore), 2))),4) AS Correlation_Salary_CreditScore
FROM 
    customerinfo c
    join churn ch on c.customerid=ch.CustomerId;
    
-- 19) Rank each bucket of credit score as per the number of customers who have churned the bank.
SELECT 
		CASE 
			WHEN CreditScore >=800 THEN 'Excellent'
			WHEN CreditScore BETWEEN 740 AND 800 THEN 'Very good'
			WHEN CreditScore BETWEEN 670 AND 740 THEN 'Good'
			WHEN CreditScore BETWEEN 580 AND 670 THEN 'Fair'
			Else 'Poor' 
		END AS Credit_Score_segment,
		CASE 
			WHEN CreditScore >=800 THEN '>= 800 score'
			WHEN CreditScore BETWEEN 740 AND 800 THEN '740-799 score'
			WHEN CreditScore BETWEEN 670 AND 740 THEN '670-739 score'
			WHEN CreditScore BETWEEN 580 AND 670 THEN '580-669 score'
			Else '< 580 score' 
		END AS Credit_Score_range,        
      COUNT(DISTINCT CustomerId) AS ChurnedCustomers,
      DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT CustomerId) DESC) AS CreditRank
FROM churn
WHERE Exited =1
GROUP BY 1,2
ORDER BY
    CreditRank;
    
    
-- 20) According to the age buckets find the number of customers who have a credit card. 
-- Also retrieve those buckets that have lesser than average number of credit cards per bucket 
WITH 
	credit_card_count AS (
SELECT 
    CASE
        WHEN Age BETWEEN 18 AND 30 THEN '18-30'
        WHEN Age BETWEEN 30 AND 50 THEN '30-50'
        WHEN Age >= 50 THEN '50+'
        ELSE 'Unknown'
    END AS AgeBucket,
    SUM(HasCrCard) AS CreditCardCount,
    COUNT(DISTINCT c.CustomerId) AS Total_Customers
FROM
    customerinfo c
        JOIN
    churn ch ON c.CustomerId = ch.CustomerId
WHERE
    HasCrCard = 1
GROUP BY 1),
Average_credit_card AS (
SELECT 
	AVG(CreditCardCount) Avg_credit_card
FROM credit_card_count)
SELECT
	*,
    (SELECT * FROM Average_credit_card) Avg_credit_card
FROM credit_card_count
WHERE CreditCardCount < (SELECT * FROM Average_credit_card);


-- 21) Rank the Locations as per the number of people who have churned the bank and average balance of the customers.

    SELECT
        g.GeographyLocation,
        COUNT(DISTINCT c.CustomerId) AS Churned_Customers,
        ROUND(AVG(ch.Balance),2) AS AvgBalance,
        DENSE_RANK() OVER(ORDER BY COUNT(DISTINCT c.CustomerId) DESC, ROUND(AVG(ch.Balance),2) DESC) Location_rank
    FROM
        customerinfo c
    JOIN
        churn ch ON c.CustomerId = ch.CustomerId
	JOIN geography g ON c.GeographyID = g.GeographyID
    WHERE
        ch.Exited = 1
    GROUP BY
        g.GeographyLocation;

-- 23) Without using “Join”, can we get the “ExitCategory” from ExitCustomers table to Bank_Churn table 
SELECT 
	Exited,
    (SELECT ExitCategory FROM exitcustomer WHERE exitcustomer.ExitID = churn.Exited) ExitCategory,
    COUNT(DISTINCT CustomerId) Total_customer
FROM churn
GROUP BY 1,2;

-- 25) Write the query to get the customer IDs, their last name, 
-- and whether they are active or not for the customers whose surname ends with “on”
 
SELECT 
	c.CustomerId,
    c.Surname 'Last Name',
    ac.ActiveCategory
FROM customerinfo c
INNER JOIN churn ch ON c.CustomerId = ch.CustomerId
INNER JOIN activecustomer ac ON ch.IsActiveMember=ac.ActiveID
WHERE LOWER(c.Surname) LIKE '%on';

-- ===================================================================================

##                        SUBJECTIVE ANSWER 

-- 9) Utilize SQL queries to segment customers based on demographics and account details 
    
 -- Segment based on acount details and demographics 
 
SELECT 
    CASE
        WHEN Balance BETWEEN 0 AND 50000 THEN 'Very Low'
        WHEN Balance BETWEEN 50001 AND 100000 THEN 'Low'
        WHEN Balance BETWEEN 100001 AND 150000 THEN 'Medium'
        WHEN Balance BETWEEN 150001 AND 200000 THEN 'High'
        ELSE 'Very High'
    END AS BalanceRange,
    CASE
        WHEN age BETWEEN 18 AND 40 THEN 'Adult'
        WHEN Balance BETWEEN 41 AND 60 THEN 'Middle aged'
        ELSE 'Old'
    END AS age_bucket,
    COUNT(DISTINCT churn.CustomerId) AS NumberOfCustomers
FROM churn
JOIN customerinfo ON churn.CustomerId=customerinfo.CustomerId
GROUP BY BalanceRange,age_bucket
ORDER BY 
	CASE BalanceRange
    WHEN '0-50,000' THEN 1
    WHEN '50,001-100,000' THEN 2
    WHEN '100,001-150,000' THEN 3
    WHEN '150,001-200,000' THEN 4
    ELSE 5 END ;


-- 14) In the “Bank_Churn” table how can you modify the name of the “HasCrCard” column to “Has_creditcard”? 

ALTER TABLE Churn
RENAME COLUMN HasCrCard TO Has_creditcard;

desc churn;

-- ALTER TABLE Churn
-- RENAME COLUMN Has_creditcard TO HasCrCard;





