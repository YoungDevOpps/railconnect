-- 27. Triggers (SQL Server)
-- A creer apres le chargement des donnees (point 11).
-- Dans un trigger, XACT_ABORT est actif : un THROW annule toute la transaction.
USE RailConnect;
GO

-- 1. Auditer les changements de statut des billets
CREATE OR ALTER TRIGGER trg_ticket_status_audit ON ticket AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values)
    SELECT 'ticket', CAST(i.ticket_id AS VARCHAR(50)), 'UPDATE',
           CONCAT('{"status":"', d.status, '"}'), CONCAT('{"status":"', i.status, '"}')
    FROM inserted i
    JOIN deleted d ON d.ticket_id = i.ticket_id
    WHERE i.status <> d.status;
END;
GO

-- 2a. Le solde de fidelite suit automatiquement l'historique des points
CREATE OR ALTER TRIGGER trg_loyalty_txn_apply ON loyalty_transaction AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    UPDATE a
    SET points_balance = a.points_balance + x.pts
    FROM loyalty_account a
    JOIN (SELECT account_id, SUM(points) AS pts FROM inserted GROUP BY account_id) x ON x.account_id = a.account_id;
END;
GO

-- 2b. Refuser toute modification de solde incoherente avec l'historique (le solde negatif est bloque par le CHECK)
CREATE OR ALTER TRIGGER trg_loyalty_balance_check ON loyalty_account AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(points_balance) AND EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.points_balance <> (SELECT COALESCE(SUM(lt.points), 0)
                                   FROM loyalty_transaction lt WHERE lt.account_id = i.account_id))
        THROW 50020, 'Solde de fidelite incoherent avec l''historique des points', 1;
END;
GO

-- 3. Horodater les paiements reussis
CREATE OR ALTER TRIGGER trg_payment_timestamp ON payment AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE p
    SET paid_at = SYSDATETIME()
    FROM payment p
    JOIN inserted i ON i.payment_id = p.payment_id
    WHERE i.status = 'SUCCESS' AND p.paid_at IS NULL;
END;
GO

-- 4. Interdire la planification d'un trajet pendant la maintenance du train
CREATE OR ALTER TRIGGER trg_journey_no_maintenance ON journey AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN maintenance m ON m.train_id = i.train_id
               WHERE i.status IN ('SCHEDULED', 'IN_PROGRESS')
                 AND i.service_date >= m.start_date
                 AND i.service_date < DATEADD(DAY, m.duration_days, m.start_date))
        THROW 50021, 'Train en maintenance a la date du trajet', 1;
END;
GO

-- 5. Auditer les changements de statut des trajets
CREATE OR ALTER TRIGGER trg_journey_status_audit ON journey AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values)
    SELECT 'journey', CAST(i.journey_id AS VARCHAR(50)), 'UPDATE',
           CONCAT('{"status":"', d.status, '"}'), CONCAT('{"status":"', i.status, '"}')
    FROM inserted i
    JOIN deleted d ON d.journey_id = i.journey_id
    WHERE i.status <> d.status;
END;
GO

-- 6. Rejeter les affectations de siege invalides
CREATE OR ALTER TRIGGER trg_ticket_seat_check ON ticket AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;

    -- le siege doit appartenir au train du trajet
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN journey j ON j.journey_id = i.journey_id
               JOIN seat s ON s.seat_id = i.seat_id
               JOIN carriage c ON c.carriage_id = s.carriage_id
               WHERE c.train_id <> j.train_id)
        THROW 50022, 'Le siege n''appartient pas au train du trajet', 1;

    -- l'origine doit preceder la destination
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN v_ticket_segment ts ON ts.ticket_id = i.ticket_id
               WHERE ts.origin_order >= ts.dest_order)
        THROW 50023, 'L''origine doit preceder la destination', 1;

    -- pas de chevauchement avec un autre billet actif sur le meme siege
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN v_ticket_segment a ON a.ticket_id = i.ticket_id
               JOIN v_ticket_segment b ON b.journey_id = a.journey_id AND b.seat_id = a.seat_id
                                      AND b.ticket_id <> a.ticket_id
               WHERE a.status <> 'CANCELLED' AND b.status <> 'CANCELLED'
                 AND a.origin_order < b.dest_order AND b.origin_order < a.dest_order)
        THROW 50024, 'Siege deja vendu sur un segment qui se chevauche', 1;
END;
GO

-- Tests rapides (annules par ROLLBACK)
BEGIN TRAN;
    UPDATE ticket SET status = 'CANCELLED' WHERE ticket_id = 1;
    SELECT * FROM audit_log WHERE table_name = 'ticket' AND record_id = '1';
ROLLBACK;
GO

BEGIN TRY
    -- siege 1 = train RC-201, alors que le trajet 85 utilise un autre train => erreur 50022
    INSERT INTO ticket (booking_id, journey_id, origin_station_id, dest_station_id, seat_id, travel_class, price)
    SELECT 1, 85, o.station_id, d.station_id, 1, 'FIRST', 5000
    FROM journey_stop o
    JOIN journey_stop d ON d.journey_id = o.journey_id AND d.stop_order = 2
    WHERE o.journey_id = 85 AND o.stop_order = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH;
GO
