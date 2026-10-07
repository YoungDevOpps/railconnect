-- 15. Complex Route and Segment Analysis
-- Segment n = troncon entre l'arret n et l'arret n+1.
-- Un billet occupe le segment n si origin_order <= n AND dest_order > n.
USE RailConnect;

-- 1. Positions d'origine et de destination de chaque billet
SELECT ts.ticket_id, ts.journey_id, so.name AS origin, ts.origin_order, sd.name AS destination, ts.dest_order
FROM v_ticket_segment ts
JOIN ticket t ON t.ticket_id = ts.ticket_id
JOIN station so ON so.station_id = t.origin_station_id
JOIN station sd ON sd.station_id = t.dest_station_id;

-- 2. Segments parcourus et distance par billet
SELECT ts.ticket_id, ts.dest_order - ts.origin_order AS segments, SUM(ls.distance_from_prev_km) AS distance_km
FROM v_ticket_segment ts
JOIN journey j ON j.journey_id = ts.journey_id
JOIN line_station ls ON ls.line_id = j.line_id
                    AND ls.stop_order > ts.origin_order AND ls.stop_order <= ts.dest_order
GROUP BY ts.ticket_id, ts.dest_order, ts.origin_order;

-- 3. Occupation de chaque segment de chaque trajet
SELECT js.journey_id, js.stop_order AS segment_no, COUNT(ts.ticket_id) AS occupied_seats, cap.seats,
       100.0 * COUNT(ts.ticket_id) / cap.seats AS occupancy_pct
FROM journey_stop js
JOIN journey j ON j.journey_id = js.journey_id
JOIN v_train_capacity cap ON cap.train_id = j.train_id
LEFT JOIN v_ticket_segment ts ON ts.journey_id = js.journey_id AND ts.status <> 'CANCELLED'
                             AND ts.origin_order <= js.stop_order AND ts.dest_order > js.stop_order
WHERE js.stop_order < (SELECT MAX(stop_order) FROM journey_stop WHERE journey_id = js.journey_id)
GROUP BY js.journey_id, js.stop_order, cap.seats
ORDER BY js.journey_id, js.stop_order;

-- 4. Segments occupes a plus de 90 %
SELECT js.journey_id, js.stop_order AS segment_no, COUNT(ts.ticket_id) AS occupied_seats, cap.seats
FROM journey_stop js
JOIN journey j ON j.journey_id = js.journey_id
JOIN v_train_capacity cap ON cap.train_id = j.train_id
JOIN v_ticket_segment ts ON ts.journey_id = js.journey_id AND ts.status <> 'CANCELLED'
                        AND ts.origin_order <= js.stop_order AND ts.dest_order > js.stop_order
GROUP BY js.journey_id, js.stop_order, cap.seats
HAVING COUNT(ts.ticket_id) > 0.9 * cap.seats;

-- 5. Reservations de siege qui se chevauchent
SELECT a.journey_id, a.seat_id, a.ticket_id AS ticket_a, b.ticket_id AS ticket_b,
       a.origin_order AS a_from, a.dest_order AS a_to, b.origin_order AS b_from, b.dest_order AS b_to
FROM v_ticket_segment a
JOIN v_ticket_segment b ON b.journey_id = a.journey_id AND b.seat_id = a.seat_id AND b.ticket_id > a.ticket_id
WHERE a.status <> 'CANCELLED' AND b.status <> 'CANCELLED'
  AND a.origin_order < b.dest_order AND b.origin_order < a.dest_order;

-- 6. Sieges libres sur un segment mais occupes sur un autre (trajet donne)
DECLARE @journey INT = 90;

WITH seg AS (
    SELECT stop_order FROM journey_stop
    WHERE journey_id = @journey
      AND stop_order < (SELECT MAX(stop_order) FROM journey_stop WHERE journey_id = @journey)
), grid AS (
    SELECT s.seat_id, seg.stop_order,
           CASE WHEN EXISTS (SELECT 1 FROM v_ticket_segment ts
                             WHERE ts.journey_id = @journey AND ts.seat_id = s.seat_id AND ts.status <> 'CANCELLED'
                               AND ts.origin_order <= seg.stop_order AND ts.dest_order > seg.stop_order)
                THEN 1 ELSE 0 END AS occupied
    FROM journey j
    JOIN carriage c ON c.train_id = j.train_id
    JOIN seat s ON s.carriage_id = c.carriage_id
    CROSS JOIN seg
    WHERE j.journey_id = @journey
)
SELECT seat_id,
       STRING_AGG(CASE WHEN occupied = 1 THEN CAST(stop_order AS VARCHAR(3)) END, ',') AS occupied_segments,
       STRING_AGG(CASE WHEN occupied = 0 THEN CAST(stop_order AS VARCHAR(3)) END, ',') AS free_segments
FROM grid
GROUP BY seat_id
HAVING SUM(occupied) > 0 AND SUM(occupied) < COUNT(*);

-- 7. Depassements de capacite (plus de billets que de sieges sur un segment)
SELECT js.journey_id, js.stop_order AS segment_no, COUNT(ts.ticket_id) AS occupied_seats, cap.seats
FROM journey_stop js
JOIN journey j ON j.journey_id = js.journey_id
JOIN v_train_capacity cap ON cap.train_id = j.train_id
JOIN v_ticket_segment ts ON ts.journey_id = js.journey_id AND ts.status <> 'CANCELLED'
                        AND ts.origin_order <= js.stop_order AND ts.dest_order > js.stop_order
GROUP BY js.journey_id, js.stop_order, cap.seats
HAVING COUNT(ts.ticket_id) > cap.seats;

-- 8. Couples origine/destination repetes
SELECT so.name AS origin, sd.name AS destination, COUNT(*) AS tickets
FROM ticket t
JOIN station so ON so.station_id = t.origin_station_id
JOIN station sd ON sd.station_id = t.dest_station_id
GROUP BY so.name, sd.name
HAVING COUNT(*) > 1
ORDER BY tickets DESC;
