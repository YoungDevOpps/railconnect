-- 28. Audit Log (SQL Server)
-- La table audit_log est creee au point 10 :
--   table_name, record_id, operation, changed_at, changed_by, old_values (JSON), new_values (JSON).
-- Un trigger AFTER INSERT, UPDATE, DELETE par table : FULL JOIN inserted/deleted pour deduire l'operation.
USE RailConnect;
GO

-- Remplace le trigger de statut du point 27 par un audit complet du billet
DROP TRIGGER IF EXISTS trg_ticket_status_audit;
GO

-- 1. Billets
CREATE OR ALTER TRIGGER trg_audit_ticket ON ticket AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values)
    SELECT 'ticket', CAST(COALESCE(i.ticket_id, d.ticket_id) AS VARCHAR(50)),
           CASE WHEN d.ticket_id IS NULL THEN 'INSERT' WHEN i.ticket_id IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
           CASE WHEN d.ticket_id IS NOT NULL THEN
               (SELECT d.status, d.price, d.seat_id, d.journey_id, d.origin_station_id, d.dest_station_id
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           CASE WHEN i.ticket_id IS NOT NULL THEN
               (SELECT i.status, i.price, i.seat_id, i.journey_id, i.origin_station_id, i.dest_station_id
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
    FROM inserted i
    FULL JOIN deleted d ON d.ticket_id = i.ticket_id;
END;
GO

-- 2. Paiements
CREATE OR ALTER TRIGGER trg_audit_payment ON payment AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values)
    SELECT 'payment', CAST(COALESCE(i.payment_id, d.payment_id) AS VARCHAR(50)),
           CASE WHEN d.payment_id IS NULL THEN 'INSERT' WHEN i.payment_id IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
           CASE WHEN d.payment_id IS NOT NULL THEN
               (SELECT d.booking_id, d.amount, d.method, d.status, d.paid_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           CASE WHEN i.payment_id IS NOT NULL THEN
               (SELECT i.booking_id, i.amount, i.method, i.status, i.paid_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
    FROM inserted i
    FULL JOIN deleted d ON d.payment_id = i.payment_id;
END;
GO

-- 3. Annulations
CREATE OR ALTER TRIGGER trg_audit_cancellation ON cancellation AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values)
    SELECT 'cancellation', CAST(COALESCE(i.cancellation_id, d.cancellation_id) AS VARCHAR(50)),
           CASE WHEN d.cancellation_id IS NULL THEN 'INSERT' WHEN i.cancellation_id IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
           CASE WHEN d.cancellation_id IS NOT NULL THEN
               (SELECT d.journey_id, d.ticket_id, d.reason, d.cancelled_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           CASE WHEN i.cancellation_id IS NOT NULL THEN
               (SELECT i.journey_id, i.ticket_id, i.reason, i.cancelled_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
    FROM inserted i
    FULL JOIN deleted d ON d.cancellation_id = i.cancellation_id;
END;
GO

-- 4. Regles tarifaires
CREATE OR ALTER TRIGGER trg_audit_pricing_rule ON pricing_rule AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values)
    SELECT 'pricing_rule', CAST(COALESCE(i.rule_id, d.rule_id) AS VARCHAR(50)),
           CASE WHEN d.rule_id IS NULL THEN 'INSERT' WHEN i.rule_id IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
           CASE WHEN d.rule_id IS NOT NULL THEN
               (SELECT d.line_id, d.travel_class, d.min_days_before, d.price_per_km, d.demand_factor,
                       d.valid_from, d.valid_to FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           CASE WHEN i.rule_id IS NOT NULL THEN
               (SELECT i.line_id, i.travel_class, i.min_days_before, i.price_per_km, i.demand_factor,
                       i.valid_from, i.valid_to FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
    FROM inserted i
    FULL JOIN deleted d ON d.rule_id = i.rule_id;
END;
GO

-- 5. Equipage (cle composee : record_id = "journey_id-employee_id")
CREATE OR ALTER TRIGGER trg_audit_journey_crew ON journey_crew AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values)
    SELECT 'journey_crew',
           CONCAT(COALESCE(i.journey_id, d.journey_id), '-', COALESCE(i.employee_id, d.employee_id)),
           CASE WHEN d.journey_id IS NULL THEN 'INSERT' WHEN i.journey_id IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
           CASE WHEN d.journey_id IS NOT NULL THEN
               (SELECT d.journey_id, d.employee_id, d.assigned_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           CASE WHEN i.journey_id IS NOT NULL THEN
               (SELECT i.journey_id, i.employee_id, i.assigned_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
    FROM inserted i
    FULL JOIN deleted d ON d.journey_id = i.journey_id AND d.employee_id = i.employee_id;
END;
GO

-- 6. Qui a modifie quoi, et quand ?
SELECT changed_at, changed_by, table_name, record_id, operation, old_values, new_values
FROM audit_log
ORDER BY changed_at DESC;

-- Historique d'un billet, avec le statut avant / apres
SELECT changed_at, changed_by, operation,
       JSON_VALUE(old_values, '$.status') AS old_status,
       JSON_VALUE(new_values, '$.status') AS new_status
FROM audit_log
WHERE table_name = 'ticket' AND record_id = '1'
ORDER BY changed_at;

-- Activite par utilisateur et par table
SELECT changed_by, table_name, operation, COUNT(*) AS changes, MAX(changed_at) AS last_change
FROM audit_log
GROUP BY changed_by, table_name, operation
ORDER BY changes DESC;
