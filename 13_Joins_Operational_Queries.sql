-- 13. Joins and Operational Queries
USE RailConnect;

-- 1. Trajets avec train, ligne, origine et destination
SELECT j.journey_id, j.service_date, j.status, t.code AS train, l.name AS line,
       so.name AS origin, sd.name AS destination
FROM journey j
JOIN train t ON t.train_id = j.train_id
JOIN railway_line l ON l.line_id = j.line_id
JOIN journey_stop o ON o.journey_id = j.journey_id AND o.stop_order = 1
JOIN journey_stop d ON d.journey_id = j.journey_id
                   AND d.stop_order = (SELECT MAX(stop_order) FROM journey_stop WHERE journey_id = j.journey_id)
JOIN station so ON so.station_id = o.station_id
JOIN station sd ON sd.station_id = d.station_id
ORDER BY j.service_date;

-- 2. Passagers d'un trajet
SELECT p.passenger_id, p.first_name, p.last_name, so.name AS origin, sd.name AS destination,
       c.carriage_no, s.seat_no, t.status
FROM ticket t
JOIN booking b ON b.booking_id = t.booking_id
JOIN passenger p ON p.passenger_id = b.passenger_id
JOIN station so ON so.station_id = t.origin_station_id
JOIN station sd ON sd.station_id = t.dest_station_id
JOIN seat s ON s.seat_id = t.seat_id
JOIN carriage c ON c.carriage_id = s.carriage_id
WHERE t.journey_id = 90 AND t.status <> 'CANCELLED'
ORDER BY c.carriage_no, s.seat_no;

-- 3. Capacite des trains
SELECT t.code, COUNT(DISTINCT c.carriage_id) AS carriages, COUNT(s.seat_id) AS seats,
       SUM(CASE WHEN c.travel_class = 'FIRST' THEN 1 ELSE 0 END) AS first_class_seats
FROM train t
LEFT JOIN carriage c ON c.train_id = t.train_id
LEFT JOIN seat s ON s.carriage_id = c.carriage_id
GROUP BY t.code;

-- 4. Reservations avec etat des paiements
SELECT b.booking_id, b.status, b.total_amount,
       COUNT(p.payment_id) AS attempts,
       SUM(CASE WHEN p.status = 'FAILED' THEN 1 ELSE 0 END) AS failed_attempts,
       SUM(CASE WHEN p.status = 'SUCCESS' THEN p.amount ELSE 0 END) AS amount_paid
FROM booking b
LEFT JOIN payment p ON p.booking_id = b.booking_id
GROUP BY b.booking_id, b.status, b.total_amount;

-- 5. Trajets passant par une gare
SELECT j.journey_id, j.service_date, l.name AS line, js.stop_order, js.planned_arrival, js.planned_departure
FROM journey_stop js
JOIN station s ON s.station_id = js.station_id
JOIN journey j ON j.journey_id = js.journey_id
JOIN railway_line l ON l.line_id = j.line_id
WHERE s.code = 'ST05C'
ORDER BY js.planned_arrival;

-- 6. Billets dont la destination n'est pas le terminus du trajet
SELECT t.ticket_id, t.journey_id, sd.name AS ticket_destination, st.name AS journey_terminus
FROM ticket t
JOIN journey_stop term ON term.journey_id = t.journey_id
                      AND term.stop_order = (SELECT MAX(stop_order) FROM journey_stop WHERE journey_id = t.journey_id)
JOIN station sd ON sd.station_id = t.dest_station_id
JOIN station st ON st.station_id = term.station_id
WHERE t.dest_station_id <> term.station_id;

-- 7. Equipage d'un trajet
SELECT jc.journey_id, e.employee_id, e.first_name, e.last_name, e.job_role, dl.licence_number, dl.expires_on
FROM journey_crew jc
JOIN employee e ON e.employee_id = jc.employee_id
LEFT JOIN driver_licence dl ON dl.employee_id = e.employee_id
WHERE jc.journey_id = 90;

-- 8. Trains entretenus cette annee
SELECT t.code, COUNT(*) AS maintenances, MAX(m.start_date) AS last_maintenance, SUM(m.cost) AS total_cost
FROM train t
JOIN maintenance m ON m.train_id = t.train_id
WHERE m.start_date >= DATEFROMPARTS(YEAR(GETDATE()), 1, 1)
  AND m.start_date <= CAST(GETDATE() AS DATE)
GROUP BY t.code;

-- 9. Passagers ayant a la fois des billets annules et des billets termines
SELECT p.passenger_id, p.first_name, p.last_name
FROM passenger p
JOIN booking b ON b.passenger_id = p.passenger_id
JOIN ticket t ON t.booking_id = b.booking_id
GROUP BY p.passenger_id, p.first_name, p.last_name
HAVING SUM(CASE WHEN t.status = 'CANCELLED' THEN 1 ELSE 0 END) > 0
   AND SUM(CASE WHEN t.status = 'COMPLETED' THEN 1 ELSE 0 END) > 0;

-- 10. Gares desservies par plusieurs lignes
SELECT s.station_id, s.name, COUNT(*) AS lines
FROM station s
JOIN line_station ls ON ls.station_id = s.station_id
GROUP BY s.station_id, s.name
HAVING COUNT(*) > 1;
