-- 24. Indexing and Performance (SQL Server)
-- SQL Server indexe automatiquement PK et UNIQUE, mais PAS les cles etrangeres.
-- Equivalent de EXPLAIN : SET SHOWPLAN_TEXT ON (plan estime) ; SET STATISTICS IO, TIME ON (mesures reelles).
USE RailConnect;
GO

-- Colonnes frequentes dans les WHERE / JOIN :
--   ticket(journey_id, seat_id, status, booking_id), journey(service_date, line_id, train_id, status),
--   journey_stop(station_id), booking(passenger_id), payment(booking_id, status),
--   maintenance(train_id, start_date), incident(train_id, status), pricing_rule(line_id, valid_from).

-- 1. Index sur les cles etrangeres utiles
CREATE INDEX ix_station_city        ON station (city_id);
CREATE INDEX ix_booking_passenger   ON booking (passenger_id);
CREATE INDEX ix_ticket_booking      ON ticket (booking_id);
CREATE INDEX ix_refund_payment      ON refund (payment_id);
CREATE INDEX ix_crew_employee       ON journey_crew (employee_id);
CREATE INDEX ix_journey_train       ON journey (train_id, service_date);
CREATE INDEX ix_loyalty_txn_account ON loyalty_transaction (account_id);
CREATE INDEX ix_delay_stop          ON delay (journey_id, station_id);

-- 2. Index composes pour les recherches courantes
CREATE INDEX ix_payment_booking_status ON payment (booking_id, status) INCLUDE (amount, paid_at);
CREATE INDEX ix_maintenance_train_date ON maintenance (train_id, start_date) INCLUDE (duration_days, result);
CREATE INDEX ix_pricing_lookup         ON pricing_rule (line_id, travel_class, min_days_before, valid_from);
CREATE INDEX ix_incident_open          ON incident (train_id, severity) WHERE status <> 'RESOLVED';

-- 3. Index pour le controle de conflit de siege : egalite sur (journey_id, seat_id), le reste est couvert
CREATE INDEX ix_ticket_seat_conflict ON ticket (journey_id, seat_id)
    INCLUDE (origin_station_id, dest_station_id, status);

-- 4. Index pour les recherches trajet / date / gare
CREATE INDEX ix_journey_date_line ON journey (service_date, line_id) INCLUDE (train_id, status);
CREATE INDEX ix_stop_station      ON journey_stop (station_id, planned_departure) INCLUDE (planned_arrival);
GO

-- 5. Comparaison des plans avant / apres
-- Executer ce bloc AVANT de creer les index, puis APRES, et comparer.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT ticket_id, origin_station_id, dest_station_id
FROM ticket
WHERE journey_id = 90 AND seat_id = 561 AND status <> 'CANCELLED';

SELECT j.journey_id, js.planned_departure
FROM journey j
JOIN journey_stop js ON js.journey_id = j.journey_id
WHERE j.service_date = DATEADD(DAY, 10, CAST(GETDATE() AS DATE)) AND js.station_id = 5;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- Plan estime sans executer la requete
SET SHOWPLAN_TEXT ON;
GO
SELECT ticket_id FROM ticket WHERE journey_id = 90 AND seat_id = 561;
GO
SET SHOWPLAN_TEXT OFF;
GO

-- Resultat attendu (non mesure ici) :
--   Avant : Clustered Index Scan sur ticket (toute la table lue), "logical reads" eleve.
--   Apres : Index Seek sur ix_ticket_seat_conflict, sans Key Lookup (index couvrant), quelques lectures.
--   Requete trajet/date/gare : Index Seek sur ix_journey_date_line puis sur la PK de journey_stop.

-- 6. Index redondants ou couteux
--   Redondants (a ne pas creer) :
--     line_station(line_id), journey_stop(journey_id)  -> deja prefixe de la PK
--     journey_stop(journey_id, station_id)             -> deja couvert par la contrainte UNIQUE
--     ticket(journey_id) seul                          -> prefixe de ix_ticket_seat_conflict
--     station(code), passenger(email), train(code)     -> deja indexes par UNIQUE
--   Couteux / peu utiles :
--     index sur une colonne peu selective seule (ticket.status, journey.status) -> preferer un index filtre
--     index sur audit_log : table en insertion massive, chaque index ralentit toutes les ecritures
--     trop d'index sur ticket : chaque INSERT/UPDATE de la vente doit tous les maintenir

-- Index inutilises (a surveiller en production)
SELECT OBJECT_NAME(i.object_id) AS table_name, i.name AS index_name,
       u.user_seeks, u.user_scans, u.user_lookups, u.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats u
       ON u.object_id = i.object_id AND u.index_id = i.index_id AND u.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1 AND i.type_desc = 'NONCLUSTERED'
ORDER BY COALESCE(u.user_seeks + u.user_scans + u.user_lookups, 0), u.user_updates DESC;
