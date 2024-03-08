-- All the data are loaded into PostgreSQL using Python code

SELECT * FROM ARTIST;
SELECT * FROM CANVAS_SIZE;
SELECT * FROM IMAGE_LINK;
SELECT * FROM MUSEUM;
SELECT * FROM MUSEUM_HOURS;
SELECT * FROM PRODUCT_SIZE;
SELECT * FROM SUBJECT;
SELECT * FROM WORK;

-- 1. Retrieve all the paintings that are not currently on display in any museums.
SELECT *
FROM WORK
WHERE MUSEUM_ID IS NULL;

-- 2. Fetch the museums without any paintings.
SELECT M.*
FROM MUSEUM M
LEFT JOIN WORK W ON M.MUSEUM_ID = W.MUSEUM_ID
WHERE W.MUSEUM_ID IS NULL;

-- 3. Retrieve the paintings with an asking price higher than their regular price.
SELECT *
FROM PRODUCT_SIZE
WHERE SALE_PRICE > REGULAR_PRICE;

-- 4. Identify the paintings whose asking price is less than 50% of their regular price.
SELECT *
FROM PRODUCT_SIZE
WHERE SALE_PRICE < (0.5*REGULAR_PRICE);

-- 5. Determine the paintings with the highest cost and specify the canvas on which they were created.
SELECT WORK_ID,SALE_PRICE,LABEL
FROM (
	SELECT *,DENSE_RANK() OVER (ORDER BY SALE_PRICE DESC)
	FROM CANVAS_SIZE C
	JOIN PRODUCT_SIZE P ON C.SIZE_ID::TEXT = P.SIZE_ID
	)
WHERE DENSE_RANK = 1;

-- 6. Remove duplicate records from the work, product_size, subject, and image_link tables.
DELETE
FROM WORK
WHERE CTID NOT IN (
		SELECT MIN(CTID)
		FROM WORK
		GROUP BY WORK_ID
		);

DELETE
FROM PRODUCT_SIZE
WHERE CTID NOT IN (
		SELECT MIN(CTID)
		FROM PRODUCT_SIZE
		GROUP BY WORK_ID,SIZE_ID 
		);

DELETE
FROM SUBJECT
WHERE CTID NOT IN (
		SELECT MIN(CTID)
		FROM SUBJECT
		GROUP BY WORK_ID, SUBJECT 
		);
		
DELETE
FROM IMAGE_LINK
WHERE CTID NOT IN (
		SELECT MIN(CTID)
		FROM IMAGE_LINK
		GROUP BY WORK_ID
		);
		
-- 7. Identify the museums in the provided dataset that have incorrect city information.
SELECT *
FROM MUSEUM
WHERE CITY ~ '^[0-9]';

-- 8. The Museum_Hours table contains one duplicate entry. Please identify and eliminate it.
DELETE
FROM MUSEUM_HOURS
WHERE CTID NOT IN (
		SELECT MIN(CTID)
		FROM MUSEUM_HOURS
		GROUP BY MUSEUM_ID,DAY
		);

-- 9. Retrieve the top 10 most renowned subjects of paintings.
SELECT SUBJECT,NO_OF_PAINTINGS
FROM (
	SELECT SUBJECT,COUNT(NAME) AS NO_OF_PAINTINGS
		,ROW_NUMBER() OVER (ORDER BY COUNT(NAME) DESC)
	FROM WORK W
	JOIN SUBJECT S ON W.WORK_ID = S.WORK_ID
	GROUP BY SUBJECT
	)
WHERE ROW_NUMBER <= 10;

-- 10. Identify museums open on both Sunday and Monday, and display their names along with their respective cities.
-- Solution 1
SELECT NAME,CITY
FROM MUSEUM
WHERE MUSEUM_ID IN (
		SELECT H1.MUSEUM_ID
		FROM MUSEUM_HOURS H1
		JOIN MUSEUM_HOURS H2 ON H1.MUSEUM_ID = H2.MUSEUM_ID
		WHERE H1.DAY = 'Sunday' AND H2.DAY = 'Monday'
		);
		
-- Solution 2
SELECT NAME,CITY
FROM MUSEUM M
JOIN MUSEUM_HOURS MH1 ON M.MUSEUM_ID = MH1.MUSEUM_ID
WHERE DAY = 'Sunday' 
	AND EXISTS (
		SELECT 1
		FROM MUSEUM_HOURS MH2
		WHERE MH1.MUSEUM_ID = MH2.MUSEUM_ID AND DAY = 'Monday'
		);
		
-- 11. Retrieve the museums that are open daily.
SELECT COUNT(1) AS NO_OF_MUSEUMS
FROM (
	SELECT MUSEUM_ID,COUNT(DISTINCT DAY)
	FROM MUSEUM_HOURS
	GROUP BY 1
	HAVING COUNT(DISTINCT DAY) = 7
	);

-- 12. Retrieve the top 5 museums ranked by the number of paintings they house, indicating their popularity.
SELECT M.MUSEUM_ID,NAME,CITY,STATE,COUNTRY,NO_OF_PAINTINGS
FROM MUSEUM M
JOIN (
	SELECT MUSEUM_ID,COUNT(WORK_ID) AS NO_OF_PAINTINGS
		,DENSE_RANK() OVER (ORDER BY COUNT(WORK_ID) DESC)
	FROM WORK W
	WHERE MUSEUM_ID IS NOT NULL
	GROUP BY MUSEUM_ID
	) AS M1 ON M.MUSEUM_ID = M1.MUSEUM_ID
	AND DENSE_RANK <= 5;
	
-- 13. Retrieve the top 5 most popular artists based on the highest number of paintings created by each artist.
SELECT FULL_NAME,NATIONALITY,NO_OF_PAINTINGS
FROM ARTIST A
JOIN (
	SELECT ARTIST_ID,COUNT(WORK_ID) AS NO_OF_PAINTINGS
		,DENSE_RANK() OVER (ORDER BY COUNT(WORK_ID) DESC)
	FROM WORK W
	GROUP BY ARTIST_ID
	) AS A1 ON A.ARTIST_ID = A1.ARTIST_ID
	AND DENSE_RANK <= 5;

-- 14. Show the three least popular Canvas sizes.
SELECT LABEL,NO_OF_PAINTINGS
FROM (
	SELECT C.SIZE_ID,LABEL,COUNT(WORK_ID) AS NO_OF_PAINTINGS
		,DENSE_RANK() OVER (ORDER BY COUNT(C.SIZE_ID))
	FROM PRODUCT_SIZE P
	JOIN CANVAS_SIZE C ON C.SIZE_ID::TEXT = P.SIZE_ID
	GROUP BY 1,2
	)
WHERE DENSE_RANK <= 3;

-- 15. Retrieve information about the museum that has the longest opening hours. 
-- Display the museum name, state, hours of operation, and the corresponding day.
SELECT NAME,STATE,DAY,HOURS_OF_OPERATION
FROM MUSEUM M
JOIN (
	SELECT MUSEUM_ID,DAY
		,(TO_TIMESTAMP(CLOSE, 'HH:MI:PM') - TO_TIMESTAMP(OPEN, 'HH:MI:AM')) AS HOURS_OF_OPERATION
	FROM MUSEUM_HOURS
	ORDER BY 3 DESC LIMIT 1
	) AS MH ON M.MUSEUM_ID = MH.MUSEUM_ID;

-- 16. Retrieve the museum that houses the largest collection of the most popular painting style.
WITH MOST_POPULAR_STYLE
AS (
	SELECT STYLE,COUNT(WORK_ID)
	FROM WORK
	GROUP BY 1
	ORDER BY 2 DESC LIMIT 1
	),MUSEUM_PAINTING_COUNT
AS (
	SELECT MUSEUM_ID,W.STYLE,COUNT(WORK_ID) AS NO_OF_PAINTINGS
	FROM WORK W
	JOIN MOST_POPULAR_STYLE S ON W.STYLE = S.STYLE
	WHERE MUSEUM_ID IS NOT NULL
	GROUP BY 1,2
	ORDER BY 3 DESC LIMIT 1
	)
SELECT NAME,STYLE,NO_OF_PAINTINGS
FROM MUSEUM M
JOIN MUSEUM_PAINTING_COUNT C ON M.MUSEUM_ID = C.MUSEUM_ID;

-- 17. Identify the artists whose paintings are exhibited across several countries.
SELECT FULL_NAME AS ARTIST,COUNT(DISTINCT COUNTRY) AS NO_OF_COUNTRIES
FROM ARTIST A
JOIN WORK W ON A.ARTIST_ID = W.ARTIST_ID
JOIN MUSEUM M ON W.MUSEUM_ID = M.MUSEUM_ID
GROUP BY 1
HAVING COUNT(DISTINCT COUNTRY) > 1
ORDER BY 2 DESC;

-- 18. Display the country and the city with the highest number of museums. 
-- Output two separate columns to indicate the city and country. If there are multiple values, separate them with commas.
WITH COUNTRY_CTE
AS (
	SELECT COUNTRY
		,RANK() OVER (ORDER BY COUNT(MUSEUM_ID) DESC)
	FROM MUSEUM
	GROUP BY 1
	)
	,CITY_CTE
AS (
	SELECT CITY
		,RANK() OVER (ORDER BY COUNT(MUSEUM_ID) DESC)
	FROM MUSEUM
	GROUP BY 1
	)
SELECT STRING_AGG(DISTINCT COUNTRY, ' , ') AS COUNTRY
	,STRING_AGG(CITY, ' , ' ORDER BY CITY) AS CITY
FROM COUNTRY_CTE AS CO
CROSS JOIN CITY_CTE AS CI
WHERE CO.RANK = 1 AND CI.RANK = 1;

-- 19. Identify the artist and the museum where the most and least expensive paintings are located. 
-- Display the artist's name, sale price, painting name, museum name, city, and canvas label.
WITH CTE
AS (
	SELECT *
		,RANK() OVER (ORDER BY SALE_PRICE) AS RNK1
		,RANK() OVER (ORDER BY SALE_PRICE DESC) AS RNK2
	FROM PRODUCT_SIZE
	)
SELECT A.FULL_NAME AS ARTIST,SALE_PRICE,W.NAME AS PAINTING,M.NAME AS MUSEUM,CITY,LABEL AS CANVAS
FROM CTE C
JOIN WORK W ON C.WORK_ID = W.WORK_ID
JOIN ARTIST A ON W.ARTIST_ID = A.ARTIST_ID
JOIN MUSEUM M ON W.MUSEUM_ID = M.MUSEUM_ID
JOIN CANVAS_SIZE S ON C.SIZE_ID = S.SIZE_ID::TEXT
WHERE RNK1 = 1 OR RNK2 = 1;

-- 20. Retrieve the country with the fifth highest number of paintings.
SELECT COUNTRY,NO_OF_PAINTINGS
FROM (
	SELECT COUNTRY,COUNT(WORK_ID) AS NO_OF_PAINTINGS
		,DENSE_RANK() OVER (ORDER BY COUNT(WORK_ID) DESC)
	FROM WORK W
	JOIN MUSEUM M ON W.MUSEUM_ID = M.MUSEUM_ID
	GROUP BY 1
	)
WHERE DENSE_RANK = 5;

-- 21. Retrieve the three most popular and three least popular painting styles.
SELECT STYLE
	,CASE 
		WHEN RNK1 <= 3 THEN 'Least Popular Painting Style'
		ELSE 'Most Popular Painting Style'
		END AS REMARKS
FROM (
	SELECT STYLE
		,DENSE_RANK() OVER (ORDER BY COUNT(WORK_ID)) AS RNK1
		,DENSE_RANK() OVER (ORDER BY COUNT(WORK_ID) DESC) AS RNK2
	FROM WORK
	WHERE STYLE IS NOT NULL
	GROUP BY 1
	)
WHERE RNK1 <= 3 OR RNK2 <= 3;

-- 22. Retrieve the artist with the highest number of portrait paintings located outside of the USA. 
-- Present the artist's name, the number of paintings, and their nationality.
SELECT ARTIST,NATIONALITY,NO_OF_PAINTINGS
FROM (
	SELECT FULL_NAME AS ARTIST,COUNT(W.WORK_ID) AS NO_OF_PAINTINGS,NATIONALITY
		,RANK() OVER (ORDER BY COUNT(W.WORK_ID) DESC)
	FROM ARTIST A
	JOIN WORK W ON A.ARTIST_ID = W.ARTIST_ID
	JOIN MUSEUM M ON M.MUSEUM_ID = W.MUSEUM_ID
	JOIN SUBJECT S ON W.WORK_ID = S.WORK_ID
	WHERE SUBJECT = 'Portraits' AND COUNTRY <> 'USA'
	GROUP BY 1,3
	)
WHERE RANK = 1;

----------------------------------------------------------------------------------------------------------------------------