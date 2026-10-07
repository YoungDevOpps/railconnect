# Advanced SQL & DBMS — Practical Case Study

## RailConnect — National Railway Network

> **Difficulty:** 3× harder than a standard CRUD/database exercise

## Case Study

A complete real-world database conception and implementation exercise.

Analyse the business case, design the database, implement it, populate it with realistic data, and solve increasingly complex operational problems.

## Table of Contents

- [1. Business Context](#1-business-context)
- [2. Main Business Objects](#2-main-business-objects)
- [3. Core Requirements](#3-core-requirements)
- [4. Advanced Pricing and Loyalty](#4-advanced-pricing-and-loyalty)
- [5. Employees and Operations](#5-employees-and-operations)
- [6. Suggested Relational Model](#6-suggested-relational-model)
- [7. Database Conception](#7-database-conception)
- [8. ER Diagram](#8-er-diagram)
- [9. Relational Schema and Normalisation](#9-relational-schema-and-normalisation)
- [10. Constraints and Data Integrity](#10-constraints-and-data-integrity)
- [11. Realistic Data Population](#11-realistic-data-population)
- [12. CRUD Practice](#12-crud-practice)
- [13. Joins and Operational Queries](#13-joins-and-operational-queries)
- [14. Aggregation and BI](#14-aggregation-and-bi)
- [15. Complex Route and Segment Analysis](#15-complex-route-and-segment-analysis)
- [16. Subqueries](#16-subqueries)
- [17. EXISTS / NOT EXISTS](#17-exists--not-exists)
- [18. CASE Expressions](#18-case-expressions)
- [19. CTEs](#19-ctes)
- [20. Window Functions](#20-window-functions)
- [21. Temporal Data](#21-temporal-data)
- [22. Recursive Query](#22-recursive-query)
- [23. Views](#23-views)
- [24. Indexing and Performance](#24-indexing-and-performance)
- [25. Transactions](#25-transactions)
- [26. Concurrency Challenge](#26-concurrency-challenge)
- [27. Triggers](#27-triggers)
- [28. Audit Log](#28-audit-log)
- [29. Security and Roles](#29-security-and-roles)
- [30. Advanced Data-Quality Audit](#30-advanced-data-quality-audit)
- [31. Final Operational Challenge](#31-final-operational-challenge)
- [32. Final Reporting Dashboard](#32-final-reporting-dashboard)
- [33. Final Deliverables](#33-final-deliverables)
- [34. Final Architecture Questions](#34-final-architecture-questions)
- [35. Final Challenge](#35-final-challenge)

---

## 1. Business Context

RailConnect operates a national railway network. It manages stations, railway lines, trains, carriages, seats, scheduled journeys, passengers, tickets, payments, refunds, employees, maintenance, delays and cancellations.

The difficult part is that passengers travel between arbitrary stations on a journey. The same physical seat may therefore be sold to different passengers on non-overlapping journey segments.

## 2. Main Business Objects

- City and Station
- Railway Line and ordered Line Stations
- Train, Carriage and Seat
- Journey and ordered Journey Stops
- Passenger and Passenger Document
- Booking, Ticket, Payment and Refund
- Pricing Rule and Discount
- Loyalty Account, Transactions and Rewards
- Employee, Driver Licence and Journey Crew
- Maintenance, Incident, Delay and Cancellation
- Audit Log

## 3. Core Requirements

- A city may contain multiple stations. A station may belong to multiple railway lines.
- A railway line contains an ordered sequence of stations. Store the distance between consecutive stations where relevant.
- A train contains multiple carriages and each carriage contains numbered seats.
- A journey uses one train and has a service date, route, status and ordered journey stops.
- Each journey stop stores planned and actual arrival/departure times and optionally a platform.
- A passenger may make many bookings and a booking may contain multiple tickets.
- Each ticket stores journey, origin station, destination station, seat, class, price and status.
- A physical seat must **not** be sold to two passengers over overlapping journey segments.
- A booking can have multiple payment attempts. Only successful payments count as revenue.
- Refunds must be traceable to the original ticket/payment where appropriate.

## 4. Advanced Pricing and Loyalty

- Prices may depend on route, class, time before departure and demand.
- Pricing rules have effective start/end timestamps.
- Detect overlapping active pricing rules for the same conditions.
- Discounts may depend on passenger category, loyalty level or promotional code.
- Passengers earn points after eligible completed journeys.
- Points history records earned, spent, expired and adjusted points.
- Rewards have point costs and availability periods.

## 5. Employees and Operations

- Employees may be `DRIVER`, `CONDUCTOR`, `CONTROLLER`, `TECHNICIAN` or `ADMIN`.
- Drivers require valid licences.
- Journeys may have several crew members.
- Detect drivers with expired licences assigned to journeys.
- Detect overlapping employee assignments.
- Trains require maintenance at defined intervals.
- Maintenance records include type, date, duration, cost and result.
- Incidents include severity, category, description and resolution status.

## 6. Suggested Relational Model

- `CITY`
- `STATION`
- `RAILWAY_LINE`
- `LINE_STATION`
- `TRAIN`
- `CARRIAGE`
- `SEAT`
- `JOURNEY`
- `JOURNEY_STOP`
- `PASSENGER`
- `PASSENGER_DOCUMENT`
- `BOOKING`
- `TICKET`
- `PAYMENT`
- `REFUND`
- `PRICING_RULE`
- `DISCOUNT`
- `TICKET_DISCOUNT`
- `LOYALTY_ACCOUNT`
- `LOYALTY_TRANSACTION`
- `REWARD`
- `EMPLOYEE`
- `DRIVER_LICENCE`
- `JOURNEY_CREW`
- `MAINTENANCE`
- `INCIDENT`
- `DELAY`
- `CANCELLATION`
- `AUDIT_LOG`

## 7. Database Conception

- Identify entities and attributes.
- Choose primary, foreign, candidate and alternate keys.
- Identify one-to-one, one-to-many and many-to-many relationships.
- Identify optional and mandatory relationships.
- Resolve every many-to-many relationship.
- Represent ordered station sequences.
- Represent temporal validity.

## 8. ER Diagram

Create the complete ER diagram with cardinalities and participation constraints.

It must clearly show:

- How passengers buy tickets
- How tickets reference journey segments
- How journeys reference stations
- How trains are structured

## 9. Relational Schema and Normalisation

- Transform the conceptual model into tables.
- Apply 1NF, 2NF and 3NF.
- Identify partial and transitive dependencies.
- Document any deliberate denormalisation and justify it.
- Explain every foreign key.

## 10. Constraints and Data Integrity

- `PRIMARY KEY`
- `FOREIGN KEY`
- `UNIQUE`
- `NOT NULL`
- `CHECK` constraints
- Valid timestamp ordering
- Positive monetary amounts
- Valid journey origin/destination ordering
- Valid seat/carriage relationships
- Appropriate `ON DELETE` / `ON UPDATE` behaviour

## 11. Realistic Data Population

Create at least:

| Data                | Minimum |
| ------------------- | ------: |
| Cities              |      20 |
| Stations            |      35 |
| Railway lines       |       8 |
| Trains              |      15 |
| Carriages per train |       5 |
| Seats per train     |      40 |
| Journeys            |     100 |
| Passengers          |     500 |
| Tickets             |     800 |

Include:

- Multiple multi-ticket bookings
- Successful and failed payments
- Cancelled/refunded tickets
- Delays, incidents and maintenance records
- Loyalty transactions and rewards

## 12. CRUD Practice

- Create passengers, trains, carriages and seats.
- Create lines and ordered stations.
- Schedule journeys.
- Create bookings and tickets.
- Register payment attempts.
- Cancel tickets and create refunds.
- Update journey delays.
- Record maintenance and incidents.
- Assign crew.

## 13. Joins and Operational Queries

- List journeys with train, line, origin and destination.
- List passengers on a journey.
- Show train capacity.
- Show bookings with payment status.
- Find journeys passing through a station.
- Find tickets whose destination differs from the final journey station.
- Show journey crew.
- List trains maintained this year.
- Find passengers with both cancelled and completed tickets.
- Find stations served by multiple lines.

## 14. Aggregation and BI

- Revenue per journey, line and month.
- Average ticket price by class.
- Passengers per journey.
- Average occupancy per train.
- Busiest stations.
- Most profitable routes.
- Cancellation and refund rates.
- Average delay by station.
- Trains with highest incident count.
- Most-used seats.
- Loyalty points per passenger.
- Passengers spending above the average.

## 15. Complex Route and Segment Analysis

A ticket may cover only part of a journey. Passenger A may occupy a seat from Station A to D, while Passenger B uses that same seat from D to F.

- Determine origin/destination stop positions.
- Calculate travelled segments per ticket.
- Calculate occupancy for every journey segment.
- Find segments above 90% occupancy.
- Detect overlapping seat reservations.
- Find seats available on one segment but occupied on another.
- Detect capacity violations.
- Find repeated origin/destination pairs.

## 16. Subqueries

- Passengers spending above average.
- Trains with above-average maintenance cost.
- Journeys with above-line-average delay.
- Stations with above-average traffic.
- Passengers who never cancelled.
- Trains with no incidents.
- Employees above average journey count.
- Routes above average revenue.

## 17. EXISTS / NOT EXISTS

- Passengers with at least one successful payment.
- Passengers who never completed a journey.
- Trains with unresolved incidents.
- Trains with no required maintenance.
- Stations with cancelled journeys.
- Lines where every active station has been served.

## 18. CASE Expressions

- Classify journeys by delay severity.
- Classify passengers by annual spending.
- Classify trains by maintenance risk.
- Classify tickets by price.
- Classify stations by traffic.
- Classify refunds by cancellation timing.

## 19. CTEs

- Revenue CTE then journey ranking.
- Passenger spending CTE.
- Station traffic CTE.
- Delay statistics CTE.
- Segment occupancy CTE.
- Seat-conflict detection using CTEs.

## 20. Window Functions

- `ROW_NUMBER` by railway line.
- `RANK` passengers by spending.
- `DENSE_RANK` stations by traffic.
- `LAG` for consecutive journey delays.
- `LEAD` for consecutive station visits.
- `SUM() OVER` for cumulative spending.
- `AVG() OVER` for line comparisons.
- Rolling monthly revenue.
- Top three journeys per line.

## 21. Temporal Data

- Planned versus actual timestamps.
- Delay calculation.
- Pricing rules active at a timestamp.
- Overlapping pricing rules.
- Overlapping employee assignments.
- Maintenance/journey conflicts.
- Booking lead time.

## 22. Recursive Query

Use a recursive query to find stations reachable from a selected station through the network.

Prevent infinite loops and duplicate results.

## 23. Views

- `available_seats_by_journey`
- `journey_delay_summary`
- `passenger_spending_summary`
- `monthly_revenue`
- `train_maintenance_status`
- `station_traffic_summary`
- `segment_occupancy`
- `active_pricing_rules`

Explain whether each view should be dynamic or materialised.

## 24. Indexing and Performance

- Identify columns frequently used in `WHERE` conditions.
- Index foreign keys where appropriate.
- Create composite indexes for common searches.
- Design an index for seat-conflict checks.
- Design an index for journey/date/station searches.
- Compare plans before and after indexing.
- Use `EXPLAIN` or `EXPLAIN ANALYZE`.
- Identify redundant or expensive indexes.

## 25. Transactions

- Create booking and tickets atomically.
- Process successful payment and mark booking paid.
- Cancel ticket and create refund consistently.
- Award loyalty points after completion.
- Rollback when a ticket insertion fails.

## 26. Concurrency Challenge

Two users attempt to buy the final available seat at almost the same time.

Explain the race condition and implement a transaction strategy preventing double booking.

- Show the race-condition timeline.
- Choose an isolation strategy.
- Use locking or another safe mechanism.
- Explain blocking.
- Discuss deadlocks.
- Explain why application-only validation is insufficient.

## 27. Triggers

- Audit ticket status changes.
- Prevent invalid loyalty balance changes.
- Timestamp successful payments.
- Prevent scheduling during maintenance.
- Audit journey status changes.
- Reject invalid seat assignments.

## 28. Audit Log

Create an audit mechanism recording table, record identifier, operation, timestamp and relevant old/new values.

- Audit ticket changes.
- Audit payment changes.
- Audit cancellations.
- Audit pricing-rule changes.
- Audit crew changes.
- Query who changed what and when.

## 29. Security and Roles

- Read-only reporting role.
- Operational journey-management role.
- Ticketing role.
- Maintenance role.
- Restrict sensitive passenger information.
- Apply least privilege.
- Explain why application users should not receive unrestricted database access.

## 30. Advanced Data-Quality Audit

- Invalid ticket station ordering.
- Tickets referencing inactive stations.
- Incorrect journey-stop ordering.
- Seats assigned to multiple carriages.
- Overlapping seat reservations.
- Payment/booking amount mismatches.
- Excessive refunds.
- Expired-driver assignments.
- Train/journey maintenance conflicts.
- Impossible timestamps.
- Unexpected pricing overlap.
- `PAID` tickets without successful payment.
- Invalid loyalty balances.

## 31. Final Operational Challenge

Scenario:

> Operations asks whether train `RC-204` can safely operate Journey `#50231` tomorrow.

- Is the train active?
- Is it in maintenance?
- Does it have critical unresolved incidents?
- Is its configuration valid?
- Is capacity sufficient?
- Is the driver licensed?
- Does the crew have conflicts?
- Are there route/station restrictions?
- Are there cancellations or operational issues?
- Are delays expected?

Produce SQL queries supporting the final operational report.

## 32. Final Reporting Dashboard

- Total revenue.
- Monthly revenue.
- Revenue by line.
- Passenger count.
- Average ticket price.
- Average occupancy.
- Top journeys.
- Most-used stations.
- Cancellation rate.
- Refund rate.
- Average delay.
- Worst-delay stations.
- Maintenance cost.
- Incident statistics.
- Loyalty statistics.

## 33. Final Deliverables

- ER diagram.
- Logical schema.
- `CREATE TABLE` script.
- Constraints.
- Population script.
- CRUD queries.
- Joins.
- Aggregations.
- Subqueries.
- `EXISTS` / `NOT EXISTS`.
- `CASE`.
- CTEs.
- Window functions.
- Recursive query.
- Views.
- Indexes.
- `EXPLAIN` investigation.
- Transactions.
- Concurrency explanation.
- Triggers.
- Audit log.
- Roles/permissions.
- Data-quality audit.
- Operational report.
- Dashboard queries.

## 34. Final Architecture Questions

- Why these primary keys?
- Which relationships are many-to-many?
- Which attributes became separate tables?
- Where was normalisation applied?
- Was anything deliberately denormalised?
- Which constraints belong in the database?
- Which indexes are essential?
- Which queries will become expensive at scale?
- Where are transactions required?
- Where can concurrency occur?
- What must be audited?
- Which users need access to which data?
- Which views simplify reporting?
- Which information is temporal?
- How would the design change at millions of tickets per day?

## 35. Final Challenge

A major holiday is approaching. Demand is unusually high, several trains are near capacity, two trains require maintenance, and multiple journeys have experienced delays.

Using your database, identify:

- Operational risks
- Affected journeys
- Overloaded segments
- Possible seat conflicts
- Payment anomalies
- Crew conflicts
- Maintenance conflicts

Produce a concise SQL-based operational report for management.

> **Warning:** Do not solve the exercise by manually inspecting rows. The objective is to demonstrate database design, relational reasoning and SQL proficiency.
