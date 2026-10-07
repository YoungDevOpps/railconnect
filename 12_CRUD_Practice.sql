-- 12. CRUD Practice (un seul lot : les variables sont partagees)
USE RailConnect;

DECLARE @today DATE = CAST(GETDATE() AS DATE);
DECLARE @now   DATETIME2(0) = SYSDATETIME();
DECLARE @day   DATETIME2(0) = CAST(DATEADD(DAY, 7, @today) AS DATETIME2(0));
DECLARE @passenger INT, @train INT, @line INT, @journey INT, @booking INT, @ticket INT, @payment INT;

-- CREATE : passager
INSERT INTO passenger (first_name, last_name, email, phone, category)
VALUES ('Awa', 'Konate', 'awa.konate@mail.ml', '+223 70000001', 'ADULT');
SET @passenger = SCOPE_IDENTITY();

-- CREATE : train, voitures, sieges
INSERT INTO train (code, model) VALUES ('RC-216', 'Siemens Desiro');
SET @train = SCOPE_IDENTITY();

INSERT INTO carriage (train_id, carriage_no, travel_class)
VALUES (@train, 1, 'FIRST'), (@train, 2, 'SECOND'), (@train, 3, 'SECOND'), (@train, 4, 'SECOND'), (@train, 5, 'SECOND');

INSERT INTO seat (carriage_id, seat_no)
SELECT c.carriage_id, v.n
FROM carriage c
CROSS JOIN (VALUES (1), (2), (3), (4), (5), (6), (7), (8)) v(n)
WHERE c.train_id = @train;

-- CREATE : ligne et gares ordonnees
INSERT INTO railway_line (code, name) VALUES ('L9', 'Bamako - Segou Express');
SET @line = SCOPE_IDENTITY();

INSERT INTO line_station (line_id, stop_order, station_id, distance_from_prev_km)
VALUES (@line, 1, 1, 0), (@line, 2, 3, 60), (@line, 3, 14, 170), (@line, 4, 11, 35);

-- CREATE : planifier un trajet (les arrets sont copies depuis la ligne)
INSERT INTO journey (line_id, train_id, service_date) VALUES (@line, @train, DATEADD(DAY, 7, @today));
SET @journey = SCOPE_IDENTITY();

INSERT INTO journey_stop (journey_id, stop_order, station_id, planned_arrival, planned_departure, platform)
SELECT @journey, stop_order, station_id,
       DATEADD(MINUTE, 480 + (stop_order - 1) * 60, @day),
       DATEADD(MINUTE, 485 + (stop_order - 1) * 60, @day), '1'
FROM line_station
WHERE line_id = @line;

-- CREATE : reservation de 2 billets Bamako -> Segou
INSERT INTO booking (passenger_id, booked_at) VALUES (@passenger, @now);
SET @booking = SCOPE_IDENTITY();

INSERT INTO ticket (booking_id, journey_id, origin_station_id, dest_station_id, seat_id, travel_class, price)
SELECT TOP 2 @booking, @journey, 1, 11, s.seat_id, c.travel_class, 12000
FROM seat s
JOIN carriage c ON c.carriage_id = s.carriage_id
WHERE c.train_id = @train
ORDER BY s.seat_id;

UPDATE booking
SET total_amount = (SELECT SUM(price) FROM ticket WHERE booking_id = @booking)
WHERE booking_id = @booking;

-- CREATE : tentatives de paiement (1 echec, puis 1 succes)
INSERT INTO payment (booking_id, amount, method, status, attempted_at)
VALUES (@booking, 24000, 'CARD', 'FAILED', @now);

INSERT INTO payment (booking_id, amount, method, status, attempted_at, paid_at)
VALUES (@booking, 24000, 'MOBILE_MONEY', 'SUCCESS', @now, @now);
SET @payment = SCOPE_IDENTITY();

UPDATE booking SET status = 'PAID' WHERE booking_id = @booking;
UPDATE ticket SET status = 'PAID' WHERE booking_id = @booking;

-- UPDATE + CREATE : annuler un billet et le rembourser a 80 %
SELECT @ticket = MAX(ticket_id) FROM ticket WHERE booking_id = @booking;

UPDATE ticket SET status = 'CANCELLED' WHERE ticket_id = @ticket;
INSERT INTO cancellation (ticket_id, reason) VALUES (@ticket, 'Demande du passager');
INSERT INTO refund (ticket_id, payment_id, amount, reason)
SELECT ticket_id, @payment, price * 0.8, 'Annulation passager (80 %)' FROM ticket WHERE ticket_id = @ticket;

-- UPDATE : retard de 15 min au 2e arret du trajet 80
UPDATE journey_stop
SET actual_arrival = DATEADD(MINUTE, 15, planned_arrival),
    actual_departure = DATEADD(MINUTE, 15, planned_departure)
WHERE journey_id = 80 AND stop_order = 2;

INSERT INTO delay (journey_id, station_id, minutes, reason)
SELECT journey_id, station_id, 15, 'Signalisation' FROM journey_stop WHERE journey_id = 80 AND stop_order = 2;

-- CREATE : maintenance et incident
INSERT INTO maintenance (train_id, maintenance_type, start_date, duration_days, cost, result)
VALUES (@train, 'INSPECTION', @today, 1, 95000, 'PASSED');

INSERT INTO incident (train_id, journey_id, severity, category, description)
VALUES (@train, NULL, 'LOW', 'TECHNICAL', 'Climatisation defaillante voiture 3');

-- CREATE : affecter l'equipage
INSERT INTO journey_crew (journey_id, employee_id) VALUES (@journey, 1), (@journey, 13), (@journey, 25);

-- READ
SELECT * FROM passenger WHERE passenger_id = @passenger;
SELECT * FROM ticket WHERE booking_id = @booking;
SELECT * FROM journey_stop WHERE journey_id = @journey ORDER BY stop_order;

-- UPDATE
UPDATE passenger SET phone = '+223 76000002' WHERE passenger_id = @passenger;
UPDATE incident SET status = 'RESOLVED', resolved_at = SYSDATETIME()
WHERE train_id = @train AND status = 'OPEN';

-- DELETE
DELETE FROM journey_crew WHERE journey_id = @journey AND employee_id = 25;
DELETE FROM passenger_document WHERE expiry_date < @today;
