-- 23. Views
-- Dynamique = vue classique, toujours a jour.
-- Materialisee = en SQL Server : vue indexee (WITH SCHEMABINDING + index cluster unique)
--                ou table de synthese rechargee par un job planifie.
USE RailConnect;
GO

-- DYNAMIQUE : la disponibilite doit etre exacte en temps reel (vente en cours).
CREATE OR ALTER VIEW available_seats_by_journey AS
SELECT j.journey_id, j.service_date, j.status, cap.seats AS total_seats,
       COUNT(DISTINCT t.seat_id) AS seats_sold,
       cap.seats - COUNT(DISTINCT t.seat_id) AS seats_fully_free
FROM journey j
JOIN v_train_capacity cap ON cap.train_id = j.train_id
LEFT JOIN ticket t ON t.journey_id = j.journey_id AND t.status <> 'CANCELLED'
GROUP BY j.journey_id, j.service_date, j.status, cap.seats;
GO

-- MATERIALISEE : les trajets termines ne changent plus ; rechargement quotidien suffisant.
CREATE OR ALTER VIEW journey_delay_summary AS
SELECT j.journey_id, j.line_id, j.train_id, j.service_date,
       AVG(1.0 * DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)) AS avg_delay_min,
       MAX(DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)) AS max_delay_min,
       SUM(CASE WHEN js.actual_arrival > js.planned_arrival THEN 1 ELSE 0 END) AS late_stops
FROM journey j
JOIN journey_stop js ON js.journey_id = j.journey_id
WHERE js.actual_arrival IS NOT NULL
GROUP BY j.journey_id, j.line_id, j.train_id, j.service_date;
GO

-- MATERIALISEE : agregat lourd sur tout l'historique, utilise pour le reporting.
CREATE OR ALTER VIEW passenger_spending_summary AS
SELECT p.passenger_id, p.first_name, p.last_name, p.category,
       COUNT(v.ticket_id) AS tickets, COALESCE(SUM(v.price), 0) AS total_spent,
       MAX(v.service_date) AS last_journey_date
FROM passenger p
LEFT JOIN v_paid_ticket v ON v.passenger_id = p.passenger_id
GROUP BY p.passenger_id, p.first_name, p.last_name, p.category;
GO

-- MATERIALISEE : les mois clos sont figes ; seul le mois courant evolue.
CREATE OR ALTER VIEW monthly_revenue AS
SELECT revenue_month, SUM(paid) AS gross_revenue, SUM(refunded) AS refunds,
       SUM(paid) - SUM(refunded) AS net_revenue
FROM (
    SELECT CONVERT(CHAR(7), paid_at, 126) AS revenue_month, amount AS paid, 0 AS refunded
    FROM payment WHERE status = 'SUCCESS'
    UNION ALL
    SELECT CONVERT(CHAR(7), refunded_at, 126), 0, amount
    FROM refund
) x
GROUP BY revenue_month;
GO

-- DYNAMIQUE : peu de lignes (trains), decision de securite => donnees fraiches.
CREATE OR ALTER VIEW train_maintenance_status AS
SELECT t.train_id, t.code, t.status, MAX(m.start_date) AS last_maintenance,
       DATEADD(DAY, t.maintenance_interval_days, MAX(m.start_date)) AS next_due,
       CASE WHEN MAX(m.start_date) IS NULL
              OR DATEADD(DAY, t.maintenance_interval_days, MAX(m.start_date)) < CAST(GETDATE() AS DATE)
            THEN 'OVERDUE' ELSE 'OK' END AS maintenance_status
FROM train t
LEFT JOIN maintenance m ON m.train_id = t.train_id AND m.result = 'PASSED'
GROUP BY t.train_id, t.code, t.status, t.maintenance_interval_days;
GO

-- MATERIALISEE : statistique de frequentation, pas besoin de temps reel.
CREATE OR ALTER VIEW station_traffic_summary AS
SELECT s.station_id, s.name,
       (SELECT COUNT(*) FROM journey_stop js WHERE js.station_id = s.station_id) AS train_stops,
       (SELECT COUNT(*) FROM ticket t WHERE t.origin_station_id = s.station_id AND t.status <> 'CANCELLED') AS boardings,
       (SELECT COUNT(*) FROM ticket t WHERE t.dest_station_id = s.station_id AND t.status <> 'CANCELLED') AS alightings
FROM station s;
GO

-- DYNAMIQUE : sert a la vente et a la detection de surcharge.
CREATE OR ALTER VIEW segment_occupancy AS
SELECT js.journey_id, js.stop_order AS segment_no, js.station_id AS from_station_id,
       COUNT(ts.ticket_id) AS occupied_seats, cap.seats,
       100.0 * COUNT(ts.ticket_id) / cap.seats AS occupancy_pct
FROM journey_stop js
JOIN journey j ON j.journey_id = js.journey_id
JOIN v_train_capacity cap ON cap.train_id = j.train_id
LEFT JOIN v_ticket_segment ts ON ts.journey_id = js.journey_id AND ts.status <> 'CANCELLED'
                             AND ts.origin_order <= js.stop_order AND ts.dest_order > js.stop_order
WHERE js.stop_order < (SELECT MAX(stop_order) FROM journey_stop WHERE journey_id = js.journey_id)
GROUP BY js.journey_id, js.stop_order, js.station_id, cap.seats;
GO

-- DYNAMIQUE : depend de l'heure courante (non materialisable) et la table est petite.
CREATE OR ALTER VIEW active_pricing_rules AS
SELECT r.rule_id, l.code AS line_code, r.travel_class, r.min_days_before, r.price_per_km,
       r.demand_factor, r.valid_from, r.valid_to
FROM pricing_rule r
JOIN railway_line l ON l.line_id = r.line_id
WHERE r.valid_from <= SYSDATETIME() AND (r.valid_to IS NULL OR r.valid_to > SYSDATETIME());
GO
