-- 21. Temporal Data
-- Deux intervalles [a1, a2[ et [b1, b2[ se chevauchent si a1 < b2 AND b1 < a2.
USE RailConnect;

-- 1. Horaires prevus et reels d'un trajet
SELECT js.stop_order, s.name, js.planned_arrival, js.actual_arrival, js.planned_departure, js.actual_departure
FROM journey_stop js
JOIN station s ON s.station_id = js.station_id
WHERE js.journey_id = 4
ORDER BY js.stop_order;

-- 2. Calcul du retard (a chaque arret, et retard final du trajet)
SELECT journey_id, stop_order,
       DATEDIFF(MINUTE, planned_arrival, actual_arrival) AS arrival_delay_min,
       DATEDIFF(MINUTE, planned_departure, actual_departure) AS departure_delay_min,
       LAST_VALUE(DATEDIFF(MINUTE, planned_arrival, actual_arrival))
           OVER (PARTITION BY journey_id ORDER BY stop_order
                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS final_delay_min
FROM journey_stop
WHERE actual_arrival > planned_arrival;

-- 3. Regles tarifaires actives a un instant donne
DECLARE @ts DATETIME2(0) = '2026-03-15T10:00:00';

SELECT *
FROM pricing_rule
WHERE valid_from <= @ts AND (valid_to IS NULL OR valid_to > @ts);

-- 4. Regles tarifaires qui se chevauchent pour les memes conditions
SELECT a.rule_id AS rule_a, b.rule_id AS rule_b, a.line_id, a.travel_class, a.min_days_before,
       a.valid_from AS a_from, a.valid_to AS a_to, b.valid_from AS b_from, b.valid_to AS b_to
FROM pricing_rule a
JOIN pricing_rule b ON b.line_id = a.line_id AND b.travel_class = a.travel_class
                   AND b.min_days_before = a.min_days_before AND b.rule_id > a.rule_id
WHERE a.valid_from < COALESCE(b.valid_to, '9999-12-31')
  AND b.valid_from < COALESCE(a.valid_to, '9999-12-31');

-- 5. Affectations d'employes qui se chevauchent
WITH journey_window AS (
    SELECT j.journey_id, MIN(js.planned_departure) AS start_at, MAX(js.planned_arrival) AS end_at
    FROM journey j
    JOIN journey_stop js ON js.journey_id = j.journey_id
    WHERE j.status <> 'CANCELLED'
    GROUP BY j.journey_id
)
SELECT e.employee_id, e.last_name, e.job_role, a.journey_id AS journey_a, b.journey_id AS journey_b,
       wa.start_at AS a_start, wa.end_at AS a_end, wb.start_at AS b_start, wb.end_at AS b_end
FROM journey_crew a
JOIN journey_crew b ON b.employee_id = a.employee_id AND b.journey_id > a.journey_id
JOIN journey_window wa ON wa.journey_id = a.journey_id
JOIN journey_window wb ON wb.journey_id = b.journey_id
JOIN employee e ON e.employee_id = a.employee_id
WHERE wa.start_at < wb.end_at AND wb.start_at < wa.end_at;

-- 6. Conflits maintenance / trajet (train planifie pendant sa maintenance)
SELECT j.journey_id, j.service_date, t.code AS train, m.maintenance_id, m.start_date,
       DATEADD(DAY, m.duration_days - 1, m.start_date) AS end_date
FROM journey j
JOIN maintenance m ON m.train_id = j.train_id
JOIN train t ON t.train_id = j.train_id
WHERE j.status <> 'CANCELLED'
  AND j.service_date >= m.start_date
  AND j.service_date < DATEADD(DAY, m.duration_days, m.start_date);

-- 7. Delai de reservation (jours entre l'achat et le depart)
SELECT t.ticket_id, b.booked_at, o.planned_departure,
       DATEDIFF(DAY, b.booked_at, o.planned_departure) AS lead_days
FROM ticket t
JOIN booking b ON b.booking_id = t.booking_id
JOIN journey_stop o ON o.journey_id = t.journey_id AND o.station_id = t.origin_station_id;

SELECT AVG(1.0 * DATEDIFF(DAY, b.booked_at, o.planned_departure)) AS avg_lead_days,
       MIN(DATEDIFF(DAY, b.booked_at, o.planned_departure)) AS min_lead_days,
       MAX(DATEDIFF(DAY, b.booked_at, o.planned_departure)) AS max_lead_days
FROM ticket t
JOIN booking b ON b.booking_id = t.booking_id
JOIN journey_stop o ON o.journey_id = t.journey_id AND o.station_id = t.origin_station_id;
