# 33. Final Deliverables

SGBD : SQL Server (T-SQL).

| Livrable | Fichier |
| --- | --- |
| Diagramme ER | [08_ER_Diagram.md](08_ER_Diagram.md) |
| Conception (entités, clés, relations) | [07_Database_Conception.md](07_Database_Conception.md) |
| Schéma logique et normalisation | [09_Relational_Schema_Normalisation.md](09_Relational_Schema_Normalisation.md) |
| Script `CREATE TABLE` et contraintes | [10_Constraints_Data_Integrity.sql](10_Constraints_Data_Integrity.sql) |
| Script de peuplement | [11_Data_Population.sql](11_Data_Population.sql) |
| Requêtes CRUD | [12_CRUD_Practice.sql](12_CRUD_Practice.sql) |
| Jointures | [13_Joins_Operational_Queries.sql](13_Joins_Operational_Queries.sql) |
| Agrégations | [14_Aggregation_BI.sql](14_Aggregation_BI.sql) |
| Analyse des segments | [15_Route_Segment_Analysis.sql](15_Route_Segment_Analysis.sql) |
| Sous-requêtes | [16_Subqueries.sql](16_Subqueries.sql) |
| `EXISTS` / `NOT EXISTS` | [17_Exists_Not_Exists.sql](17_Exists_Not_Exists.sql) |
| `CASE` | [18_Case_Expressions.sql](18_Case_Expressions.sql) |
| CTE | [19_CTEs.sql](19_CTEs.sql) |
| Fonctions de fenêtrage | [20_Window_Functions.sql](20_Window_Functions.sql) |
| Données temporelles | [21_Temporal_Data.sql](21_Temporal_Data.sql) |
| Requête récursive | [22_Recursive_Query.sql](22_Recursive_Query.sql) |
| Vues | [23_Views.sql](23_Views.sql) |
| Index et investigation des plans | [24_Indexing_Performance.sql](24_Indexing_Performance.sql) |
| Transactions | [25_Transactions.sql](25_Transactions.sql) |
| Concurrence (explication + procédure) | [26_Concurrency_Challenge.md](26_Concurrency_Challenge.md) |
| Triggers | [27_Triggers.sql](27_Triggers.sql) |
| Journal d'audit | [28_Audit_Log.sql](28_Audit_Log.sql) |
| Rôles et permissions | [29_Security_Roles.sql](29_Security_Roles.sql) |
| Audit de qualité des données | [30_Data_Quality_Audit.sql](30_Data_Quality_Audit.sql) |
| Rapport opérationnel | [31_Final_Operational_Challenge.sql](31_Final_Operational_Challenge.sql) |
| Requêtes du tableau de bord | [32_Reporting_Dashboard.sql](32_Reporting_Dashboard.sql) |
| Questions d'architecture | [34_Architecture_Questions.md](34_Architecture_Questions.md) |
| Défi final | [35_Final_Challenge.sql](35_Final_Challenge.sql) |

## Ordre d'exécution

1. `10` : base, tables, contraintes, vues utilitaires.
2. `11` : données (en un seul lot, avant les triggers).
3. `12` à `22` : requêtes, dans n'importe quel ordre.
4. `23` : vues de reporting (utilisées par `32` et `35`).
5. `24` : index.
6. `25`, puis la procédure du `26`.
7. `27`, `28` : triggers et audit.
8. `29` : rôles (nécessite la procédure du `26`).
9. `30`, `31`, `32`, `35` : audits et rapports.
