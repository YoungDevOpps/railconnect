# 7. Database Conception

SGBD cible : **SQL Server**. Modèle volontairement simple : 29 tables, clés techniques `INT IDENTITY`.

## 7.1 Entités et attributs

**PK en gras**, `#` = clé étrangère.

| Entité | Attributs |
| --- | --- |
| CITY | **city_id**, name, region |
| STATION | **station_id**, #city_id, code, name, is_active |
| RAILWAY_LINE | **line_id**, code, name, is_active |
| LINE_STATION | **(#line_id, stop_order)**, #station_id, distance_from_prev_km |
| TRAIN | **train_id**, code, model, status, maintenance_interval_days |
| CARRIAGE | **carriage_id**, #train_id, carriage_no, travel_class |
| SEAT | **seat_id**, #carriage_id, seat_no |
| JOURNEY | **journey_id**, #line_id, #train_id, service_date, status |
| JOURNEY_STOP | **(#journey_id, stop_order)**, #station_id, planned_arrival, planned_departure, actual_arrival, actual_departure, platform |
| PASSENGER | **passenger_id**, first_name, last_name, email, phone, category, created_at |
| PASSENGER_DOCUMENT | **document_id**, #passenger_id, doc_type, doc_number, expiry_date |
| BOOKING | **booking_id**, #passenger_id, booked_at, status, total_amount |
| TICKET | **ticket_id**, #booking_id, #journey_id, #origin_station_id, #dest_station_id, #seat_id, travel_class, price, status |
| PAYMENT | **payment_id**, #booking_id, amount, method, status, attempted_at, paid_at |
| REFUND | **refund_id**, #ticket_id, #payment_id, amount, reason, refunded_at |
| PRICING_RULE | **rule_id**, #line_id, travel_class, min_days_before, price_per_km, demand_factor, valid_from, valid_to |
| DISCOUNT | **discount_id**, code, discount_type, target, percent_off, valid_from, valid_to |
| TICKET_DISCOUNT | **(#ticket_id, #discount_id)**, amount |
| LOYALTY_ACCOUNT | **account_id**, #passenger_id, tier, points_balance, opened_at |
| LOYALTY_TRANSACTION | **transaction_id**, #account_id, #ticket_id, #reward_id, txn_type, points, created_at |
| REWARD | **reward_id**, name, points_cost, available_from, available_to |
| EMPLOYEE | **employee_id**, first_name, last_name, email, job_role, hired_on, is_active |
| DRIVER_LICENCE | **licence_id**, #employee_id, licence_number, issued_on, expires_on |
| JOURNEY_CREW | **(#journey_id, #employee_id)**, assigned_at |
| MAINTENANCE | **maintenance_id**, #train_id, maintenance_type, start_date, duration_days, cost, result |
| INCIDENT | **incident_id**, #train_id, #journey_id, severity, category, description, status, reported_at, resolved_at |
| DELAY | **delay_id**, #(journey_id, station_id), minutes, reason, recorded_at |
| CANCELLATION | **cancellation_id**, #journey_id, #ticket_id, reason, cancelled_at |
| AUDIT_LOG | **audit_id**, table_name, record_id, operation, changed_at, changed_by, old_values, new_values |

## 7.2 Clés

- **Clés primaires** : identifiant technique `IDENTITY` partout, sauf les tables d'association/ordonnées qui ont une clé composée naturelle (`LINE_STATION`, `JOURNEY_STOP`, `TICKET_DISCOUNT`, `JOURNEY_CREW`).
- **Clés candidates → clés alternatives (`UNIQUE`)** :

| Table | Clé alternative |
| --- | --- |
| CITY | (name, region) |
| STATION | code |
| RAILWAY_LINE | code |
| LINE_STATION | (line_id, station_id) |
| TRAIN | code |
| CARRIAGE | (train_id, carriage_no) |
| SEAT | (carriage_id, seat_no) |
| JOURNEY_STOP | (journey_id, station_id) |
| PASSENGER | email |
| PASSENGER_DOCUMENT | (doc_type, doc_number) |
| REFUND | ticket_id |
| DISCOUNT | code |
| LOYALTY_ACCOUNT | passenger_id |
| EMPLOYEE | email |
| DRIVER_LICENCE | licence_number |

- **Clés étrangères** : détaillées au point 9.

## 7.3 Relations

| Type | Relation |
| --- | --- |
| 1:1 | PASSENGER – LOYALTY_ACCOUNT ; TICKET – REFUND ; JOURNEY – CANCELLATION ; TICKET – CANCELLATION |
| 1:N | CITY→STATION ; TRAIN→CARRIAGE→SEAT ; RAILWAY_LINE→JOURNEY ; TRAIN→JOURNEY ; JOURNEY→JOURNEY_STOP ; PASSENGER→BOOKING→TICKET ; BOOKING→PAYMENT ; PAYMENT→REFUND ; SEAT→TICKET ; PASSENGER→PASSENGER_DOCUMENT ; RAILWAY_LINE→PRICING_RULE ; LOYALTY_ACCOUNT→LOYALTY_TRANSACTION ; EMPLOYEE→DRIVER_LICENCE ; TRAIN→MAINTENANCE ; TRAIN→INCIDENT ; JOURNEY_STOP→DELAY |
| N:N | RAILWAY_LINE – STATION ; JOURNEY – STATION ; TICKET – DISCOUNT ; JOURNEY – EMPLOYEE |

## 7.4 Participation (obligatoire / optionnelle)

| Relation | Côté obligatoire | Côté optionnel |
| --- | --- | --- |
| STATION → CITY | une gare a toujours une ville | une ville peut n'avoir aucune gare |
| CARRIAGE → TRAIN, SEAT → CARRIAGE | toujours rattaché | — |
| JOURNEY → LINE, TRAIN | obligatoires | une ligne/un train peut n'avoir aucun trajet |
| TICKET → BOOKING, JOURNEY_STOP (×2), SEAT | obligatoires | un siège peut n'avoir aucun billet |
| PAYMENT → BOOKING | obligatoire | une réservation peut n'avoir aucun paiement |
| REFUND → TICKET, PAYMENT | obligatoires | un billet n'a pas forcément de remboursement |
| LOYALTY_ACCOUNT → PASSENGER | obligatoire | un passager peut ne pas avoir de compte |
| LOYALTY_TRANSACTION → TICKET, REWARD | — | optionnels (`NULL`) |
| INCIDENT → TRAIN / JOURNEY | train obligatoire | trajet optionnel |
| CANCELLATION → JOURNEY / TICKET | exactement un des deux | l'autre est `NULL` |
| DRIVER_LICENCE → EMPLOYEE | obligatoire | seuls les `DRIVER` en ont |

## 7.5 Résolution des N:N

| Relation N:N | Table d'association | Attributs portés |
| --- | --- | --- |
| RAILWAY_LINE – STATION | LINE_STATION | stop_order, distance_from_prev_km |
| JOURNEY – STATION | JOURNEY_STOP | stop_order, horaires prévus/réels, platform |
| TICKET – DISCOUNT | TICKET_DISCOUNT | amount |
| JOURNEY – EMPLOYEE | JOURNEY_CREW | assigned_at |

## 7.6 Séquences ordonnées de gares

- `LINE_STATION(line_id, stop_order)` : `stop_order` = position de la gare sur la ligne, `distance_from_prev_km` = distance depuis la gare précédente.
- `JOURNEY_STOP(journey_id, stop_order)` : copie de l'ordre de la ligne au moment de la planification, avec les horaires.
- La PK `(parent, stop_order)` empêche deux gares à la même position ; `UNIQUE (parent, station_id)` empêche une gare en double.
- Un billet référence ses deux arrêts via `(journey_id, origin_station_id)` et `(journey_id, dest_station_id)` → `JOURNEY_STOP`. Segment occupé = `[origin_order, dest_order[`.
- Deux billets sur le même siège sont en conflit si `a.origin_order < b.dest_order AND b.origin_order < a.dest_order`.

## 7.7 Validité temporelle

| Donnée | Représentation |
| --- | --- |
| Règles tarifaires, remises | `valid_from`, `valid_to` (`NULL` = sans fin), `CHECK (valid_to > valid_from)` |
| Récompenses | `available_from`, `available_to` |
| Permis | `issued_on`, `expires_on` |
| Documents passager | `expiry_date` |
| Arrêts | `planned_*` / `actual_*` |
| Maintenance | `start_date` + `duration_days` |
| Événements | `booked_at`, `attempted_at`, `paid_at`, `refunded_at`, `cancelled_at`, `reported_at`, `resolved_at`, `changed_at` |

Règle « active à l'instant T » : `valid_from <= T AND (valid_to IS NULL OR valid_to > T)`.
