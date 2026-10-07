-- 25. Transactions (SQL Server)
-- Modele commun : SET XACT_ABORT ON + BEGIN TRY / BEGIN TRAN / COMMIT, et ROLLBACK dans le CATCH.
USE RailConnect;
GO

-- 1. Creer une reservation et ses billets de facon atomique (passager 460, trajet 85, sieges 399 et 400)
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRAN;

    DECLARE @booking INT;
    INSERT INTO booking (passenger_id) VALUES (460);
    SET @booking = SCOPE_IDENTITY();

    INSERT INTO ticket (booking_id, journey_id, origin_station_id, dest_station_id, seat_id, travel_class, price)
    SELECT @booking, 85, o.station_id, d.station_id, s.seat_id, c.travel_class, 15000
    FROM journey_stop o
    JOIN journey_stop d ON d.journey_id = o.journey_id AND d.stop_order = 6
    JOIN seat s ON s.seat_id IN (399, 400)
    JOIN carriage c ON c.carriage_id = s.carriage_id
    WHERE o.journey_id = 85 AND o.stop_order = 1;

    UPDATE booking
    SET total_amount = (SELECT SUM(price) FROM ticket WHERE booking_id = @booking)
    WHERE booking_id = @booking;

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- 2. Enregistrer un paiement reussi et marquer la reservation payee
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRAN;

    DECLARE @booking INT = (SELECT MAX(booking_id) FROM booking WHERE passenger_id = 460);
    DECLARE @now DATETIME2(0) = SYSDATETIME();

    INSERT INTO payment (booking_id, amount, method, status, attempted_at, paid_at)
    SELECT booking_id, total_amount, 'CARD', 'SUCCESS', @now, @now
    FROM booking WHERE booking_id = @booking AND status = 'PENDING';

    IF @@ROWCOUNT = 0
        THROW 50001, 'Reservation introuvable ou deja traitee', 1;

    UPDATE booking SET status = 'PAID' WHERE booking_id = @booking;
    UPDATE ticket SET status = 'PAID' WHERE booking_id = @booking AND status = 'BOOKED';

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- 3. Annuler un billet et creer son remboursement de facon coherente
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRAN;

    DECLARE @ticket INT = (SELECT MAX(t.ticket_id)
                           FROM ticket t JOIN booking b ON b.booking_id = t.booking_id
                           WHERE b.passenger_id = 460 AND t.status = 'PAID');

    UPDATE ticket SET status = 'CANCELLED' WHERE ticket_id = @ticket AND status = 'PAID';

    IF @@ROWCOUNT = 0
        THROW 50002, 'Billet non annulable', 1;

    INSERT INTO cancellation (ticket_id, reason) VALUES (@ticket, 'Demande du passager');

    INSERT INTO refund (ticket_id, payment_id, amount, reason)
    SELECT t.ticket_id, p.payment_id, t.price * 0.8, 'Annulation passager (80 %)'
    FROM ticket t
    JOIN payment p ON p.booking_id = t.booking_id AND p.status = 'SUCCESS'
    WHERE t.ticket_id = @ticket;

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- 4. Cloturer un trajet et attribuer les points de fidelite (1 point par 100 de prix)
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRAN;

    DECLARE @journey INT = 80;

    UPDATE journey SET status = 'COMPLETED' WHERE journey_id = @journey;
    UPDATE ticket SET status = 'COMPLETED' WHERE journey_id = @journey AND status = 'PAID';

    INSERT INTO loyalty_transaction (account_id, ticket_id, txn_type, points)
    SELECT a.account_id, t.ticket_id, 'EARNED', CAST(t.price / 100 AS INT)
    FROM ticket t
    JOIN booking b ON b.booking_id = t.booking_id
    JOIN loyalty_account a ON a.passenger_id = b.passenger_id
    WHERE t.journey_id = @journey AND t.status = 'COMPLETED' AND t.price >= 100
      AND NOT EXISTS (SELECT 1 FROM loyalty_transaction x
                      WHERE x.ticket_id = t.ticket_id AND x.txn_type = 'EARNED');

    -- Solde recalcule depuis l'historique (reste correct avec ou sans le trigger du point 27)
    UPDATE a
    SET points_balance = (SELECT COALESCE(SUM(points), 0) FROM loyalty_transaction lt WHERE lt.account_id = a.account_id)
    FROM loyalty_account a
    WHERE a.passenger_id IN (SELECT b.passenger_id
                             FROM ticket t JOIN booking b ON b.booking_id = t.booking_id
                             WHERE t.journey_id = @journey);

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- 5. Rollback quand l'insertion d'un billet echoue (siege inexistant => violation de FK)
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRAN;

    DECLARE @booking INT;
    INSERT INTO booking (passenger_id) VALUES (470);
    SET @booking = SCOPE_IDENTITY();

    INSERT INTO ticket (booking_id, journey_id, origin_station_id, dest_station_id, seat_id, travel_class, price)
    SELECT @booking, 85, o.station_id, d.station_id, 999999, 'SECOND', 15000
    FROM journey_stop o
    JOIN journey_stop d ON d.journey_id = o.journey_id AND d.stop_order = 6
    WHERE o.journey_id = 85 AND o.stop_order = 1;

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT('Transaction annulee : ', ERROR_MESSAGE());
END CATCH;
GO

-- Verification : la reservation du passager 470 n'existe pas (0 ligne)
SELECT * FROM booking WHERE passenger_id = 470;
