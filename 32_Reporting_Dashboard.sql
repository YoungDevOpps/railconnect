-- 32. Final Reporting Dashboard
-- Prerequis : vues des points 10 et 23.
USE RailConnect;

-- 1. Revenu total (paiements reussis - remboursements)
SELECT (SELECT COALESCE(SUM(amount), 0) FROM payment WHERE status = 'SUCCESS') AS gross_revenue,
       (SELECT COALESCE(SUM(amount), 0) FROM refund) AS refunds,
       (SELECT COALESCE(SUM(amount), 0) FROM payment WHERE status = 'SUCCESS')
     - (SELECT COALESCE(SUM(amount), 0) FROM refund) AS net_revenue;

-- 2. Revenu mensuel
SELECT revenue_month, gross_revenue, refunds, net_revenue FROM monthly_revenue ORDER BY revenue_month;

-- 3. Revenu par ligne
SELECT l.code, l.name, COALESCE(SUM(v.price), 0) AS revenue
FROM railway_line l
LEFT JOIN v_paid_ticket v ON v.line_id = l.line_id
GROUP BY l.code, l.name
ORDER BY revenue DESC;

-- 4. Nombre de passagers (inscrits / ayant voyage ou reserve)
SELECT (SELECT COUNT(*) FROM passenger) AS registered_passengers,
       (SELECT COUNT(DISTINCT passenger_id) FROM v_paid_ticket) AS paying_passengers;

-- 5. Prix moyen du billet
SELECT AVG(price) AS avg_ticket_price FROM v_paid_ticket;

-- 6. Occupation moyenne (tous segments, trajets non annules)
SELECT AVG(so.occupancy_pct) AS avg_occupancy_pct
FROM segment_occupancy so
JOIN journey j ON j.journey_id = so.journey_id
WHERE j.status <> 'CANCELLED';

-- 7. Meilleurs trajets (revenu)
SELECT TOP 10 v.journey_id, v.service_date, l.name AS line, COUNT(*) AS tickets, SUM(v.price) AS revenue
FROM v_paid_ticket v
JOIN railway_line l ON l.line_id = v.line_id
GROUP BY v.journey_id, v.service_date, l.name
ORDER BY revenue DESC;

-- 8. Gares les plus utilisees
SELECT TOP 10 name, boardings, alightings, boardings + alightings AS traffic
FROM station_traffic_summary
ORDER BY traffic DESC;

-- 9. Taux d'annulation / 10. Taux de remboursement
SELECT 100.0 * SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) / COUNT(*) AS ticket_cancellation_rate_pct,
       100.0 * (SELECT COUNT(*) FROM refund) / COUNT(*) AS refund_rate_pct,
       (SELECT 100.0 * SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) / COUNT(*) FROM journey)
           AS journey_cancellation_rate_pct
FROM ticket;

-- 11. Retard moyen
SELECT AVG(avg_delay_min) AS avg_delay_min, MAX(max_delay_min) AS worst_delay_min,
       100.0 * SUM(CASE WHEN late_stops > 0 THEN 1 ELSE 0 END) / COUNT(*) AS late_journeys_pct
FROM journey_delay_summary;

-- 12. Gares aux pires retards
SELECT TOP 5 s.name, AVG(1.0 * d.minutes) AS avg_delay_min, COUNT(*) AS delays
FROM delay d
JOIN station s ON s.station_id = d.station_id
GROUP BY s.name
ORDER BY avg_delay_min DESC;

-- 13. Cout de maintenance (total, et par type)
SELECT maintenance_type, COUNT(*) AS operations, SUM(cost) AS total_cost, AVG(cost) AS avg_cost
FROM maintenance
GROUP BY ROLLUP (maintenance_type);

-- 14. Statistiques d'incidents
SELECT severity, COUNT(*) AS incidents,
       SUM(CASE WHEN status <> 'RESOLVED' THEN 1 ELSE 0 END) AS unresolved,
       AVG(1.0 * DATEDIFF(HOUR, reported_at, resolved_at)) AS avg_resolution_hours
FROM incident
GROUP BY severity;

-- 15. Statistiques de fidelite
SELECT a.tier, COUNT(*) AS accounts, SUM(a.points_balance) AS points_outstanding,
       SUM(x.earned) AS points_earned, SUM(x.spent) AS points_spent, SUM(x.expired) AS points_expired
FROM loyalty_account a
OUTER APPLY (SELECT COALESCE(SUM(CASE WHEN lt.txn_type = 'EARNED' THEN lt.points END), 0) AS earned,
                    COALESCE(SUM(CASE WHEN lt.txn_type = 'SPENT' THEN -lt.points END), 0) AS spent,
                    COALESCE(SUM(CASE WHEN lt.txn_type = 'EXPIRED' THEN -lt.points END), 0) AS expired
             FROM loyalty_transaction lt
             WHERE lt.account_id = a.account_id) x
GROUP BY a.tier;
