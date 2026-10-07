-- 31. Final Operational Challenge
-- Le train RC-204 peut-il assurer le trajet #50231 demain ?
-- Chaque controle ajoute une ligne au rapport : OK / ALERTE / BLOQUANT. Un seul BLOQUANT => NO-GO.
USE RailConnect;

DECLARE @train_code VARCHAR(10) = 'RC-204', @journey INT = 50231;

DECLARE @train INT  = (SELECT train_id FROM train WHERE code = @train_code);
DECLARE @day DATE   = (SELECT service_date FROM journey WHERE journey_id = @journey);
DECLARE @line INT   = (SELECT line_id FROM journey WHERE journey_id = @journey);
DECLARE @start DATETIME2(0) = (SELECT MIN(planned_departure) FROM journey_stop WHERE journey_id = @journey);
DECLARE @end   DATETIME2(0) = (SELECT MAX(planned_arrival) FROM journey_stop WHERE journey_id = @journey);

DECLARE @report TABLE (check_no INT, check_name VARCHAR(60), result VARCHAR(10), detail VARCHAR(200));

-- 1. Le train est-il actif (et bien affecte a ce trajet) ?
INSERT INTO @report
SELECT 1, 'Train actif et affecte au trajet',
       CASE WHEN t.status = 'ACTIVE' AND j.train_id = t.train_id THEN 'OK' ELSE 'BLOQUANT' END,
       CONCAT('statut train = ', t.status, ' ; train du trajet = ', j.train_id, ' ; date = ', j.service_date)
FROM train t
CROSS JOIN journey j
WHERE t.train_id = @train AND j.journey_id = @journey;

-- 2. Est-il en maintenance ce jour-la, ou en retard d'entretien ?
INSERT INTO @report
SELECT 2, 'Maintenance',
       CASE WHEN SUM(CASE WHEN @day >= m.start_date AND @day < DATEADD(DAY, m.duration_days, m.start_date)
                          THEN 1 ELSE 0 END) > 0 THEN 'BLOQUANT'
            WHEN MAX(CASE WHEN m.result = 'PASSED' THEN m.start_date END) IS NULL
              OR DATEADD(DAY, t.maintenance_interval_days, MAX(CASE WHEN m.result = 'PASSED' THEN m.start_date END)) < @day
                 THEN 'ALERTE'
            ELSE 'OK' END,
       CONCAT('derniere maintenance reussie = ', MAX(CASE WHEN m.result = 'PASSED' THEN m.start_date END),
              ' ; intervalle = ', t.maintenance_interval_days, ' j')
FROM train t
LEFT JOIN maintenance m ON m.train_id = t.train_id
WHERE t.train_id = @train
GROUP BY t.train_id, t.maintenance_interval_days;

-- 3. A-t-il des incidents critiques non resolus ?
INSERT INTO @report
SELECT 3, 'Incidents critiques non resolus',
       CASE WHEN SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) > 0 THEN 'BLOQUANT'
            WHEN COUNT(*) > 0 THEN 'ALERTE' ELSE 'OK' END,
       CONCAT(COALESCE(SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END), 0), ' critique(s) sur ',
              COUNT(*), ' incident(s) ouvert(s)')
FROM incident
WHERE train_id = @train AND status <> 'RESOLVED';

-- 4. Sa configuration est-elle valide (voitures, sieges, aucune voiture vide) ?
INSERT INTO @report
SELECT 4, 'Configuration du train',
       CASE WHEN COUNT(DISTINCT c.carriage_id) >= 1 AND COUNT(s.seat_id) >= 40
             AND COUNT(DISTINCT c.carriage_id) = COUNT(DISTINCT s.carriage_id) THEN 'OK' ELSE 'BLOQUANT' END,
       CONCAT(COUNT(DISTINCT c.carriage_id), ' voiture(s), ', COUNT(s.seat_id), ' siege(s)')
FROM carriage c
LEFT JOIN seat s ON s.carriage_id = c.carriage_id
WHERE c.train_id = @train;

-- 5. La capacite est-elle suffisante (segment le plus charge vs nombre de sieges) ?
INSERT INTO @report
SELECT 5, 'Capacite',
       CASE WHEN COALESCE(MAX(x.occupied), 0) > cap.seats THEN 'BLOQUANT'
            WHEN COALESCE(MAX(x.occupied), 0) > 0.9 * cap.seats THEN 'ALERTE' ELSE 'OK' END,
       CONCAT('segment le plus charge = ', COALESCE(MAX(x.occupied), 0), ' / ', cap.seats, ' sieges')
FROM v_train_capacity cap
LEFT JOIN (SELECT js.stop_order, COUNT(ts.ticket_id) AS occupied
           FROM journey_stop js
           LEFT JOIN v_ticket_segment ts ON ts.journey_id = js.journey_id AND ts.status <> 'CANCELLED'
                                        AND ts.origin_order <= js.stop_order AND ts.dest_order > js.stop_order
           WHERE js.journey_id = @journey
           GROUP BY js.stop_order) x ON 1 = 1
WHERE cap.train_id = @train
GROUP BY cap.seats;

-- 6. Le conducteur a-t-il un permis valide a la date du trajet ?
INSERT INTO @report
SELECT 6, 'Conducteur et permis',
       CASE WHEN COUNT(e.employee_id) = 0 THEN 'BLOQUANT'
            WHEN SUM(CASE WHEN dl.max_expiry IS NULL OR dl.max_expiry < @day THEN 1 ELSE 0 END) > 0 THEN 'BLOQUANT'
            ELSE 'OK' END,
       CONCAT(COUNT(e.employee_id), ' conducteur(s) ; permis valide jusqu''au ', MIN(dl.max_expiry))
FROM journey_crew jc
JOIN employee e ON e.employee_id = jc.employee_id AND e.job_role = 'DRIVER'
LEFT JOIN (SELECT employee_id, MAX(expires_on) AS max_expiry FROM driver_licence GROUP BY employee_id) dl
       ON dl.employee_id = e.employee_id
WHERE jc.journey_id = @journey;

-- 7. L'equipage a-t-il des conflits d'affectation (autre trajet au meme moment) ?
INSERT INTO @report
SELECT 7, 'Conflits d''equipage',
       CASE WHEN COUNT(*) > 0 THEN 'BLOQUANT' ELSE 'OK' END,
       CONCAT(COUNT(*), ' conflit(s) ; employes : ', COALESCE(STRING_AGG(CAST(o.employee_id AS VARCHAR(10)), ','), '-'))
FROM journey_crew mine
JOIN journey_crew o ON o.employee_id = mine.employee_id AND o.journey_id <> mine.journey_id
JOIN journey oj ON oj.journey_id = o.journey_id AND oj.status <> 'CANCELLED'
JOIN (SELECT journey_id, MIN(planned_departure) AS start_at, MAX(planned_arrival) AS end_at
      FROM journey_stop GROUP BY journey_id) w ON w.journey_id = o.journey_id
WHERE mine.journey_id = @journey AND w.start_at < @end AND @start < w.end_at;

-- 8. Y a-t-il des restrictions de parcours (ligne ou gare inactive) ?
INSERT INTO @report
SELECT 8, 'Restrictions ligne / gares',
       CASE WHEN MIN(CAST(l.is_active AS INT)) = 0 OR MIN(CAST(s.is_active AS INT)) = 0 THEN 'BLOQUANT' ELSE 'OK' END,
       CONCAT(SUM(CASE WHEN s.is_active = 0 THEN 1 ELSE 0 END), ' gare(s) inactive(s) sur ', COUNT(*), ' arret(s)')
FROM journey_stop js
JOIN station s ON s.station_id = js.station_id
JOIN railway_line l ON l.line_id = @line
WHERE js.journey_id = @journey;

-- 9. Y a-t-il une annulation ou un probleme d'exploitation (train deja utilise au meme moment) ?
INSERT INTO @report
SELECT 9, 'Annulation / double utilisation du train',
       CASE WHEN j.status = 'CANCELLED' OR EXISTS (SELECT 1 FROM cancellation c WHERE c.journey_id = j.journey_id)
              OR x.other_journeys > 0 THEN 'BLOQUANT' ELSE 'OK' END,
       CONCAT('statut trajet = ', j.status, ' ; autres trajets du train au meme moment = ', x.other_journeys)
FROM journey j
CROSS APPLY (SELECT COUNT(DISTINCT o.journey_id) AS other_journeys
             FROM journey o
             JOIN journey_stop os ON os.journey_id = o.journey_id
             WHERE o.train_id = @train AND o.journey_id <> @journey AND o.status <> 'CANCELLED'
               AND os.planned_arrival < @end AND os.planned_departure > @start) x
WHERE j.journey_id = @journey;

-- 10. Des retards sont-ils a prevoir (historique de la ligne et du train sur 30 jours) ?
INSERT INTO @report
SELECT 10, 'Retards attendus',
       CASE WHEN COALESCE(AVG(1.0 * DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)), 0) > 10
            THEN 'ALERTE' ELSE 'OK' END,
       CONCAT('retard moyen sur 30 j (ligne ou train) = ',
              CAST(COALESCE(AVG(1.0 * DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)), 0) AS DECIMAL(6,1)),
              ' min sur ', COUNT(DISTINCT j.journey_id), ' trajet(s)')
FROM journey j
JOIN journey_stop js ON js.journey_id = j.journey_id
WHERE (j.line_id = @line OR j.train_id = @train)
  AND js.actual_arrival IS NOT NULL
  AND j.service_date >= DATEADD(DAY, -30, @day);

-- Rapport detaille
SELECT check_no, check_name, result, detail FROM @report ORDER BY check_no;

-- Decision finale
SELECT @train_code AS train, @journey AS journey_id, @day AS service_date,
       SUM(CASE WHEN result = 'BLOQUANT' THEN 1 ELSE 0 END) AS blocking_issues,
       SUM(CASE WHEN result = 'ALERTE' THEN 1 ELSE 0 END) AS warnings,
       CASE WHEN COUNT(*) < 10 THEN 'NO-GO (controle manquant)'
            WHEN SUM(CASE WHEN result = 'BLOQUANT' THEN 1 ELSE 0 END) > 0 THEN 'NO-GO'
            WHEN SUM(CASE WHEN result = 'ALERTE' THEN 1 ELSE 0 END) > 0 THEN 'GO SOUS RESERVE'
            ELSE 'GO' END AS decision
FROM @report;
