# RailConnect — Réseau ferroviaire national

Étude de cas SQL avancé et SGBD (GoMyCode) : conception, implémentation et exploitation de la base de données d'un opérateur ferroviaire.

- **SGBD cible :** SQL Server (T-SQL)
- **Énoncé :** [rail_connect.md](rail_connect.md)
- **Modèle :** 29 tables, clés techniques `INT IDENTITY`, conception volontairement simple

## Le problème central

Un passager voyage entre deux gares quelconques d'un trajet. Un même siège physique peut donc être vendu plusieurs fois sur un même trajet, à condition que les segments ne se chevauchent pas (A → D, puis D → F).

Un billet occupe le segment *n* (tronçon entre l'arrêt *n* et l'arrêt *n+1*) si `origin_order <= n AND dest_order > n`. Cette règle sert à l'analyse d'occupation, à la détection des doubles ventes et à la réservation concurrente.

## Contenu

Un fichier par point de l'énoncé (7 à 35).

### Conception

| Point | Fichier | Contenu |
| --- | --- | --- |
| 7 | [07_Database_Conception.md](07_Database_Conception.md) | Entités, attributs, clés, relations |
| 8 | [08_ER_Diagram.md](08_ER_Diagram.md) | Diagramme ER avec cardinalités |
| 9 | [09_Relational_Schema_Normalisation.md](09_Relational_Schema_Normalisation.md) | Schéma logique, 1NF à 3NF, dénormalisations justifiées |

### Implémentation

| Point | Fichier | Contenu |
| --- | --- | --- |
| 10 | [10_Constraints_Data_Integrity.sql](10_Constraints_Data_Integrity.sql) | Base, `CREATE TABLE`, contraintes, vues utilitaires |
| 11 | [11_Data_Population.sql](11_Data_Population.sql) | Peuplement généré par formules |
| 12 | [12_CRUD_Practice.sql](12_CRUD_Practice.sql) | Opérations CRUD |

### Requêtes

| Point | Fichier | Contenu |
| --- | --- | --- |
| 13 | [13_Joins_Operational_Queries.sql](13_Joins_Operational_Queries.sql) | Jointures opérationnelles |
| 14 | [14_Aggregation_BI.sql](14_Aggregation_BI.sql) | Agrégations et indicateurs |
| 15 | [15_Route_Segment_Analysis.sql](15_Route_Segment_Analysis.sql) | Occupation par segment, conflits de sièges |
| 16 | [16_Subqueries.sql](16_Subqueries.sql) | Sous-requêtes |
| 17 | [17_Exists_Not_Exists.sql](17_Exists_Not_Exists.sql) | `EXISTS` / `NOT EXISTS` |
| 18 | [18_Case_Expressions.sql](18_Case_Expressions.sql) | Classifications avec `CASE` |
| 19 | [19_CTEs.sql](19_CTEs.sql) | CTE |
| 20 | [20_Window_Functions.sql](20_Window_Functions.sql) | Fonctions de fenêtrage |
| 21 | [21_Temporal_Data.sql](21_Temporal_Data.sql) | Retards, chevauchements d'intervalles |
| 22 | [22_Recursive_Query.sql](22_Recursive_Query.sql) | Gares atteignables (CTE récursive) |

### Objets et administration

| Point | Fichier | Contenu |
| --- | --- | --- |
| 23 | [23_Views.sql](23_Views.sql) | 8 vues de reporting |
| 24 | [24_Indexing_Performance.sql](24_Indexing_Performance.sql) | Index et plans d'exécution |
| 25 | [25_Transactions.sql](25_Transactions.sql) | Transactions atomiques |
| 26 | [26_Concurrency_Challenge.md](26_Concurrency_Challenge.md) | Double réservation, procédure `usp_book_seat` |
| 27 | [27_Triggers.sql](27_Triggers.sql) | Triggers métier |
| 28 | [28_Audit_Log.sql](28_Audit_Log.sql) | Journal d'audit (anciennes/nouvelles valeurs en JSON) |
| 29 | [29_Security_Roles.sql](29_Security_Roles.sql) | 4 rôles, moindre privilège |

### Audits et rapports

| Point | Fichier | Contenu |
| --- | --- | --- |
| 30 | [30_Data_Quality_Audit.sql](30_Data_Quality_Audit.sql) | Contrôles de qualité (0 ligne = conforme) |
| 31 | [31_Final_Operational_Challenge.sql](31_Final_Operational_Challenge.sql) | Rapport GO / NO-GO : train `RC-204`, trajet `#50231` |
| 32 | [32_Reporting_Dashboard.sql](32_Reporting_Dashboard.sql) | Requêtes du tableau de bord |
| 33 | [33_Final_Deliverables.md](33_Final_Deliverables.md) | Liste des livrables |
| 34 | [34_Architecture_Questions.md](34_Architecture_Questions.md) | Questions d'architecture |
| 35 | [35_Final_Challenge.sql](35_Final_Challenge.sql) | Rapport opérationnel avant un jour férié |

## Exécution

Prérequis : SQL Server et un client (SSMS ou `sqlcmd`). Le fichier `10` crée la base `RailConnect`.

Respecter cet ordre :

1. `10` : base, tables, contraintes, vues utilitaires.
2. `11` : données, en un seul lot, sur des tables vides et avant les triggers.
3. `12` à `22` : requêtes, dans n'importe quel ordre.
4. `23` : vues de reporting (utilisées par `32` et `35`).
5. `24` : index.
6. `25`, puis la procédure du `26`.
7. `27`, `28` : triggers et audit.
8. `29` : rôles (nécessite la procédure du `26`).
9. `30`, `31`, `32`, `35` : audits et rapports.

Avec `sqlcmd` :

```
sqlcmd -S localhost -E -i 10_Constraints_Data_Integrity.sql
sqlcmd -S localhost -E -i 11_Data_Population.sql
```

## Jeu de données

| Donnée | Volume |
| --- | ---: |
| Villes | 20 |
| Gares | 35 |
| Lignes | 8 (6 gares chacune) |
| Trains | 15 (`RC-201` à `RC-215`), 5 voitures et 40 sièges chacun |
| Trajets | 100, plus le trajet `#50231` du scénario final |
| Passagers | 500 |
| Réservations | 736 |
| Billets | 936 |
| Employés | 40 |

Les dates sont relatives au jour d'exécution : les trajets s'étalent de J-79 à J+20.

Le peuplement contient des anomalies volontaires pour que les audits des points 30 et 35 renvoient des lignes : double vente d'un siège, permis de conducteur expiré, conflit d'équipage, maintenance planifiée le jour d'un trajet, règle tarifaire en chevauchement, billet `PAID` sans paiement réussi, remboursement excessif, solde de fidélité faux.

## Auteur

Ibrahim Tangara — GoMyCode
