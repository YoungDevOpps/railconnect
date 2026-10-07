-- 16. Subqueries
USE RailConnect;

-- 1. Passagers depensant plus que la moyenne
SELECT p.passenger_id, p.last_name, s.total_spent
FROM passenger p
JOIN (SELECT passenger_id, SUM(price) AS total_spent FROM v_paid_ticket GROUP BY passenger_id) s
  ON s.passenger_id = p.passenger_id
WHERE s.total_spent > (SELECT AVG(total) FROM (SELECT SUM(price) AS total FROM v_paid_ticket GROUP BY passenger_id) x);

-- 2. Trains dont le cout de maintenance depasse la moyenne
SELECT t.code, (SELECT SUM(m.cost) FROM maintenance m WHERE m.train_id = t.train_id) AS maintenance_cost
FROM train t
WHERE (SELECT SUM(m.cost) FROM maintenance m WHERE m.train_id = t.train_id)
    > (SELECT AVG(total) FROM (SELECT SUM(cost) AS total FROM maintenance GROUP BY train_id) x);

-- 3. Trajets dont le retard moyen depasse la moyenne de leur ligne (sous-requete correlee)
SELECT jd.journey_id, jd.line_id, jd.avg_delay_min
FROM (
    SELECT j.journey_id, j.line_id, AVG(1.0 * DATEDIFF(MINUTE, js.planned_arrival, js.actual_arrival)) AS avg_delay_min
    FROM journey j
    JOIN journey_stop js ON js.journey_id = j.journey_id
    WHERE js.actual_arrival IS NOT NULL
    GROUP BY j.journey_id, j.line_id
) jd
WHERE jd.avg_delay_min > (
    SELECT AVG(1.0 * DATEDIFF(MINUTE, js2.planned_arrival, js2.actual_arrival))
    FROM journey j2
    JOIN journey_stop js2 ON js2.journey_id = j2.journey_id
    WHERE j2.line_id = jd.line_id AND js2.actual_arrival IS NOT NULL
);

-- 4. Gares au trafic (nombre d'arrets de trains) superieur a la moyenne
SELECT s.name, (SELECT COUNT(*) FROM journey_stop js WHERE js.station_id = s.station_id) AS train_stops
FROM station s
WHERE (SELECT COUNT(*) FROM journey_stop js WHERE js.station_id = s.station_id)
    > (SELECT AVG(1.0 * cnt) FROM (SELECT COUNT(*) AS cnt FROM journey_stop GROUP BY station_id) x);

-- 5. Passagers n'ayant jamais annule
SELECT passenger_id, first_name, last_name
FROM passenger
WHERE passenger_id IN (SELECT passenger_id FROM booking)
  AND passenger_id NOT IN (
      SELECT b.passenger_id
      FROM booking b
      JOIN ticket t ON t.booking_id = b.booking_id
      WHERE t.status = 'CANCELLED');

-- 6. Trains sans incident
SELECT code FROM train WHERE train_id NOT IN (SELECT train_id FROM incident);

-- 7. Employes au-dessus du nombre moyen de trajets
SELECT e.employee_id, e.last_name, e.job_role, COUNT(*) AS journeys
FROM employee e
JOIN journey_crew jc ON jc.employee_id = e.employee_id
GROUP BY e.employee_id, e.last_name, e.job_role
HAVING COUNT(*) > (SELECT AVG(1.0 * cnt) FROM (SELECT COUNT(*) AS cnt FROM journey_crew GROUP BY employee_id) x);

-- 8. Lignes dont le revenu depasse la moyenne des lignes
SELECT l.name, r.revenue
FROM railway_line l
JOIN (SELECT line_id, SUM(price) AS revenue FROM v_paid_ticket GROUP BY line_id) r ON r.line_id = l.line_id
WHERE r.revenue > (SELECT AVG(revenue) FROM (SELECT SUM(price) AS revenue FROM v_paid_ticket GROUP BY line_id) x);
