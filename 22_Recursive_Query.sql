-- 22. Recursive Query : gares atteignables depuis une gare de depart
-- Anti-boucle : le chemin deja parcouru est memorise et une gare deja visitee n'est pas revisitee.
-- Anti-doublon : GROUP BY final (une ligne par gare, avec le plus petit nombre de sauts).
USE RailConnect;

DECLARE @start INT = 1;

WITH edges AS (
    -- gares voisines sur une meme ligne, dans les deux sens
    SELECT DISTINCT a.station_id AS from_id, b.station_id AS to_id
    FROM line_station a
    JOIN line_station b ON b.line_id = a.line_id AND ABS(b.stop_order - a.stop_order) = 1
), reach AS (
    SELECT @start AS station_id, 0 AS hops, CAST(CONCAT('/', @start, '/') AS VARCHAR(MAX)) AS path
    UNION ALL
    SELECT e.to_id, r.hops + 1, CAST(CONCAT(r.path, e.to_id, '/') AS VARCHAR(MAX))
    FROM reach r
    JOIN edges e ON e.from_id = r.station_id
    WHERE r.path NOT LIKE CONCAT('%/', e.to_id, '/%')
      AND r.hops < 50
)
SELECT s.station_id, s.name, MIN(r.hops) AS min_hops
FROM reach r
JOIN station s ON s.station_id = r.station_id
WHERE r.station_id <> @start
GROUP BY s.station_id, s.name
ORDER BY min_hops
OPTION (MAXRECURSION 100);
