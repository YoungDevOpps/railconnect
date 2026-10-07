-- 14. Aggregation and BI
-- Revenu = billets non annules d'une reservation payee avec succes (vue v_paid_ticket).
USE RailConnect;

-- 1a. Revenu par trajet
SELECT journey_id, SUM(price) AS revenue FROM v_paid_ticket GROUP BY journey_id ORDER BY revenue DESC;

-- 1b. Revenu par ligne
SELECT l.name, SUM(v.price) AS revenue
FROM v_paid_ticket v
JOIN railway_line l ON l.line_id = v.line_id
GROUP BY l.name
ORDER BY revenue DESC;

-- 1c. Revenu par mois (paiements reussis)
SELECT CONVERT(CHAR(7), paid_at, 126) AS revenue_month, SUM(amount) AS revenue
FROM payment
WHERE status = 'SUCCESS'
GROUP BY CONVERT(CHAR(7), paid_at, 126)
ORDER BY revenue_month;

-- 2. Prix moyen du billet par classe
SELECT travel_class, COUNT(*) AS tickets, AVG(price) AS avg_price FROM ticket GROUP BY travel_class;

-- 3. Passagers par trajet
SELECT t.journey_id, COUNT(DISTINCT b.passenger_id) AS passengers, COUNT(*) AS tickets
FROM ticket t
JOIN booking b ON b.booking_id = t.booking_id
WHERE t.status <> 'CANCELLED'
GROUP BY t.journey_id;

-- 4. Taux d'occupation moyen par train (sieges vendus / capacite, par trajet)
SELECT tr.code, AVG(o.occupancy_pct) AS avg_occupancy_pct
FROM (
    SELECT j.journey_id, j.train_id, 100.0 * COUNT(DISTINCT t.seat_id) / cap.seats AS occupancy_pct
    FROM journey j
    JOIN v_train_capacity cap ON cap.train_id = j.train_id
    LEFT JOIN ticket t ON t.journey_id = j.journey_id AND t.status <> 'CANCELLED'
    WHERE j.status <> 'CANCELLED'
    GROUP BY j.journey_id, j.train_id, cap.seats
) o
JOIN train tr ON tr.train_id = o.train_id
GROUP BY tr.code
ORDER BY avg_occupancy_pct DESC;

-- 5. Gares les plus frequentees (montees + descentes)
SELECT TOP 10 s.name, COUNT(*) AS movements
FROM ticket t
CROSS APPLY (VALUES (t.origin_station_id), (t.dest_station_id)) v(station_id)
JOIN station s ON s.station_id = v.station_id
WHERE t.status <> 'CANCELLED'
GROUP BY s.name
ORDER BY movements DESC;

-- 6. Parcours (origine -> destination) les plus rentables
SELECT TOP 10 so.name AS origin, sd.name AS destination, COUNT(*) AS tickets, SUM(v.price) AS revenue
FROM v_paid_ticket v
JOIN station so ON so.station_id = v.origin_station_id
JOIN station sd ON sd.station_id = v.dest_station_id
GROUP BY so.name, sd.name
ORDER BY revenue DESC;

-- 7. Taux d'annulation et de remboursement
SELECT COUNT(*) AS tickets,
       100.0 * SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) / COUNT(*) AS cancellation_rate_pct,
       100.0 * (SELECT COUNT(*) FROM refund) / COUNT(*) AS refund_rate_pct
FROM ticket;

-- 8. Retard moyen par gare (minutes)
SELECT s.name, AVG(1.0 * DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)) AS avg_delay_min
FROM journey_stop js
JOIN station s ON s.station_id = js.station_id
WHERE js.actual_arrival IS NOT NULL
GROUP BY s.name
ORDER BY avg_delay_min DESC;

-- 9. Trains avec le plus d'incidents
SELECT TOP 5 t.code, COUNT(*) AS incidents,
       SUM(CASE WHEN i.status <> 'RESOLVED' THEN 1 ELSE 0 END) AS unresolved
FROM incident i
JOIN train t ON t.train_id = i.train_id
GROUP BY t.code
ORDER BY incidents DESC;

-- 10. Sieges les plus utilises
SELECT TOP 10 tr.code AS train, c.carriage_no, s.seat_no, COUNT(*) AS tickets
FROM ticket t
JOIN seat s ON s.seat_id = t.seat_id
JOIN carriage c ON c.carriage_id = s.carriage_id
JOIN train tr ON tr.train_id = c.train_id
WHERE t.status <> 'CANCELLED'
GROUP BY tr.code, c.carriage_no, s.seat_no
ORDER BY tickets DESC;

-- 11. Points de fidelite par passager
SELECT p.passenger_id, p.last_name, a.tier, a.points_balance,
       SUM(CASE WHEN lt.txn_type = 'EARNED' THEN lt.points ELSE 0 END) AS earned,
       SUM(CASE WHEN lt.txn_type = 'SPENT' THEN -lt.points ELSE 0 END) AS spent
FROM loyalty_account a
JOIN passenger p ON p.passenger_id = a.passenger_id
LEFT JOIN loyalty_transaction lt ON lt.account_id = a.account_id
GROUP BY p.passenger_id, p.last_name, a.tier, a.points_balance
ORDER BY a.points_balance DESC;

-- 12. Passagers depensant plus que la moyenne
SELECT p.passenger_id, p.last_name, SUM(v.price) AS total_spent
FROM v_paid_ticket v
JOIN passenger p ON p.passenger_id = v.passenger_id
GROUP BY p.passenger_id, p.last_name
HAVING SUM(v.price) > (SELECT AVG(total) FROM (SELECT SUM(price) AS total FROM v_paid_ticket GROUP BY passenger_id) x)
ORDER BY total_spent DESC;
