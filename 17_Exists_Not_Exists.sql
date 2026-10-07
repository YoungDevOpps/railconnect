-- 17. EXISTS / NOT EXISTS
USE RailConnect;

-- 1. Passagers ayant au moins un paiement reussi
SELECT p.passenger_id, p.first_name, p.last_name
FROM passenger p
WHERE EXISTS (SELECT 1
              FROM booking b
              JOIN payment pay ON pay.booking_id = b.booking_id
              WHERE b.passenger_id = p.passenger_id AND pay.status = 'SUCCESS');

-- 2. Passagers n'ayant jamais termine un trajet
SELECT p.passenger_id, p.first_name, p.last_name
FROM passenger p
WHERE NOT EXISTS (SELECT 1
                  FROM booking b
                  JOIN ticket t ON t.booking_id = b.booking_id
                  WHERE b.passenger_id = p.passenger_id AND t.status = 'COMPLETED');

-- 3. Trains avec des incidents non resolus
SELECT t.code
FROM train t
WHERE EXISTS (SELECT 1 FROM incident i WHERE i.train_id = t.train_id AND i.status <> 'RESOLVED');

-- 4. Trains sans maintenance requise (une maintenance reussie existe dans l'intervalle prevu)
SELECT t.code
FROM train t
WHERE EXISTS (SELECT 1
              FROM maintenance m
              WHERE m.train_id = t.train_id AND m.result = 'PASSED'
                AND m.start_date <= CAST(GETDATE() AS DATE)
                AND m.start_date >= DATEADD(DAY, -t.maintenance_interval_days, CAST(GETDATE() AS DATE)));

-- 5. Gares concernees par des trajets annules
SELECT s.station_id, s.name
FROM station s
WHERE EXISTS (SELECT 1
              FROM journey_stop js
              JOIN journey j ON j.journey_id = js.journey_id
              WHERE js.station_id = s.station_id AND j.status = 'CANCELLED');

-- 6. Lignes dont toutes les gares actives ont ete desservies (double NOT EXISTS = division relationnelle)
SELECT l.code, l.name
FROM railway_line l
WHERE NOT EXISTS (
    SELECT 1
    FROM line_station ls
    JOIN station s ON s.station_id = ls.station_id
    WHERE ls.line_id = l.line_id AND s.is_active = 1
      AND NOT EXISTS (SELECT 1
                      FROM journey j
                      JOIN journey_stop js ON js.journey_id = j.journey_id
                      WHERE j.line_id = l.line_id AND js.station_id = ls.station_id
                        AND js.actual_arrival IS NOT NULL));
