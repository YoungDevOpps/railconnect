-- 11. Realistic Data Population (SQL Server)
-- A executer en UN SEUL lot, juste apres le fichier 10 (tables vides, avant les triggers du point 27).
-- Donnees generees par formules (pas de saisie manuelle) ; dates relatives a aujourd'hui.

USE RailConnect;
SET NOCOUNT ON;

DECLARE @today DATE = CAST(GETDATE() AS DATE);
DECLARE @now   DATETIME2(0) = CAST(@today AS DATETIME2(0));

-- Table de nombres 1..1000
CREATE TABLE #n (n INT PRIMARY KEY);
WITH s AS (SELECT 1 AS n UNION ALL SELECT n + 1 FROM s WHERE n < 1000)
INSERT INTO #n SELECT n FROM s OPTION (MAXRECURSION 1000);

CREATE TABLE #fn (i INT, v VARCHAR(50));
INSERT INTO #fn VALUES (0, 'Amadou'), (1, 'Fatoumata'), (2, 'Moussa'), (3, 'Aminata'), (4, 'Ibrahima'),
                       (5, 'Mariam'), (6, 'Oumar'), (7, 'Kadiatou'), (8, 'Seydou'), (9, 'Awa');
CREATE TABLE #ln (i INT, v VARCHAR(50));
INSERT INTO #ln VALUES (0, 'Traore'), (1, 'Diarra'), (2, 'Coulibaly'), (3, 'Keita'), (4, 'Diallo'),
                       (5, 'Sidibe'), (6, 'Kone');

-- 20 villes
INSERT INTO city (name, region) VALUES
('Bamako', 'Bamako'), ('Kati', 'Koulikoro'), ('Koulikoro', 'Koulikoro'), ('Kayes', 'Kayes'),
('Kita', 'Kayes'), ('Bafoulabe', 'Kayes'), ('Nioro', 'Kayes'), ('Sikasso', 'Sikasso'),
('Koutiala', 'Sikasso'), ('Bougouni', 'Sikasso'), ('Segou', 'Segou'), ('San', 'Segou'),
('Niono', 'Segou'), ('Markala', 'Segou'), ('Mopti', 'Mopti'), ('Djenne', 'Mopti'),
('Bandiagara', 'Mopti'), ('Tombouctou', 'Tombouctou'), ('Gao', 'Gao'), ('Kidal', 'Kidal');

-- 35 gares : 1 "Central" par ville (id 1..20) + 1 "Nord" pour les 15 premieres (id 21..35)
INSERT INTO station (city_id, code, name)
SELECT city_id, CONCAT('ST', RIGHT(CONCAT('0', city_id), 2), 'C'), CONCAT(name, ' Central')
FROM city ORDER BY city_id;
INSERT INTO station (city_id, code, name)
SELECT city_id, CONCAT('ST', RIGHT(CONCAT('0', city_id), 2), 'N'), CONCAT(name, ' Nord')
FROM city WHERE city_id <= 15 ORDER BY city_id;
UPDATE station SET is_active = 0 WHERE station_id = 35;

-- 8 lignes de 6 gares ; deux lignes voisines partagent 2 gares (reseau connexe)
INSERT INTO railway_line (code, name)
SELECT CONCAT('L', n), CONCAT('Ligne ', n) FROM #n WHERE n <= 8 ORDER BY n;

INSERT INTO line_station (line_id, stop_order, station_id, distance_from_prev_km)
SELECT l.n, k.n, ((l.n - 1) * 4 + k.n - 1) % 34 + 1,
       CASE WHEN k.n = 1 THEN 0 ELSE 40 + (l.n * 7 + k.n * 13) % 60 END
FROM #n l CROSS JOIN #n k
WHERE l.n <= 8 AND k.n <= 6;

-- 15 trains (RC-201..RC-215) x 5 voitures x 8 sieges = 40 sieges par train
INSERT INTO train (code, model)
SELECT CONCAT('RC-', 200 + n),
       CASE n % 3 WHEN 0 THEN 'Alstom Coradia' WHEN 1 THEN 'Siemens Desiro' ELSE 'CRRC DMU' END
FROM #n WHERE n <= 15 ORDER BY n;

INSERT INTO carriage (train_id, carriage_no, travel_class)
SELECT t.n, c.n, CASE WHEN c.n = 1 THEN 'FIRST' ELSE 'SECOND' END
FROM #n t CROSS JOIN #n c
WHERE t.n <= 15 AND c.n <= 5
ORDER BY t.n, c.n;

INSERT INTO seat (carriage_id, seat_no)
SELECT c.carriage_id, s.n
FROM carriage c CROSS JOIN #n s
WHERE s.n <= 8
ORDER BY c.carriage_id, s.n;

-- 100 trajets : 1 par jour de J-79 a J+20 (79 passes, 21 a venir), 4 annules
INSERT INTO journey (line_id, train_id, service_date, status)
SELECT (n - 1) % 8 + 1, (n - 1) % 15 + 1, DATEADD(DAY, n - 80, @today),
       CASE WHEN n % 25 = 0 THEN 'CANCELLED' WHEN n < 80 THEN 'COMPLETED' ELSE 'SCHEDULED' END
FROM #n WHERE n <= 100 ORDER BY n;

-- Trajet du scenario final (point 31) : #50231, demain, train RC-204
SET IDENTITY_INSERT journey ON;
INSERT INTO journey (journey_id, line_id, train_id, service_date, status)
VALUES (50231, 1, 4, DATEADD(DAY, 1, @today), 'SCHEDULED');
SET IDENTITY_INSERT journey OFF;

-- Arrets : copie de l'ordre de la ligne ; 1 trajet termine sur 4 est en retard
INSERT INTO journey_stop (journey_id, stop_order, station_id, planned_arrival, planned_departure,
                          actual_arrival, actual_departure, platform)
SELECT j.journey_id, ls.stop_order, ls.station_id, x.arr, x.dep,
       CASE WHEN j.status = 'COMPLETED' THEN DATEADD(MINUTE, x.late, x.arr) END,
       CASE WHEN j.status = 'COMPLETED' THEN DATEADD(MINUTE, x.late, x.dep) END,
       CAST(ls.stop_order % 4 + 1 AS VARCHAR(5))
FROM journey j
JOIN line_station ls ON ls.line_id = j.line_id
CROSS APPLY (SELECT DATEADD(MINUTE, (6 + j.journey_id % 12) * 60 + (ls.stop_order - 1) * 50,
                            CAST(j.service_date AS DATETIME2(0))) AS arr) a
CROSS APPLY (SELECT a.arr,
                    CASE WHEN ls.stop_order = 6 THEN a.arr ELSE DATEADD(MINUTE, 5, a.arr) END AS dep,
                    CASE WHEN j.journey_id % 4 = 0 THEN (j.journey_id % 7) * 5 + ls.stop_order * 2 ELSE 0 END AS late) x;

INSERT INTO delay (journey_id, station_id, minutes, reason, recorded_at)
SELECT journey_id, station_id, DATEDIFF(MINUTE, planned_arrival, actual_arrival),
       CASE journey_id % 3 WHEN 0 THEN 'Panne technique' WHEN 1 THEN 'Meteo' ELSE 'Trafic dense' END,
       actual_arrival
FROM journey_stop
WHERE actual_arrival > planned_arrival;

-- 500 passagers, 400 documents
INSERT INTO passenger (first_name, last_name, email, phone, category, created_at)
SELECT f.v, l.v, CONCAT('passager', n, '@mail.ml'),
       CONCAT('+223 7', RIGHT(CONCAT('0000000', n * 7919), 7)),
       CASE n % 10 WHEN 0 THEN 'STUDENT' WHEN 1 THEN 'SENIOR' WHEN 2 THEN 'CHILD' ELSE 'ADULT' END,
       DATEADD(DAY, -200 - n % 300, @now)
FROM #n
JOIN #fn f ON f.i = n % 10
JOIN #ln l ON l.i = n % 7
WHERE n <= 500 ORDER BY n;

INSERT INTO passenger_document (passenger_id, doc_type, doc_number, expiry_date)
SELECT passenger_id, CASE WHEN passenger_id % 2 = 0 THEN 'PASSPORT' ELSE 'ID_CARD' END,
       CONCAT('ML', 100000 + passenger_id), DATEADD(DAY, passenger_id * 3, @today)
FROM passenger WHERE passenger_id <= 400;

-- 736 reservations : 600 normales (6 par trajet) + 136 sur les trajets tres demandes 90 et 95.
-- Les passagers 451..500 n'ont aucune reservation.
INSERT INTO booking (passenger_id, booked_at, status, total_amount)
SELECT (n - 1) % 450 + 1,
       DATEADD(DAY, CASE WHEN n <= 600 THEN (n - 1) % 100 - 100 - n % 30 ELSE -30 - n % 20 END, @now),
       CASE WHEN n % 20 = 0 THEN 'CANCELLED' ELSE 'PAID' END, 0
FROM #n WHERE n <= 736 ORDER BY n;

-- 936 billets : 1 par reservation, 2 pour une reservation normale sur 3 (reservations multi-billets).
-- Les billets d'un trajet vont par paires sur le meme siege : segment 1->2/3 puis 3->4/5/6 (pas de chevauchement).
WITH base AS (
    SELECT b.booking_id, s.n AS seq,
           CASE WHEN b.booking_id <= 600 THEN (b.booking_id - 1) % 100 + 1
                WHEN b.booking_id <= 668 THEN 90 ELSE 95 END AS journey_id
    FROM booking b
    JOIN #n s ON s.n = 1 OR (s.n = 2 AND b.booking_id <= 600 AND b.booking_id % 3 = 0)
), ranked AS (
    SELECT booking_id, seq, journey_id,
           CAST(ROW_NUMBER() OVER (PARTITION BY journey_id ORDER BY booking_id, seq) AS INT) AS r
    FROM base
)
INSERT INTO ticket (booking_id, journey_id, origin_station_id, dest_station_id, seat_id, travel_class, price, status)
SELECT r.booking_id, r.journey_id, o.station_id, d.station_id, s.seat_id, c.travel_class,
       (d.stop_order - o.stop_order) * CASE c.travel_class WHEN 'FIRST' THEN 5000 ELSE 3000 END
           + (r.booking_id % 5) * 250,
       CASE WHEN r.booking_id % 20 = 0 THEN 'CANCELLED'
            WHEN r.booking_id <= 600 AND r.booking_id % 7 = 3 AND r.seq = 1 THEN 'CANCELLED'
            WHEN j.status = 'CANCELLED' THEN 'CANCELLED'
            WHEN j.status = 'COMPLETED' THEN 'COMPLETED'
            ELSE 'PAID' END
FROM ranked r
JOIN journey j ON j.journey_id = r.journey_id
JOIN journey_stop o ON o.journey_id = r.journey_id
                   AND o.stop_order = CASE WHEN r.r % 2 = 1 THEN 1 ELSE 3 END
JOIN journey_stop d ON d.journey_id = r.journey_id
                   AND d.stop_order = CASE WHEN r.r % 2 = 1 THEN 2 + r.booking_id % 2 ELSE 4 + r.booking_id % 3 END
JOIN seat s ON s.seat_id = (j.train_id - 1) * 40 + (((r.r + 1) / 2 - 1) * 7) % 40 + 1
JOIN carriage c ON c.carriage_id = s.carriage_id
ORDER BY r.booking_id, r.seq;

UPDATE b SET total_amount = t.total
FROM booking b
JOIN (SELECT booking_id, SUM(price) AS total FROM ticket GROUP BY booking_id) t ON t.booking_id = b.booking_id;

-- Paiements : 1 echec pour 1 reservation sur 10 ; 1 succes pour toutes sauf 1 sur 20 (jamais payees)
INSERT INTO payment (booking_id, amount, method, status, attempted_at, paid_at)
SELECT booking_id, total_amount, 'CARD', 'FAILED', DATEADD(MINUTE, 1, booked_at), NULL
FROM booking WHERE booking_id % 10 = 0
UNION ALL
SELECT booking_id, total_amount,
       CASE booking_id % 3 WHEN 0 THEN 'CARD' WHEN 1 THEN 'MOBILE_MONEY' ELSE 'CASH' END,
       'SUCCESS', DATEADD(MINUTE, 5, booked_at), DATEADD(MINUTE, 6, booked_at)
FROM booking WHERE booking_id % 20 <> 0;

-- Annulations : trajets annules, puis billets annules individuellement
INSERT INTO cancellation (journey_id, ticket_id, reason, cancelled_at)
SELECT journey_id, NULL, 'Indisponibilite du materiel',
       DATEADD(DAY, -1, CAST(CASE WHEN service_date > @today THEN @today ELSE service_date END AS DATETIME2(0)))
FROM journey WHERE status = 'CANCELLED';

INSERT INTO cancellation (journey_id, ticket_id, reason, cancelled_at)
SELECT NULL, t.ticket_id,
       CASE WHEN b.status = 'CANCELLED' THEN 'Paiement echoue' ELSE 'Demande du passager' END,
       DATEADD(DAY, b.booking_id % 20, b.booked_at)
FROM ticket t
JOIN booking b ON b.booking_id = t.booking_id
JOIN journey j ON j.journey_id = t.journey_id
WHERE t.status = 'CANCELLED' AND j.status <> 'CANCELLED';

-- Remboursements des billets annules deja payes : 100 % si trajet annule, 80 % sinon
INSERT INTO refund (ticket_id, payment_id, amount, reason, refunded_at)
SELECT t.ticket_id, p.payment_id,
       CASE WHEN j.status = 'CANCELLED' THEN t.price ELSE ROUND(t.price * 0.8, 0) END,
       CASE WHEN j.status = 'CANCELLED' THEN 'Trajet annule' ELSE 'Annulation passager' END,
       DATEADD(HOUR, 2, c.cancelled_at)
FROM ticket t
JOIN journey j ON j.journey_id = t.journey_id
JOIN payment p ON p.booking_id = t.booking_id AND p.status = 'SUCCESS'
JOIN cancellation c ON c.ticket_id = t.ticket_id OR c.journey_id = t.journey_id
WHERE t.status = 'CANCELLED';

-- Tarification : 2 classes x 2 paliers d'anticipation par ligne
INSERT INTO pricing_rule (line_id, travel_class, min_days_before, price_per_km, demand_factor, valid_from, valid_to)
SELECT l.line_id, c.cls, d.days, c.base * d.coef, 1, '2025-01-01', NULL
FROM railway_line l
CROSS JOIN (VALUES ('FIRST', 60.0), ('SECOND', 35.0)) c(cls, base)
CROSS JOIN (VALUES (0, 1.0), (30, 0.8)) d(days, coef);

INSERT INTO discount (code, discount_type, target, percent_off, valid_from, valid_to) VALUES
('STUDENT20', 'CATEGORY', 'STUDENT', 20, '2025-01-01', NULL),
('SENIOR25',  'CATEGORY', 'SENIOR',  25, '2025-01-01', NULL),
('CHILD50',   'CATEGORY', 'CHILD',   50, '2025-01-01', NULL),
('GOLD10',    'LOYALTY',  'GOLD',    10, '2025-01-01', NULL),
('FETE15',    'PROMO',    NULL,      15, '2026-12-01', '2027-01-15');

INSERT INTO ticket_discount (ticket_id, discount_id, amount)
SELECT t.ticket_id, d.discount_id, ROUND(t.price * d.percent_off / 100, 0)
FROM ticket t
JOIN booking b ON b.booking_id = t.booking_id
JOIN passenger p ON p.passenger_id = b.passenger_id
JOIN discount d ON d.discount_type = 'CATEGORY' AND d.target = p.category;

-- Fidelite : 300 comptes (account_id = passenger_id), points gagnes / depenses / expires / ajustes
INSERT INTO reward (name, points_cost, available_from, available_to) VALUES
('Cafe offert', 50, '2025-01-01', NULL),
('Acces salon', 150, '2026-01-01', '2026-12-31'),
('Surclassement 1re classe', 200, '2025-01-01', NULL),
('Billet gratuit', 500, '2025-01-01', NULL);

INSERT INTO loyalty_account (passenger_id, tier, points_balance, opened_at)
SELECT passenger_id,
       CASE WHEN passenger_id % 10 = 0 THEN 'GOLD' WHEN passenger_id % 3 = 0 THEN 'SILVER' ELSE 'BRONZE' END,
       0, created_at
FROM passenger WHERE passenger_id <= 300 ORDER BY passenger_id;

INSERT INTO loyalty_transaction (account_id, ticket_id, reward_id, txn_type, points, created_at)
SELECT a.account_id, t.ticket_id, NULL, 'EARNED', CAST(t.price / 100 AS INT),
       DATEADD(DAY, 1, CAST(j.service_date AS DATETIME2(0)))
FROM ticket t
JOIN booking b ON b.booking_id = t.booking_id
JOIN loyalty_account a ON a.passenger_id = b.passenger_id
JOIN journey j ON j.journey_id = t.journey_id
WHERE t.status = 'COMPLETED';

INSERT INTO loyalty_transaction (account_id, ticket_id, reward_id, txn_type, points, created_at)
SELECT account_id, NULL, 1, 'SPENT', -50, @now
FROM loyalty_transaction WHERE account_id % 4 = 0
GROUP BY account_id HAVING SUM(points) >= 50;

INSERT INTO loyalty_transaction (account_id, ticket_id, reward_id, txn_type, points, created_at)
SELECT account_id, NULL, NULL, 'EXPIRED', -10, @now
FROM loyalty_transaction WHERE account_id % 9 = 0
GROUP BY account_id HAVING SUM(points) >= 10;

INSERT INTO loyalty_transaction (account_id, ticket_id, reward_id, txn_type, points, created_at)
SELECT account_id, NULL, NULL, 'ADJUSTED', 20, @now
FROM loyalty_account WHERE account_id % 25 = 0;

UPDATE a SET points_balance = x.total
FROM loyalty_account a
JOIN (SELECT account_id, SUM(points) AS total FROM loyalty_transaction GROUP BY account_id) x
  ON x.account_id = a.account_id;

-- 40 employes : 1-12 conducteurs, 13-24 chefs de bord, 25-30 controleurs, 31-36 techniciens, 37-40 admin
INSERT INTO employee (first_name, last_name, email, job_role, hired_on)
SELECT f.v, l.v, CONCAT('employe', n, '@railconnect.ml'),
       CASE WHEN n <= 12 THEN 'DRIVER' WHEN n <= 24 THEN 'CONDUCTOR' WHEN n <= 30 THEN 'CONTROLLER'
            WHEN n <= 36 THEN 'TECHNICIAN' ELSE 'ADMIN' END,
       DATEADD(DAY, -400 - n * 60, @today)
FROM #n
JOIN #fn f ON f.i = (n + 3) % 10
JOIN #ln l ON l.i = (n + 2) % 7
WHERE n <= 40 ORDER BY n;

-- Permis : celui du conducteur 12 est expire depuis 30 jours
INSERT INTO driver_licence (employee_id, licence_number, issued_on, expires_on)
SELECT employee_id, CONCAT('LIC-', 1000 + employee_id), DATEADD(YEAR, -3, @today),
       CASE WHEN employee_id = 12 THEN DATEADD(DAY, -30, @today) ELSE DATEADD(YEAR, 2, @today) END
FROM employee WHERE job_role = 'DRIVER';

-- Equipage : 1 conducteur + 1 chef de bord + 1 controleur par trajet
INSERT INTO journey_crew (journey_id, employee_id, assigned_at)
SELECT j.journey_id, e.employee_id, DATEADD(DAY, -7, CAST(j.service_date AS DATETIME2(0)))
FROM journey j
JOIN employee e ON e.employee_id IN ((j.journey_id - 1) % 12 + 1,
                                     13 + (j.journey_id - 1) % 12,
                                     25 + (j.journey_id - 1) % 6)
WHERE j.journey_id <= 100;

-- Maintenance : 1 revision ancienne pour tous, 1 recente pour les trains 1..13 (14 et 15 sont en retard d'entretien)
INSERT INTO maintenance (train_id, maintenance_type, start_date, duration_days, cost, result)
SELECT train_id, 'ROUTINE', DATEADD(DAY, -150 - train_id, @today), 2, 150000 + train_id * 10000, 'PASSED'
FROM train
UNION ALL
SELECT train_id, CASE WHEN train_id % 2 = 0 THEN 'REPAIR' ELSE 'INSPECTION' END,
       DATEADD(DAY, -40 - train_id * 2, @today), 1 + train_id % 3, 80000 + train_id * 25000,
       CASE WHEN train_id % 5 = 0 THEN 'FAILED' ELSE 'PASSED' END
FROM train WHERE train_id <= 13;

-- 30 incidents sur les trains 1..12 (les trains 13..15 n'en ont aucun)
INSERT INTO incident (train_id, journey_id, severity, category, description, status, reported_at, resolved_at)
SELECT i.train_id, j.journey_id,
       CASE n % 4 WHEN 0 THEN 'LOW' WHEN 1 THEN 'MEDIUM' WHEN 2 THEN 'HIGH' ELSE 'CRITICAL' END,
       CASE n % 3 WHEN 0 THEN 'TECHNICAL' WHEN 1 THEN 'SAFETY' ELSE 'WEATHER' END,
       CONCAT('Incident signale sur le train RC-', 200 + i.train_id),
       i.status, r.reported_at,
       CASE WHEN i.status = 'RESOLVED' THEN DATEADD(DAY, 2, r.reported_at) END
FROM #n
CROSS APPLY (SELECT n % 12 + 1 AS train_id,
                    CASE n % 5 WHEN 0 THEN 'OPEN' WHEN 1 THEN 'IN_PROGRESS' ELSE 'RESOLVED' END AS status) i
LEFT JOIN journey j ON n % 2 = 0 AND j.journey_id = i.train_id + 15 * (n % 4)
CROSS APPLY (SELECT COALESCE(DATEADD(HOUR, 12, CAST(j.service_date AS DATETIME2(0))),
                             DATEADD(DAY, -n * 4, @now)) AS reported_at) r
WHERE n <= 30;

-- ---------------------------------------------------------------------------
-- Scenario du point 31 et anomalies volontaires (pour que les audits 30 et 35 trouvent des lignes)
-- ---------------------------------------------------------------------------

-- Equipage du trajet 50231 : le chef de bord 21 est deja sur le trajet 81 au meme moment
INSERT INTO journey_crew (journey_id, employee_id) VALUES (50231, 3), (50231, 21), (50231, 26);

-- Maintenance planifiee sur le train 5 le jour du trajet 95
INSERT INTO maintenance (train_id, maintenance_type, start_date, duration_days, cost, result)
VALUES (5, 'REPAIR', DATEADD(DAY, 15, @today), 2, 300000, 'PENDING');

-- Regle tarifaire en chevauchement (ligne 1, SECOND, meme palier)
INSERT INTO pricing_rule (line_id, travel_class, min_days_before, price_per_km, demand_factor, valid_from, valid_to)
VALUES (1, 'SECOND', 0, 40, 1.2, '2026-06-01', NULL);

-- Double vente d'un siege sur le trajet 90
INSERT INTO ticket (booking_id, journey_id, origin_station_id, dest_station_id, seat_id, travel_class, price, status)
SELECT TOP 1 736, journey_id, origin_station_id, dest_station_id, seat_id, travel_class, price, 'PAID'
FROM ticket WHERE journey_id = 90 AND status = 'PAID' ORDER BY ticket_id;

-- Billet PAID sans paiement reussi, paiement incoherent, remboursement excessif, solde fidelite faux
UPDATE ticket SET status = 'PAID' WHERE booking_id = 720;
UPDATE payment SET amount = amount - 1000 WHERE booking_id = 7 AND status = 'SUCCESS';
UPDATE refund SET amount = amount * 2 WHERE refund_id = 1;
UPDATE loyalty_account SET points_balance = points_balance + 500 WHERE account_id = 2;

DROP TABLE #n, #fn, #ln;

-- Controle des volumes
SELECT 'city' AS tbl, COUNT(*) AS nb FROM city
UNION ALL SELECT 'station', COUNT(*) FROM station
UNION ALL SELECT 'railway_line', COUNT(*) FROM railway_line
UNION ALL SELECT 'train', COUNT(*) FROM train
UNION ALL SELECT 'carriage', COUNT(*) FROM carriage
UNION ALL SELECT 'seat', COUNT(*) FROM seat
UNION ALL SELECT 'journey', COUNT(*) FROM journey
UNION ALL SELECT 'passenger', COUNT(*) FROM passenger
UNION ALL SELECT 'booking', COUNT(*) FROM booking
UNION ALL SELECT 'ticket', COUNT(*) FROM ticket
UNION ALL SELECT 'payment', COUNT(*) FROM payment
UNION ALL SELECT 'refund', COUNT(*) FROM refund;
