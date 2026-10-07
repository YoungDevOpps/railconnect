-- 35. Final Challenge : rapport operationnel avant un grand jour ferie
-- Prerequis : vues des points 10 et 23. Periode analysee : les 30 prochains jours.
USE RailConnect;

DECLARE @from DATE = CAST(GETDATE() AS DATE);
DECLARE @to   DATE = DATEADD(DAY, 30, @from);

-- Fenetre horaire de chaque trajet a venir
SELECT j.journey_id, j.line_id, j.train_id, j.service_date,
       MIN(js.planned_departure) AS start_at, MAX(js.planned_arrival) AS end_at
INTO #upcoming
FROM journey j
JOIN journey_stop js ON js.journey_id = j.journey_id
WHERE j.status IN ('SCHEDULED', 'IN_PROGRESS') AND j.service_date BETWEEN @from AND @to
GROUP BY j.journey_id, j.line_id, j.train_id, j.service_date;

-- =====================================================================
-- A. Synthese pour la direction : nombre de cas par risque
-- =====================================================================
SELECT 'Segments occupes a plus de 90 %' AS risk, COUNT(*) AS cases
FROM segment_occupancy so JOIN #upcoming u ON u.journey_id = so.journey_id
WHERE so.occupancy_pct > 90
UNION ALL
SELECT 'Conflits de siege (double vente)', COUNT(*)
FROM v_ticket_segment a
JOIN v_ticket_segment b ON b.journey_id = a.journey_id AND b.seat_id = a.seat_id AND b.ticket_id > a.ticket_id
JOIN #upcoming u ON u.journey_id = a.journey_id
WHERE a.status <> 'CANCELLED' AND b.status <> 'CANCELLED'
  AND a.origin_order < b.dest_order AND b.origin_order < a.dest_order
UNION ALL
SELECT 'Billets payes sans paiement reussi', COUNT(*)
FROM ticket t JOIN #upcoming u ON u.journey_id = t.journey_id
WHERE t.status = 'PAID'
  AND NOT EXISTS (SELECT 1 FROM payment p WHERE p.booking_id = t.booking_id AND p.status = 'SUCCESS')
UNION ALL
SELECT 'Conflits d''equipage', COUNT(*)
FROM journey_crew a
JOIN journey_crew b ON b.employee_id = a.employee_id AND b.journey_id > a.journey_id
JOIN #upcoming ua ON ua.journey_id = a.journey_id
JOIN #upcoming ub ON ub.journey_id = b.journey_id
WHERE ua.start_at < ub.end_at AND ub.start_at < ua.end_at
UNION ALL
SELECT 'Conducteurs au permis expire', COUNT(*)
FROM journey_crew jc
JOIN #upcoming u ON u.journey_id = jc.journey_id
JOIN employee e ON e.employee_id = jc.employee_id AND e.job_role = 'DRIVER'
WHERE NOT EXISTS (SELECT 1 FROM driver_licence dl
                  WHERE dl.employee_id = e.employee_id AND dl.expires_on >= u.service_date)
UNION ALL
SELECT 'Trajets planifies pendant une maintenance', COUNT(*)
FROM #upcoming u
JOIN maintenance m ON m.train_id = u.train_id
WHERE u.service_date >= m.start_date AND u.service_date < DATEADD(DAY, m.duration_days, m.start_date)
UNION ALL
SELECT 'Trajets sur un train en retard d''entretien', COUNT(*)
FROM #upcoming u JOIN train_maintenance_status s ON s.train_id = u.train_id
WHERE s.maintenance_status = 'OVERDUE'
UNION ALL
SELECT 'Trajets sur un train avec incident critique ouvert', COUNT(DISTINCT u.journey_id)
FROM #upcoming u
JOIN incident i ON i.train_id = u.train_id AND i.severity = 'CRITICAL' AND i.status <> 'RESOLVED';

-- =====================================================================
-- B. Trajets concernes : une ligne par trajet a risque, avec ses indicateurs
-- =====================================================================
SELECT u.journey_id, u.service_date, t.code AS train, l.name AS line,
       occ.max_occupancy_pct, ms.maintenance_status, mc.maintenance_conflicts,
       inc.critical_incidents, hist.avg_delay_min AS line_avg_delay_min
FROM #upcoming u
JOIN train t ON t.train_id = u.train_id
JOIN railway_line l ON l.line_id = u.line_id
JOIN train_maintenance_status ms ON ms.train_id = u.train_id
CROSS APPLY (SELECT MAX(occupancy_pct) AS max_occupancy_pct
             FROM segment_occupancy so WHERE so.journey_id = u.journey_id) occ
CROSS APPLY (SELECT COUNT(*) AS maintenance_conflicts
             FROM maintenance m
             WHERE m.train_id = u.train_id AND u.service_date >= m.start_date
               AND u.service_date < DATEADD(DAY, m.duration_days, m.start_date)) mc
CROSS APPLY (SELECT COUNT(*) AS critical_incidents
             FROM incident i
             WHERE i.train_id = u.train_id AND i.severity = 'CRITICAL' AND i.status <> 'RESOLVED') inc
CROSS APPLY (SELECT AVG(d.avg_delay_min) AS avg_delay_min
             FROM journey_delay_summary d
             WHERE d.line_id = u.line_id AND d.service_date >= DATEADD(DAY, -30, @from)) hist
WHERE occ.max_occupancy_pct > 90
   OR ms.maintenance_status = 'OVERDUE'
   OR mc.maintenance_conflicts > 0
   OR inc.critical_incidents > 0
   OR hist.avg_delay_min > 10
ORDER BY u.service_date;

-- =====================================================================
-- C. Details par risque
-- =====================================================================

-- C1. Segments surcharges
SELECT so.journey_id, u.service_date, so.segment_no, s.name AS from_station,
       so.occupied_seats, so.seats, so.occupancy_pct
FROM segment_occupancy so
JOIN #upcoming u ON u.journey_id = so.journey_id
JOIN station s ON s.station_id = so.from_station_id
WHERE so.occupancy_pct > 90
ORDER BY so.occupancy_pct DESC;

-- C2. Conflits de siege possibles
SELECT a.journey_id, a.seat_id, a.ticket_id AS ticket_a, b.ticket_id AS ticket_b,
       a.origin_order, a.dest_order, b.origin_order AS b_origin_order, b.dest_order AS b_dest_order
FROM v_ticket_segment a
JOIN v_ticket_segment b ON b.journey_id = a.journey_id AND b.seat_id = a.seat_id AND b.ticket_id > a.ticket_id
JOIN #upcoming u ON u.journey_id = a.journey_id
WHERE a.status <> 'CANCELLED' AND b.status <> 'CANCELLED'
  AND a.origin_order < b.dest_order AND b.origin_order < a.dest_order;

-- C3. Anomalies de paiement : billets payes sans paiement, ecarts de montant, echecs repetes
SELECT 'Billet PAID sans paiement reussi' AS anomaly, t.booking_id, t.ticket_id AS reference, t.price AS amount
FROM ticket t
JOIN #upcoming u ON u.journey_id = t.journey_id
WHERE t.status = 'PAID'
  AND NOT EXISTS (SELECT 1 FROM payment p WHERE p.booking_id = t.booking_id AND p.status = 'SUCCESS')
UNION ALL
SELECT 'Montant paye different du total', b.booking_id, p.payment_id, p.amount - b.total_amount
FROM booking b
JOIN payment p ON p.booking_id = b.booking_id AND p.status = 'SUCCESS'
WHERE p.amount <> b.total_amount
UNION ALL
SELECT 'Paiements echoues sans succes', b.booking_id, COUNT(*), b.total_amount
FROM booking b
JOIN payment p ON p.booking_id = b.booking_id AND p.status = 'FAILED'
WHERE b.booked_at >= DATEADD(DAY, -30, @from)
  AND NOT EXISTS (SELECT 1 FROM payment s WHERE s.booking_id = b.booking_id AND s.status = 'SUCCESS')
GROUP BY b.booking_id, b.total_amount;

-- C4. Conflits d'equipage et permis expires
SELECT e.employee_id, e.last_name, e.job_role, a.journey_id AS journey_a, b.journey_id AS journey_b,
       ua.start_at AS a_start, ua.end_at AS a_end, ub.start_at AS b_start, ub.end_at AS b_end
FROM journey_crew a
JOIN journey_crew b ON b.employee_id = a.employee_id AND b.journey_id > a.journey_id
JOIN #upcoming ua ON ua.journey_id = a.journey_id
JOIN #upcoming ub ON ub.journey_id = b.journey_id
JOIN employee e ON e.employee_id = a.employee_id
WHERE ua.start_at < ub.end_at AND ub.start_at < ua.end_at;

SELECT u.journey_id, u.service_date, e.employee_id, e.last_name, MAX(dl.expires_on) AS licence_expires_on
FROM journey_crew jc
JOIN #upcoming u ON u.journey_id = jc.journey_id
JOIN employee e ON e.employee_id = jc.employee_id AND e.job_role = 'DRIVER'
LEFT JOIN driver_licence dl ON dl.employee_id = e.employee_id
GROUP BY u.journey_id, u.service_date, e.employee_id, e.last_name
HAVING MAX(dl.expires_on) IS NULL OR MAX(dl.expires_on) < u.service_date;

-- C5. Conflits de maintenance et trains en retard d'entretien
SELECT u.journey_id, u.service_date, t.code AS train, m.maintenance_type, m.start_date, m.duration_days
FROM #upcoming u
JOIN maintenance m ON m.train_id = u.train_id
JOIN train t ON t.train_id = u.train_id
WHERE u.service_date >= m.start_date AND u.service_date < DATEADD(DAY, m.duration_days, m.start_date);

SELECT s.code AS train, s.last_maintenance, s.next_due, COUNT(u.journey_id) AS upcoming_journeys
FROM train_maintenance_status s
LEFT JOIN #upcoming u ON u.train_id = s.train_id
WHERE s.maintenance_status = 'OVERDUE'
GROUP BY s.code, s.last_maintenance, s.next_due;

-- C6. Lignes ayant subi des retards sur les 30 derniers jours
SELECT l.name AS line, COUNT(*) AS journeys, AVG(d.avg_delay_min) AS avg_delay_min, MAX(d.max_delay_min) AS worst_delay_min
FROM journey_delay_summary d
JOIN railway_line l ON l.line_id = d.line_id
WHERE d.service_date >= DATEADD(DAY, -30, @from) AND d.late_stops > 0
GROUP BY l.name
ORDER BY avg_delay_min DESC;

DROP TABLE #upcoming;
