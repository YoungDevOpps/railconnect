# 34. Final Architecture Questions

**1. Pourquoi ces clés primaires ?**
Clés techniques `INT IDENTITY` : stables, courtes, rapides en jointure, indépendantes des données métier (un code de gare ou un e-mail peut changer). Les codes métier restent protégés par `UNIQUE`. Clés composées naturelles seulement pour les tables d'association ou ordonnées (`LINE_STATION`, `JOURNEY_STOP`, `JOURNEY_CREW`, `TICKET_DISCOUNT`), où elles garantissent directement la règle (« une seule gare par position »).

**2. Quelles relations sont N:N ?**
Ligne–Gare (`LINE_STATION`), Trajet–Gare (`JOURNEY_STOP`), Billet–Remise (`TICKET_DISCOUNT`), Trajet–Employé (`JOURNEY_CREW`).

**3. Quels attributs sont devenus des tables ?**
Ville d'une gare (`CITY`), documents du passager (`PASSENGER_DOCUMENT`), permis du conducteur (`DRIVER_LICENCE`), tentatives de paiement (`PAYMENT`), remboursement (`REFUND`), historique des points (`LOYALTY_TRANSACTION`), retards (`DELAY`), annulations (`CANCELLATION`).

**4. Où la normalisation a-t-elle été appliquée ?**
1NF : listes de gares, arrêts, sièges en lignes. 2NF : rien dans une table à clé composée ne dépend d'une partie de la clé. 3NF : pas de `train_id` dans `SEAT`, pas de `passenger_id` dans `TICKET`, pas de nom de ville dans `STATION`. Détail au point 9.

**5. Y a-t-il une dénormalisation volontaire ?**
Oui : `BOOKING.total_amount`, `LOYALTY_ACCOUNT.points_balance`, `TICKET.travel_class`, `TICKET.price`, `DELAY.minutes`. Raisons : lecture rapide et conservation de la valeur historique. Chacune est contrôlée par trigger ou par l'audit qualité.

**6. Quelles contraintes appartiennent à la base ?**
Tout ce qui doit être vrai quel que soit le programme : PK, FK, `UNIQUE`, `NOT NULL`, `CHECK` (montants positifs, ordre des dates, listes de statuts), FK composées billet → arrêt, et par trigger : non-chevauchement des sièges, siège du bon train, ordre origine/destination, pas de trajet pendant une maintenance. Restent dans l'application : calcul du prix, règles commerciales changeantes, présentation.

**7. Quels index sont essentiels ?**
`ticket(journey_id, seat_id)` pour le contrôle de conflit, `ticket(booking_id)`, `booking(passenger_id)`, `payment(booking_id, status)`, `journey(service_date, line_id)`, `journey(train_id, service_date)`, `journey_stop(station_id, planned_departure)`, `journey_crew(employee_id)`, `maintenance(train_id, start_date)`.

**8. Quelles requêtes deviendront coûteuses à grande échelle ?**
L'occupation par segment (croisement arrêts × billets), la détection de chevauchements (auto-jointure sur `ticket`), les agrégats sur tout l'historique (revenu, dépenses par passager), les fenêtres sur les paiements, la requête récursive sur un grand réseau, et toute lecture de `audit_log`.

**9. Où les transactions sont-elles nécessaires ?**
Réservation + billets ; paiement + passage en `PAID` ; annulation + remboursement ; clôture de trajet + points de fidélité ; planification d'un trajet + ses arrêts ; dépense de points + récompense.

**10. Où la concurrence peut-elle se produire ?**
Vente du même siège, double paiement d'une réservation, deux mises à jour du même solde de points, affectation du même employé ou du même train à deux trajets, double remboursement d'un billet.

**11. Que faut-il auditer ?**
Billets (statut, prix, siège), paiements, remboursements et annulations, règles tarifaires, équipages, statuts des trajets, et les changements de droits.

**12. Quels utilisateurs accèdent à quelles données ?**

| Rôle | Accès |
| --- | --- |
| `rc_reporting` | lecture seule, sans e-mail, téléphone, documents ni audit |
| `rc_operations` | trajets, arrêts, équipages, retards, incidents, annulations |
| `rc_ticketing` | passagers, réservations, billets, paiements, remboursements, fidélité |
| `rc_maintenance` | trains, maintenances, incidents |
| administrateur | schéma, rôles, journal d'audit |

**13. Quelles vues simplifient le reporting ?**
`v_paid_ticket`, `v_ticket_segment`, `v_train_capacity`, puis `monthly_revenue`, `passenger_spending_summary`, `journey_delay_summary`, `station_traffic_summary`, `segment_occupancy`, `available_seats_by_journey`, `train_maintenance_status`, `active_pricing_rules`.

**14. Quelles informations sont temporelles ?**
Horaires prévus/réels des arrêts, validité des règles tarifaires, remises et récompenses, permis et documents, périodes de maintenance, et tous les horodatages d'événements (réservation, paiement, remboursement, annulation, incident, audit).

**15. Que changer pour des millions de billets par jour ?**

- **Partitionner** `ticket`, `payment`, `journey_stop`, `audit_log` par date ; archiver l'historique.
- Stocker `origin_order` / `dest_order` dans `ticket` pour éviter deux jointures à chaque contrôle de siège.
- Table d'**inventaire** `(journey_id, seat_id, segment_no)` avec `UNIQUE` : la double vente devient impossible par simple contrainte, sans trigger ni verrou long.
- Clés `BIGINT` ; séparer lecture et écriture (réplicas en lecture seule pour le reporting).
- Agrégats pré-calculés (vues indexées, tables de synthèse, entrepôt de données / columnstore) au lieu de requêtes sur les tables transactionnelles.
- Audit asynchrone (CDC ou file de messages) au lieu de triggers synchrones.
- Cache pour les données de référence (gares, lignes, tarifs) et réservation temporaire de siège avec expiration pendant le paiement.
