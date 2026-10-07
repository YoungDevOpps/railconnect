# 9. Relational Schema and Normalisation

## 9.1 Schéma relationnel

PK soulignée par `_.._`, `#` = clé étrangère.

```
CITY(_city_id_, name, region)
STATION(_station_id_, #city_id, code, name, is_active)
RAILWAY_LINE(_line_id_, code, name, is_active)
LINE_STATION(_#line_id, stop_order_, #station_id, distance_from_prev_km)
TRAIN(_train_id_, code, model, status, maintenance_interval_days)
CARRIAGE(_carriage_id_, #train_id, carriage_no, travel_class)
SEAT(_seat_id_, #carriage_id, seat_no)
JOURNEY(_journey_id_, #line_id, #train_id, service_date, status)
JOURNEY_STOP(_#journey_id, stop_order_, #station_id, planned_arrival, planned_departure,
             actual_arrival, actual_departure, platform)
PASSENGER(_passenger_id_, first_name, last_name, email, phone, category, created_at)
PASSENGER_DOCUMENT(_document_id_, #passenger_id, doc_type, doc_number, expiry_date)
BOOKING(_booking_id_, #passenger_id, booked_at, status, total_amount)
TICKET(_ticket_id_, #booking_id, #journey_id, #origin_station_id, #dest_station_id,
       #seat_id, travel_class, price, status)
PAYMENT(_payment_id_, #booking_id, amount, method, status, attempted_at, paid_at)
REFUND(_refund_id_, #ticket_id, #payment_id, amount, reason, refunded_at)
PRICING_RULE(_rule_id_, #line_id, travel_class, min_days_before, price_per_km,
             demand_factor, valid_from, valid_to)
DISCOUNT(_discount_id_, code, discount_type, target, percent_off, valid_from, valid_to)
TICKET_DISCOUNT(_#ticket_id, #discount_id_, amount)
LOYALTY_ACCOUNT(_account_id_, #passenger_id, tier, points_balance, opened_at)
LOYALTY_TRANSACTION(_transaction_id_, #account_id, #ticket_id, #reward_id, txn_type, points, created_at)
REWARD(_reward_id_, name, points_cost, available_from, available_to)
EMPLOYEE(_employee_id_, first_name, last_name, email, job_role, hired_on, is_active)
DRIVER_LICENCE(_licence_id_, #employee_id, licence_number, issued_on, expires_on)
JOURNEY_CREW(_#journey_id, #employee_id_, assigned_at)
MAINTENANCE(_maintenance_id_, #train_id, maintenance_type, start_date, duration_days, cost, result)
INCIDENT(_incident_id_, #train_id, #journey_id, severity, category, description, status,
         reported_at, resolved_at)
DELAY(_delay_id_, #(journey_id, station_id), minutes, reason, recorded_at)
CANCELLATION(_cancellation_id_, #journey_id, #ticket_id, reason, cancelled_at)
AUDIT_LOG(_audit_id_, table_name, record_id, operation, changed_at, changed_by, old_values, new_values)
```

## 9.2 Normalisation

**1NF — valeurs atomiques, pas de groupes répétitifs**

- La liste des gares d'une ligne → lignes de `LINE_STATION` (pas de colonnes `station1, station2…`).
- Les arrêts d'un trajet → `JOURNEY_STOP` ; les voitures et sièges → `CARRIAGE`, `SEAT`.
- Plusieurs documents, paiements, remises → `PASSENGER_DOCUMENT`, `PAYMENT`, `TICKET_DISCOUNT`.

**2NF — pas de dépendance partielle sur une clé composée**

| Dépendance partielle évitée | Solution |
| --- | --- |
| `(line_id, stop_order) → line_name` (dépend de `line_id` seul) | `name` reste dans `RAILWAY_LINE` |
| `(journey_id, stop_order) → service_date, train_id` (dépend de `journey_id` seul) | restent dans `JOURNEY` |
| `(journey_id, employee_id) → job_role` (dépend de `employee_id` seul) | reste dans `EMPLOYEE` |
| `(ticket_id, discount_id) → percent_off` (dépend de `discount_id` seul) | reste dans `DISCOUNT` |

**3NF — pas de dépendance transitive**

| Dépendance transitive évitée | Solution |
| --- | --- |
| `station_id → city_id → city_name, region` | table `CITY` |
| `seat_id → carriage_id → train_id` | `SEAT` ne stocke pas `train_id` |
| `ticket_id → booking_id → passenger_id` | `TICKET` ne stocke pas `passenger_id` |
| `journey_id → train_id → train_code, model` | restent dans `TRAIN` |
| `refund_id → ticket_id → booking_id` | `REFUND` ne stocke pas `booking_id` |
| `employee_id → licence_number, expires_on` (seulement pour les conducteurs) | table `DRIVER_LICENCE` |

## 9.3 Dénormalisations volontaires

| Colonne | Dérivable depuis | Justification |
| --- | --- | --- |
| `BOOKING.total_amount` | `SUM(TICKET.price)` | Montant attendu au paiement, lu très souvent ; contrôlé par l'audit qualité (point 30). |
| `LOYALTY_ACCOUNT.points_balance` | `SUM(LOYALTY_TRANSACTION.points)` | Lecture instantanée du solde ; maintenu par trigger (point 27). |
| `TICKET.travel_class` | `SEAT → CARRIAGE.travel_class` | Classe vendue figée même si la voiture est reconfigurée. |
| `TICKET.price` | règle tarifaire + remises | Prix historique : ne doit pas changer quand les règles changent. |
| `DELAY.minutes` | `actual_arrival − planned_arrival` | Retard déclaré avec sa cause, indépendant d'une correction d'horaire. |

## 9.4 Clés étrangères

| FK | Référence | Rôle |
| --- | --- | --- |
| STATION.city_id | CITY | ville de la gare |
| LINE_STATION.line_id | RAILWAY_LINE | ligne desservie |
| LINE_STATION.station_id | STATION | gare à cette position |
| CARRIAGE.train_id | TRAIN | train de la voiture |
| SEAT.carriage_id | CARRIAGE | voiture du siège |
| JOURNEY.line_id | RAILWAY_LINE | itinéraire du trajet |
| JOURNEY.train_id | TRAIN | train qui assure le trajet |
| JOURNEY_STOP.journey_id | JOURNEY | trajet de l'arrêt |
| JOURNEY_STOP.station_id | STATION | gare de l'arrêt |
| PASSENGER_DOCUMENT.passenger_id | PASSENGER | titulaire du document |
| BOOKING.passenger_id | PASSENGER | acheteur |
| TICKET.booking_id | BOOKING | réservation contenant le billet |
| TICKET.(journey_id, origin_station_id) | JOURNEY_STOP | arrêt de montée (doit exister sur ce trajet) |
| TICKET.(journey_id, dest_station_id) | JOURNEY_STOP | arrêt de descente (doit exister sur ce trajet) |
| TICKET.seat_id | SEAT | siège physique |
| PAYMENT.booking_id | BOOKING | réservation payée |
| REFUND.ticket_id | TICKET | billet remboursé |
| REFUND.payment_id | PAYMENT | paiement d'origine (traçabilité) |
| PRICING_RULE.line_id | RAILWAY_LINE | ligne tarifée |
| TICKET_DISCOUNT.ticket_id | TICKET | billet remisé |
| TICKET_DISCOUNT.discount_id | DISCOUNT | remise appliquée |
| LOYALTY_ACCOUNT.passenger_id | PASSENGER | titulaire du compte |
| LOYALTY_TRANSACTION.account_id | LOYALTY_ACCOUNT | compte mouvementé |
| LOYALTY_TRANSACTION.ticket_id | TICKET | billet à l'origine des points (optionnel) |
| LOYALTY_TRANSACTION.reward_id | REWARD | récompense consommée (optionnel) |
| DRIVER_LICENCE.employee_id | EMPLOYEE | conducteur titulaire |
| JOURNEY_CREW.journey_id | JOURNEY | trajet |
| JOURNEY_CREW.employee_id | EMPLOYEE | membre d'équipage |
| MAINTENANCE.train_id | TRAIN | train entretenu |
| INCIDENT.train_id | TRAIN | train concerné |
| INCIDENT.journey_id | JOURNEY | trajet concerné (optionnel) |
| DELAY.(journey_id, station_id) | JOURNEY_STOP | arrêt en retard |
| CANCELLATION.journey_id | JOURNEY | trajet annulé (ou) |
| CANCELLATION.ticket_id | TICKET | billet annulé |
