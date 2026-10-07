-- 30. Advanced Data-Quality Audit
-- Chaque requete renvoie les lignes en anomalie (0 ligne = controle conforme).
USE RailConnect;

-- 1. Billets dont l'origine ne precede pas la destination
SELECT ticket_id, journey_id, origin_order, dest_order
FROM v_ticket_segment
WHERE origin_order >= dest_order;

-- 2. Billets referencant une gare inactive
SELECT t.ticket_id, s.station_id, s.name
FROM ticket t
JOIN station s ON s.station_id IN (t.origin_station_id, t.dest_station_id)
WHERE s.is_active = 0;

-- 3. Ordre des arrets incorrect : trou dans la numerotation, horaire non croissant, ou ordre different de la ligne
SELECT x.journey_id, x.stop_order, 'TROU OU HORAIRE NON CROISSANT' AS issue
FROM (SELECT journey_id, stop_order, planned_arrival,
             LAG(stop_order) OVER (PARTITION BY journey_id ORDER BY stop_order) AS prev_order,
             LAG(planned_departure) OVER (PARTITION BY journey_id ORDER BY stop_order) AS prev_departure
      FROM journey_stop) x
WHERE (x.prev_order IS NULL AND x.stop_order <> 1)
   OR x.stop_order <> x.prev_order + 1
   OR x.planned_arrival < x.prev_departure
UNION ALL
SELECT js.journey_id, js.stop_order, 'ORDRE DIFFERENT DE LA LIGNE'
FROM journey_stop js
JOIN journey j ON j.journey_id = js.journey_id
LEFT JOIN line_station ls ON ls.line_id = j.line_id AND ls.stop_order = js.stop_order
WHERE ls.station_id IS NULL OR ls.station_id <> js.station_id;

-- 4. Sieges incoherents : numero en double dans une voiture, ou billet sur un siege d'un autre train
SELECT carriage_id, seat_no, COUNT(*) AS duplicates
FROM seat
GROUP BY carriage_id, seat_no
HAVING COUNT(*) > 1;

SELECT t.ticket_id, t.journey_id, j.train_id AS journey_train, c.train_id AS seat_train
FROM ticket t
JOIN journey j ON j.journey_id = t.journey_id
JOIN seat s ON s.seat_id = t.seat_id
JOIN carriage c ON c.carriage_id = s.carriage_id
WHERE c.train_id <> j.train_id;

-- 5. Reservations de siege qui se chevauchent
SELECT a.journey_id, a.seat_id, a.ticket_id AS ticket_a, b.ticket_id AS ticket_b
FROM v_ticket_segment a
JOIN v_ticket_segment b ON b.journey_id = a.journey_id AND b.seat_id = a.seat_id AND b.ticket_id > a.ticket_id
WHERE a.status <> 'CANCELLED' AND b.status <> 'CANCELLED'
  AND a.origin_order < b.dest_order AND b.origin_order < a.dest_order;

-- 6. Ecarts entre montant paye et montant de la reservation (ou total different de la somme des billets)
SELECT b.booking_id, b.status, b.total_amount,
       (SELECT COALESCE(SUM(p.amount), 0) FROM payment p WHERE p.booking_id = b.booking_id AND p.status = 'SUCCESS') AS paid,
       (SELECT COALESCE(SUM(t.price), 0) FROM ticket t WHERE t.booking_id = b.booking_id) AS tickets_total
FROM booking b
WHERE (b.status = 'PAID'
       AND b.total_amount <> (SELECT COALESCE(SUM(p.amount), 0) FROM payment p
                              WHERE p.booking_id = b.booking_id AND p.status = 'SUCCESS'))
   OR b.total_amount <> (SELECT COALESCE(SUM(t.price), 0) FROM ticket t WHERE t.booking_id = b.booking_id);

-- 7. Remboursements excessifs (superieurs au prix du billet ou au paiement d'origine)
SELECT r.refund_id, r.ticket_id, r.amount AS refunded, t.price, p.amount AS payment_amount
FROM refund r
JOIN ticket t ON t.ticket_id = r.ticket_id
JOIN payment p ON p.payment_id = r.payment_id
WHERE r.amount > t.price
   OR p.status <> 'SUCCESS'
   OR (SELECT SUM(r2.amount) FROM refund r2 WHERE r2.payment_id = r.payment_id) > p.amount;

-- 8. Conducteurs affectes sans permis valide a la date du trajet
SELECT j.journey_id, j.service_date, e.employee_id, e.last_name, MAX(dl.expires_on) AS licence_expires_on
FROM journey_crew jc
JOIN journey j ON j.journey_id = jc.journey_id
JOIN employee e ON e.employee_id = jc.employee_id AND e.job_role = 'DRIVER'
LEFT JOIN driver_licence dl ON dl.employee_id = e.employee_id
WHERE j.status <> 'CANCELLED'
GROUP BY j.journey_id, j.service_date, e.employee_id, e.last_name
HAVING MAX(dl.expires_on) IS NULL OR MAX(dl.expires_on) < j.service_date;

-- 9. Conflits train / trajet / maintenance
SELECT j.journey_id, j.service_date, j.train_id, m.maintenance_id, m.start_date, m.duration_days
FROM journey j
JOIN maintenance m ON m.train_id = j.train_id
WHERE j.status <> 'CANCELLED'
  AND j.service_date >= m.start_date
  AND j.service_date < DATEADD(DAY, m.duration_days, m.start_date);

-- 10. Horodatages impossibles
SELECT 'payment' AS source, payment_id AS id, 'paye avant la tentative' AS issue
FROM payment WHERE paid_at < attempted_at
UNION ALL
SELECT 'refund', r.refund_id, 'rembourse avant le paiement'
FROM refund r JOIN payment p ON p.payment_id = r.payment_id WHERE r.refunded_at < p.paid_at
UNION ALL
SELECT 'incident', incident_id, 'resolu avant le signalement'
FROM incident WHERE resolved_at < reported_at
UNION ALL
SELECT 'journey_stop', journey_id, 'depart reel avant l''arrivee reelle'
FROM journey_stop WHERE actual_departure < actual_arrival
UNION ALL
SELECT 'ticket', t.ticket_id, 'reserve apres le depart'
FROM ticket t
JOIN booking b ON b.booking_id = t.booking_id
JOIN journey_stop o ON o.journey_id = t.journey_id AND o.station_id = t.origin_station_id
WHERE b.booked_at > o.planned_departure
UNION ALL
SELECT 'journey', j.journey_id, 'heure reelle sur un trajet futur'
FROM journey j JOIN journey_stop js ON js.journey_id = j.journey_id
WHERE js.actual_arrival > SYSDATETIME();

-- 11. Chevauchement inattendu de regles tarifaires
SELECT a.rule_id AS rule_a, b.rule_id AS rule_b, a.line_id, a.travel_class, a.min_days_before
FROM pricing_rule a
JOIN pricing_rule b ON b.line_id = a.line_id AND b.travel_class = a.travel_class
                   AND b.min_days_before = a.min_days_before AND b.rule_id > a.rule_id
WHERE a.valid_from < COALESCE(b.valid_to, '9999-12-31')
  AND b.valid_from < COALESCE(a.valid_to, '9999-12-31');

-- 12. Billets PAID sans paiement reussi
SELECT t.ticket_id, t.booking_id, t.status
FROM ticket t
WHERE t.status IN ('PAID', 'COMPLETED')
  AND NOT EXISTS (SELECT 1 FROM payment p WHERE p.booking_id = t.booking_id AND p.status = 'SUCCESS');

-- 13. Soldes de fidelite invalides (negatifs ou differents de l'historique)
SELECT a.account_id, a.points_balance, COALESCE(SUM(lt.points), 0) AS history_total
FROM loyalty_account a
LEFT JOIN loyalty_transaction lt ON lt.account_id = a.account_id
GROUP BY a.account_id, a.points_balance
HAVING a.points_balance < 0 OR a.points_balance <> COALESCE(SUM(lt.points), 0);
