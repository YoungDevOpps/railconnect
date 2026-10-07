# 26. Concurrency Challenge

Deux utilisateurs veulent le dernier siège libre du même trajet au même instant.

## 26.1 La condition de course

Sans protection, sous `READ COMMITTED` (niveau par défaut de SQL Server) :

| Temps | Session A | Session B |
| --- | --- | --- |
| t1 | `SELECT` : le siège 12 est libre | |
| t2 | | `SELECT` : le siège 12 est libre |
| t3 | `INSERT ticket` (siège 12) | |
| t4 | | `INSERT ticket` (siège 12) |
| t5 | `COMMIT` | |
| t6 | | `COMMIT` → **siège vendu deux fois** |

Le problème : la vérification (t1/t2) et l'écriture (t3/t4) ne sont pas atomiques, et un `SELECT` simple ne pose aucun verrou durable. Aucune contrainte `UNIQUE` ne peut aider, car un même siège peut légitimement être vendu plusieurs fois sur des segments différents.

## 26.2 Stratégie retenue

- **Isolation** : `READ COMMITTED` conservé, complété par un **verrou pessimiste explicite** sur la ligne du siège.
- **Verrou** : `WITH (UPDLOCK, HOLDLOCK)` sur `seat`. `UPDLOCK` est exclusif entre deux lecteurs qui veulent écrire ; `HOLDLOCK` le conserve jusqu'à la fin de la transaction.
- **Séquence** : verrouiller le siège → vérifier le chevauchement → insérer → `COMMIT`.
- **Filet de sécurité** : le trigger `trg_ticket_seat_check` (point 27) refuse tout chevauchement, même si un programme contourne la procédure.

Alternative : `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE` (verrous d'intervalle sur `ticket`). Correct aussi, mais provoque plus de deadlocks car les deux sessions lisent d'abord en partagé puis veulent écrire.

```sql
USE RailConnect;
GO

CREATE OR ALTER PROCEDURE usp_book_seat
    @booking_id INT, @journey_id INT, @seat_id INT,
    @origin_station_id INT, @dest_station_id INT, @price DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @o INT, @d INT, @lock INT;

    SELECT @o = stop_order FROM journey_stop WHERE journey_id = @journey_id AND station_id = @origin_station_id;
    SELECT @d = stop_order FROM journey_stop WHERE journey_id = @journey_id AND station_id = @dest_station_id;

    IF @o IS NULL OR @d IS NULL OR @o >= @d
        THROW 50010, 'Segment invalide pour ce trajet', 1;

    BEGIN TRAN;

    -- Le second acheteur attend ici tant que le premier n'a pas termine
    SELECT @lock = seat_id FROM seat WITH (UPDLOCK, HOLDLOCK) WHERE seat_id = @seat_id;

    IF EXISTS (SELECT 1 FROM v_ticket_segment ts
               WHERE ts.journey_id = @journey_id AND ts.seat_id = @seat_id AND ts.status <> 'CANCELLED'
                 AND ts.origin_order < @d AND ts.dest_order > @o)
    BEGIN
        ROLLBACK;
        THROW 50011, 'Siege deja vendu sur ce segment', 1;
    END;

    INSERT INTO ticket (booking_id, journey_id, origin_station_id, dest_station_id, seat_id, travel_class, price)
    SELECT @booking_id, @journey_id, @origin_station_id, @dest_station_id, s.seat_id, c.travel_class, @price
    FROM seat s
    JOIN carriage c ON c.carriage_id = s.carriage_id
    WHERE s.seat_id = @seat_id;

    COMMIT;
END;
GO
```

Avec la procédure :

| Temps | Session A | Session B |
| --- | --- | --- |
| t1 | `BEGIN TRAN`, verrou U sur le siège 12 | |
| t2 | | `BEGIN TRAN`, demande le verrou → **bloquée** |
| t3 | vérifie : libre → `INSERT` → `COMMIT` | (attend) |
| t4 | | obtient le verrou, vérifie : **occupé** → `ROLLBACK`, erreur 50011 |

## 26.3 Blocage

- B n'échoue pas tout de suite : elle **attend** que A libère le verrou (au `COMMIT` ou `ROLLBACK`).
- L'attente est courte si la transaction est courte : aucun appel externe (paiement, e-mail) ne doit se trouver entre `BEGIN TRAN` et `COMMIT`.
- `SET LOCK_TIMEOUT 5000;` évite une attente infinie (erreur 1222 après 5 s).
- Le verrou porte sur une seule ligne `seat` : les ventes des autres sièges ne sont pas bloquées. (Il bloque aussi ce siège sur les autres trajets du même train ; `sp_getapplock` sur la clé `trajet-siège` serait plus fin.)

## 26.4 Deadlocks

- Cas type : A verrouille le siège 1 puis veut le 2 ; B verrouille le 2 puis veut le 1. SQL Server tue une des deux transactions (erreur **1205**).
- Prévention :
  - verrouiller les sièges **toujours dans le même ordre** (`seat_id` croissant) pour une réservation multi-billets ;
  - prendre directement `UPDLOCK` plutôt qu'un verrou partagé converti ensuite ;
  - transactions courtes, index `ix_ticket_seat_conflict` (point 24) pour ne verrouiller que les lignes utiles.
- Traitement : côté application, intercepter l'erreur 1205 et **rejouer** la transaction (2 ou 3 tentatives).

## 26.5 Pourquoi la validation applicative seule ne suffit pas

- Plusieurs serveurs ou processus applicatifs s'exécutent en parallèle : chacun « voit » le siège libre.
- Le temps entre la vérification et l'insertion existe toujours (*check-then-act*).
- D'autres accès contournent l'application : scripts, imports, outils d'administration, autre service.
- Seule la base voit toutes les transactions concurrentes : c'est elle qui doit sérialiser l'accès (verrou) et garantir la règle (trigger/contrainte).
