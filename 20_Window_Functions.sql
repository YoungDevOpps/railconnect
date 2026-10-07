-- 20. Window Functions
USE RailConnect;

-- 1. ROW_NUMBER : numerotation des trajets au sein de chaque ligne
SELECT line_id, journey_id, service_date,
       ROW_NUMBER() OVER (PARTITION BY line_id ORDER BY service_date) AS journey_no_on_line
FROM journey;

-- 2. RANK : passagers par depense
SELECT passenger_id, SUM(price) AS total_spent, RANK() OVER (ORDER BY SUM(price) DESC) AS spending_rank
FROM v_paid_ticket
GROUP BY passenger_id;

-- 3. DENSE_RANK : gares par trafic (arrets de trains)
SELECT s.name, COUNT(*) AS train_stops, DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS traffic_rank
FROM journey_stop js
JOIN station s ON s.station_id = js.station_id
GROUP BY s.name;

-- 4. LAG : retard du trajet precedent sur la meme ligne
WITH journey_delay AS (
    SELECT j.journey_id, j.line_id, j.service_date,
           MAX(DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)) AS delay_min
    FROM journey j
    JOIN journey_stop js ON js.journey_id = j.journey_id
    WHERE js.actual_arrival IS NOT NULL
    GROUP BY j.journey_id, j.line_id, j.service_date
)
SELECT line_id, journey_id, service_date, delay_min,
       LAG(delay_min) OVER (PARTITION BY line_id ORDER BY service_date) AS previous_delay_min,
       delay_min - LAG(delay_min) OVER (PARTITION BY line_id ORDER BY service_date) AS variation
FROM journey_delay;

-- 5. LEAD : gare suivante de chaque arret
SELECT js.journey_id, js.stop_order, s.name AS station,
       LEAD(s.name) OVER (PARTITION BY js.journey_id ORDER BY js.stop_order) AS next_station,
       DATEDIFF(MINUTE, js.planned_departure,
                LEAD(js.planned_arrival) OVER (PARTITION BY js.journey_id ORDER BY js.stop_order)) AS minutes_to_next
FROM journey_stop js
JOIN station s ON s.station_id = js.station_id;

-- 6. SUM() OVER : depense cumulee par passager
SELECT b.passenger_id, p.paid_at, p.amount,
       SUM(p.amount) OVER (PARTITION BY b.passenger_id ORDER BY p.paid_at, p.payment_id
                           ROWS UNBOUNDED PRECEDING) AS cumulative_spent
FROM payment p
JOIN booking b ON b.booking_id = p.booking_id
WHERE p.status = 'SUCCESS';

-- 7. AVG() OVER : revenu d'un trajet compare a la moyenne de sa ligne
WITH journey_revenue AS (
    SELECT journey_id, line_id, SUM(price) AS revenue FROM v_paid_ticket GROUP BY journey_id, line_id
)
SELECT journey_id, line_id, revenue,
       AVG(revenue) OVER (PARTITION BY line_id) AS line_avg_revenue,
       revenue - AVG(revenue) OVER (PARTITION BY line_id) AS diff_vs_line
FROM journey_revenue;

-- 8. Revenu mensuel glissant sur 3 mois
WITH monthly AS (
    SELECT CONVERT(CHAR(7), paid_at, 126) AS revenue_month, SUM(amount) AS revenue
    FROM payment
    WHERE status = 'SUCCESS'
    GROUP BY CONVERT(CHAR(7), paid_at, 126)
)
SELECT revenue_month, revenue,
       SUM(revenue) OVER (ORDER BY revenue_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_3_months
FROM monthly;

-- 9. Les trois meilleurs trajets par ligne (revenu)
WITH journey_revenue AS (
    SELECT journey_id, line_id, SUM(price) AS revenue FROM v_paid_ticket GROUP BY journey_id, line_id
), ranked AS (
    SELECT journey_id, line_id, revenue,
           ROW_NUMBER() OVER (PARTITION BY line_id ORDER BY revenue DESC) AS rn
    FROM journey_revenue
)
SELECT line_id, rn AS position, journey_id, revenue
FROM ranked
WHERE rn <= 3
ORDER BY line_id, rn;
