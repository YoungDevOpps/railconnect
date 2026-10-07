-- 19. CTEs
USE RailConnect;

-- 1. CTE de revenu puis classement des trajets
WITH journey_revenue AS (
    SELECT journey_id, line_id, SUM(price) AS revenue
    FROM v_paid_ticket
    GROUP BY journey_id, line_id
)
SELECT journey_id, line_id, revenue, RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM journey_revenue;

-- 2. CTE de depense par passager, comparee a la moyenne
WITH spending AS (
    SELECT passenger_id, COUNT(*) AS tickets, SUM(price) AS total_spent
    FROM v_paid_ticket
    GROUP BY passenger_id
), average AS (
    SELECT AVG(total_spent) AS avg_spent FROM spending
)
SELECT p.passenger_id, p.last_name, s.tickets, s.total_spent, s.total_spent - a.avg_spent AS diff_vs_avg
FROM spending s
JOIN passenger p ON p.passenger_id = s.passenger_id
CROSS JOIN average a
ORDER BY s.total_spent DESC;

-- 3. CTE de trafic par gare
WITH boardings AS (
    SELECT origin_station_id AS station_id, COUNT(*) AS n FROM ticket WHERE status <> 'CANCELLED' GROUP BY origin_station_id
), alightings AS (
    SELECT dest_station_id AS station_id, COUNT(*) AS n FROM ticket WHERE status <> 'CANCELLED' GROUP BY dest_station_id
)
SELECT s.name, COALESCE(b.n, 0) AS boardings, COALESCE(a.n, 0) AS alightings,
       COALESCE(b.n, 0) + COALESCE(a.n, 0) AS traffic
FROM station s
LEFT JOIN boardings b ON b.station_id = s.station_id
LEFT JOIN alightings a ON a.station_id = s.station_id
ORDER BY traffic DESC;

-- 4. CTE de statistiques de retard par ligne
WITH journey_delay AS (
    SELECT j.journey_id, j.line_id, MAX(DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)) AS delay_min
    FROM journey j
    JOIN journey_stop js ON js.journey_id = j.journey_id
    WHERE js.actual_arrival IS NOT NULL
    GROUP BY j.journey_id, j.line_id
)
SELECT l.name, COUNT(*) AS journeys, AVG(1.0 * jd.delay_min) AS avg_delay_min, MAX(jd.delay_min) AS max_delay_min,
       100.0 * SUM(CASE WHEN jd.delay_min > 0 THEN 1 ELSE 0 END) / COUNT(*) AS late_journeys_pct
FROM journey_delay jd
JOIN railway_line l ON l.line_id = jd.line_id
GROUP BY l.name;

-- 5. CTE d'occupation par segment, puis segments les plus charges
WITH occupancy AS (
    SELECT js.journey_id, js.stop_order AS segment_no, COUNT(ts.ticket_id) AS occupied_seats
    FROM journey_stop js
    LEFT JOIN v_ticket_segment ts ON ts.journey_id = js.journey_id AND ts.status <> 'CANCELLED'
                                 AND ts.origin_order <= js.stop_order AND ts.dest_order > js.stop_order
    WHERE js.stop_order < (SELECT MAX(stop_order) FROM journey_stop WHERE journey_id = js.journey_id)
    GROUP BY js.journey_id, js.stop_order
)
SELECT TOP 10 o.journey_id, o.segment_no, o.occupied_seats, cap.seats,
       100.0 * o.occupied_seats / cap.seats AS occupancy_pct
FROM occupancy o
JOIN journey j ON j.journey_id = o.journey_id
JOIN v_train_capacity cap ON cap.train_id = j.train_id
ORDER BY occupancy_pct DESC;

-- 6. Detection des conflits de siege avec des CTE
WITH active AS (
    SELECT ticket_id, journey_id, seat_id, origin_order, dest_order
    FROM v_ticket_segment
    WHERE status <> 'CANCELLED'
), conflicts AS (
    SELECT a.journey_id, a.seat_id, a.ticket_id AS ticket_a, b.ticket_id AS ticket_b
    FROM active a
    JOIN active b ON b.journey_id = a.journey_id AND b.seat_id = a.seat_id AND b.ticket_id > a.ticket_id
                 AND a.origin_order < b.dest_order AND b.origin_order < a.dest_order
)
SELECT c.journey_id, tr.code AS train, ca.carriage_no, s.seat_no, c.ticket_a, c.ticket_b
FROM conflicts c
JOIN seat s ON s.seat_id = c.seat_id
JOIN carriage ca ON ca.carriage_id = s.carriage_id
JOIN train tr ON tr.train_id = ca.train_id;
