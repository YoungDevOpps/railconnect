-- 18. CASE Expressions
USE RailConnect;

-- 1. Trajets par gravite de retard (retard maximal a l'arrivee)
SELECT j.journey_id, MAX(DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)) AS max_delay_min,
       CASE WHEN MAX(DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)) <= 0 THEN 'A L''HEURE'
            WHEN MAX(DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)) <= 10 THEN 'LEGER'
            WHEN MAX(DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)) <= 30 THEN 'MODERE'
            ELSE 'SEVERE' END AS delay_severity
FROM journey j
JOIN journey_stop js ON js.journey_id = j.journey_id
WHERE js.actual_arrival IS NOT NULL
GROUP BY j.journey_id;

-- 2. Passagers par depense annuelle
SELECT p.passenger_id, p.last_name, COALESCE(SUM(v.price), 0) AS spent_this_year,
       CASE WHEN COALESCE(SUM(v.price), 0) >= 30000 THEN 'PREMIUM'
            WHEN COALESCE(SUM(v.price), 0) >= 10000 THEN 'REGULIER'
            WHEN COALESCE(SUM(v.price), 0) > 0 THEN 'OCCASIONNEL'
            ELSE 'INACTIF' END AS segment
FROM passenger p
LEFT JOIN v_paid_ticket v ON v.passenger_id = p.passenger_id AND YEAR(v.service_date) = YEAR(GETDATE())
GROUP BY p.passenger_id, p.last_name;

-- 3. Trains par risque de maintenance
SELECT t.code, lm.last_maintenance, DATEDIFF(DAY, lm.last_maintenance, GETDATE()) AS days_since,
       CASE WHEN lm.last_maintenance IS NULL
              OR DATEDIFF(DAY, lm.last_maintenance, GETDATE()) > t.maintenance_interval_days THEN 'ELEVE'
            WHEN DATEDIFF(DAY, lm.last_maintenance, GETDATE()) > 0.7 * t.maintenance_interval_days THEN 'MOYEN'
            ELSE 'FAIBLE' END AS maintenance_risk
FROM train t
LEFT JOIN (SELECT train_id, MAX(start_date) AS last_maintenance
           FROM maintenance WHERE result = 'PASSED' GROUP BY train_id) lm ON lm.train_id = t.train_id;

-- 4. Billets par niveau de prix
SELECT ticket_id, price,
       CASE WHEN price < 5000 THEN 'ECONOMIQUE'
            WHEN price < 10000 THEN 'STANDARD'
            ELSE 'ELEVE' END AS price_band
FROM ticket;

-- 5. Gares par trafic (montees + descentes)
SELECT s.name, COUNT(t.ticket_id) AS movements,
       CASE WHEN COUNT(t.ticket_id) >= 100 THEN 'FORT'
            WHEN COUNT(t.ticket_id) >= 30 THEN 'MOYEN'
            WHEN COUNT(t.ticket_id) > 0 THEN 'FAIBLE'
            ELSE 'AUCUN' END AS traffic_level
FROM station s
LEFT JOIN ticket t ON s.station_id IN (t.origin_station_id, t.dest_station_id) AND t.status <> 'CANCELLED'
GROUP BY s.name;

-- 6. Remboursements par delai d'annulation avant le depart
SELECT r.refund_id, r.amount, DATEDIFF(DAY, c.cancelled_at, o.planned_departure) AS days_before_departure,
       CASE WHEN c.journey_id IS NOT NULL THEN 'ANNULATION OPERATEUR'
            WHEN DATEDIFF(DAY, c.cancelled_at, o.planned_departure) >= 30 THEN 'ANTICIPEE'
            WHEN DATEDIFF(DAY, c.cancelled_at, o.planned_departure) >= 14 THEN 'STANDARD'
            ELSE 'TARDIVE' END AS cancellation_timing
FROM refund r
JOIN ticket t ON t.ticket_id = r.ticket_id
JOIN cancellation c ON c.ticket_id = t.ticket_id OR c.journey_id = t.journey_id
JOIN journey_stop o ON o.journey_id = t.journey_id AND o.station_id = t.origin_station_id;
