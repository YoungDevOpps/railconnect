-- 29. Security and Roles (SQL Server)
-- Moindre privilege : chaque role ne recoit que les droits necessaires a son metier.
-- Prerequis : procedure usp_book_seat (point 26). En T-SQL, un GRANT porte sur un seul objet.
USE RailConnect;
GO

CREATE ROLE rc_reporting;
CREATE ROLE rc_operations;
CREATE ROLE rc_ticketing;
CREATE ROLE rc_maintenance;
GO

-- Vue sans donnees sensibles (pas d'e-mail, de telephone ni de document)
CREATE OR ALTER VIEW v_passenger_public AS
SELECT passenger_id, first_name, LEFT(last_name, 1) + '.' AS last_name_initial, category, created_at
FROM passenger;
GO

-- 1. Reporting : lecture seule, sans les donnees personnelles
GRANT SELECT ON SCHEMA::dbo TO rc_reporting;
DENY SELECT ON OBJECT::dbo.passenger (email, phone) TO rc_reporting;
DENY SELECT ON OBJECT::dbo.passenger_document TO rc_reporting;
DENY SELECT ON OBJECT::dbo.audit_log TO rc_reporting;

-- 2. Exploitation : gestion des trajets, arrets, equipages, retards, annulations, incidents
GRANT SELECT ON station        TO rc_operations;
GRANT SELECT ON railway_line   TO rc_operations;
GRANT SELECT ON line_station   TO rc_operations;
GRANT SELECT ON train          TO rc_operations;
GRANT SELECT ON carriage       TO rc_operations;
GRANT SELECT ON seat           TO rc_operations;
GRANT SELECT ON employee       TO rc_operations;
GRANT SELECT ON driver_licence TO rc_operations;
GRANT SELECT ON maintenance    TO rc_operations;
GRANT SELECT, INSERT, UPDATE ON journey      TO rc_operations;
GRANT SELECT, INSERT, UPDATE ON journey_stop TO rc_operations;
GRANT SELECT, INSERT, UPDATE ON delay        TO rc_operations;
GRANT SELECT, INSERT, UPDATE ON incident     TO rc_operations;
GRANT SELECT, INSERT, DELETE ON journey_crew TO rc_operations;
GRANT SELECT, INSERT         ON cancellation TO rc_operations;

-- 3. Billetterie : passagers, reservations, billets, paiements, remboursements, fidelite
GRANT SELECT ON station          TO rc_ticketing;
GRANT SELECT ON railway_line     TO rc_ticketing;
GRANT SELECT ON line_station     TO rc_ticketing;
GRANT SELECT ON carriage         TO rc_ticketing;
GRANT SELECT ON seat             TO rc_ticketing;
GRANT SELECT ON journey          TO rc_ticketing;
GRANT SELECT ON journey_stop     TO rc_ticketing;
GRANT SELECT ON pricing_rule     TO rc_ticketing;
GRANT SELECT ON discount         TO rc_ticketing;
GRANT SELECT ON reward           TO rc_ticketing;
GRANT SELECT ON loyalty_account  TO rc_ticketing;
GRANT SELECT ON v_ticket_segment TO rc_ticketing;
GRANT SELECT ON v_train_capacity TO rc_ticketing;
GRANT SELECT, INSERT, UPDATE ON passenger          TO rc_ticketing;
GRANT SELECT, INSERT, UPDATE ON passenger_document TO rc_ticketing;
GRANT SELECT, INSERT, UPDATE ON booking            TO rc_ticketing;
GRANT SELECT, INSERT, UPDATE ON ticket             TO rc_ticketing;
GRANT SELECT, INSERT ON payment             TO rc_ticketing;
GRANT SELECT, INSERT ON refund              TO rc_ticketing;
GRANT SELECT, INSERT ON cancellation        TO rc_ticketing;
GRANT SELECT, INSERT ON ticket_discount     TO rc_ticketing;
GRANT SELECT, INSERT ON loyalty_transaction TO rc_ticketing;
GRANT EXECUTE ON usp_book_seat TO rc_ticketing;

-- 4. Maintenance : trains, maintenances, incidents ; aucun acces aux passagers ni aux paiements
GRANT SELECT ON train    TO rc_maintenance;
GRANT SELECT ON carriage TO rc_maintenance;
GRANT SELECT ON seat     TO rc_maintenance;
GRANT SELECT ON journey  TO rc_maintenance;
GRANT SELECT, INSERT, UPDATE ON maintenance TO rc_maintenance;
GRANT SELECT, INSERT, UPDATE ON incident    TO rc_maintenance;
GRANT UPDATE ON train (status) TO rc_maintenance;

-- Personne (hors administrateurs) ne peut modifier ni supprimer le journal d'audit
DENY UPDATE, DELETE ON audit_log TO rc_reporting, rc_operations, rc_ticketing, rc_maintenance;
GO

-- Utilisateurs applicatifs rattaches aux roles
CREATE USER report_user WITHOUT LOGIN;
CREATE USER ops_user WITHOUT LOGIN;
CREATE USER ticket_app WITHOUT LOGIN;
CREATE USER maint_user WITHOUT LOGIN;

ALTER ROLE rc_reporting ADD MEMBER report_user;
ALTER ROLE rc_operations ADD MEMBER ops_user;
ALTER ROLE rc_ticketing ADD MEMBER ticket_app;
ALTER ROLE rc_maintenance ADD MEMBER maint_user;
GO

-- Verification
EXECUTE AS USER = 'report_user';
    SELECT TOP 5 * FROM v_passenger_public;              -- autorise
    SELECT TOP 5 passenger_id, category FROM passenger;  -- autorise (colonnes non sensibles)
    -- SELECT email FROM passenger;                      -- refuse
    -- DELETE FROM ticket;                               -- refuse
REVERT;
GO

SELECT pr.name AS role_name, pe.permission_name, pe.state_desc, OBJECT_NAME(pe.major_id) AS object_name
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name LIKE 'rc[_]%'
ORDER BY pr.name, object_name;

-- Pourquoi l'application ne doit pas avoir un acces illimite (db_owner / sa) :
--   * une injection SQL ou un bug ne peut faire que ce que le compte a le droit de faire ;
--   * un compte vole ne permet ni de lire les donnees personnelles, ni de supprimer des tables ;
--   * les regles metier ne sont pas contournables (pas de DELETE sur payment, pas d'UPDATE sur audit_log) ;
--   * chaque action reste tracable par compte (changed_by dans audit_log) ;
--   * conformite : acces aux donnees personnelles limite a ceux qui en ont besoin.
