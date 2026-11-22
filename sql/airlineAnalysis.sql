-- Airline Passenger Satisfaction: PostgreSQL analysis queries

-- Q1. Overall satisfaction rate
SELECT 
       COUNT(*) AS total_passengers,
       SUM(satisfied_flag)  AS satisfied_passengers,
       ROUND(100.0 * AVG(satisfied_flag)::numeric, 1) AS pct_satisfied
FROM passengers;

-- Q2. Satisfaction by travel class
SELECT 
       class,
       COUNT(*) AS passengers,
       ROUND(100.0 * AVG(satisfied_flag)::numeric, 1)  AS percentage_satisfied
FROM passengers
GROUP BY class
ORDER BY percentage_satisfied DESC;

-- Q3. Satisfaction by customer type and type of travel
SELECT 
       customer_type,
       type_of_travel,
       COUNT(*) AS passengers,
       ROUND(100.0 * AVG(satisfied_flag)::numeric, 1)  AS percentage_satisfied
FROM passengers
GROUP BY customer_type, type_of_travel
ORDER BY percentage_satisfied;

-- Q4. Impact of departure delay (CASE buckets)
SELECT CASE
           WHEN departure_delay_in_minutes = 0   THEN '1. On time'
           WHEN departure_delay_in_minutes <= 15 THEN '2. 1-15 min'
           WHEN departure_delay_in_minutes <= 60 THEN '3. 16-60 min'
           ELSE '4. 60+ min'
       END AS delay_group,
       COUNT(*) AS passengers,
       ROUND(100.0 * AVG(satisfied_flag)::numeric, 1)  AS percentage_satisfied,
       ROUND(AVG(arrival_delay_in_minutes)::numeric, 1) AS avg_arrival_delay
FROM passengers
GROUP BY delay_group
ORDER BY delay_group;

-- Q5. Average service ratings: satisfied vs not satisfied (rating gap)
SELECT 'seat_comfort' AS factor,
       ROUND(AVG(NULLIF(seat_comfort, 0)) FILTER (WHERE satisfied_flag = 1)::numeric, 2) AS avg_satisfied,
       ROUND(AVG(NULLIF(seat_comfort, 0)) FILTER (WHERE satisfied_flag = 0)::numeric, 2) AS avg_not_satisfied
FROM passengers
UNION ALL
SELECT 'online_boarding',
       ROUND(AVG(NULLIF(online_boarding, 0)) FILTER (WHERE satisfied_flag = 1)::numeric, 2),
       ROUND(AVG(NULLIF(online_boarding, 0)) FILTER (WHERE satisfied_flag = 0)::numeric, 2)
FROM passengers
UNION ALL
SELECT 'inflight_entertainment',
       ROUND(AVG(NULLIF(inflight_entertainment, 0)) FILTER (WHERE satisfied_flag = 1)::numeric, 2),
       ROUND(AVG(NULLIF(inflight_entertainment, 0)) FILTER (WHERE satisfied_flag = 0)::numeric, 2)
FROM passengers
UNION ALL
SELECT 'inflight_wifi_service',
       ROUND(AVG(NULLIF(inflight_wifi_service, 0)) FILTER (WHERE satisfied_flag = 1)::numeric, 2),
       ROUND(AVG(NULLIF(inflight_wifi_service, 0)) FILTER (WHERE satisfied_flag = 0)::numeric, 2)
FROM passengers
UNION ALL
SELECT 'cleanliness',
       ROUND(AVG(NULLIF(cleanliness, 0)) FILTER (WHERE satisfied_flag = 1)::numeric, 2),
       ROUND(AVG(NULLIF(cleanliness, 0)) FILTER (WHERE satisfied_flag = 0)::numeric, 2)
FROM passengers;

-- Q6. CTE + window function: rank segments from least to most satisfied
WITH segment_stats AS (
    SELECT 
	       class,
           type_of_travel,
           customer_type,
           COUNT(*) AS passengers,
           AVG(satisfied_flag) AS satisfaction_rate
    FROM passengers
    GROUP BY class, type_of_travel, customer_type
)
SELECT 
       class,
       type_of_travel,
       customer_type,
       passengers,
       ROUND(100 * satisfaction_rate::numeric, 1) AS percentage_satisfied,
       RANK() OVER (ORDER BY satisfaction_rate ASC)  AS dissatisfaction_rank
FROM segment_stats
ORDER BY dissatisfaction_rank;

-- Q7. Share of total passengers and gap vs overall average (window function)
WITH by_class AS (
    SELECT class,
           COUNT(*) AS passengers,
           AVG(satisfied_flag) AS satisfaction_rate
    FROM passengers
    GROUP BY class
)
SELECT 
       class,
       passengers,
       ROUND(100.0 * passengers / SUM(passengers) OVER (), 1) AS percentage_of_passengers,
       ROUND(100 * satisfaction_rate::numeric, 1) AS percentage_satisfied,
       ROUND(100 * (satisfaction_rate
             - (SELECT AVG(satisfied_flag) FROM passengers))::numeric, 1) AS gap_vs_overall_pts
FROM by_class
ORDER BY percentage_satisfied DESC;
-- Q8. Satisfaction by age group
SELECT 
      CASE
           WHEN age < 18  THEN '1. <18'
           WHEN age <= 25 THEN '2. 18-25'
           WHEN age <= 40 THEN '3. 26-40'
           WHEN age <= 60 THEN '4. 41-60'
           ELSE '5. 60+'
       END AS age_range,
       COUNT(*) AS passengers,
       ROUND(100.0 * AVG(satisfied_flag)::numeric, 1) AS percentage_satisfied
FROM passengers
GROUP BY age_range
ORDER BY age_range;

-- Q9. Delay impact within each class (CTE)
WITH delay_class AS (
    SELECT class,
           CASE WHEN departure_delay_in_minutes > 60 THEN 'Delayed 60+ min'
                WHEN departure_delay_in_minutes > 0  THEN 'Minor delay'
                ELSE 'On time' END AS delay_group,
           satisfied_flag
    FROM passengers
)
SELECT class,
       delay_group,
       COUNT(*) AS passengers,
       ROUND(100.0 * AVG(satisfied_flag)::numeric, 1)  AS percentage_satisfied
FROM delay_class
GROUP BY class, delay_group
ORDER BY class, delay_group;

-- Q10. Passengers who rated key services poorly (<= 2) and their satisfaction
SELECT CASE WHEN seat_comfort BETWEEN 1 AND 2 THEN 'Poor seat comfort'
            WHEN seat_comfort >= 4             THEN 'Good seat comfort'
            ELSE 'Average / N/A' END                   AS seat_group,
       COUNT(*)                                        AS passengers,
       ROUND(100.0 * AVG(satisfied_flag)::numeric, 1)  AS percentage_satisfied
FROM passengers
GROUP BY seat_group
ORDER BY percentage_satisfied;
