-- 10. Constraints and Data Integrity (SQL Server) : script CREATE TABLE complet
-- Les PK sont des IDENTITY (non modifiables) : ON UPDATE reste donc NO ACTION partout.
-- ON DELETE CASCADE uniquement parent -> composant ; NO ACTION (defaut) pour proteger l'historique.

CREATE DATABASE RailConnect;
GO
USE RailConnect;
GO

CREATE TABLE city (
    city_id INT IDENTITY PRIMARY KEY,
    name    VARCHAR(80) NOT NULL,
    region  VARCHAR(80) NOT NULL,
    CONSTRAINT uq_city UNIQUE (name, region)
);

CREATE TABLE station (
    station_id INT IDENTITY PRIMARY KEY,
    city_id    INT NOT NULL REFERENCES city (city_id),
    code       VARCHAR(10) NOT NULL UNIQUE,
    name       VARCHAR(100) NOT NULL,
    is_active  BIT NOT NULL DEFAULT 1
);

CREATE TABLE railway_line (
    line_id   INT IDENTITY PRIMARY KEY,
    code      VARCHAR(10) NOT NULL UNIQUE,
    name      VARCHAR(100) NOT NULL,
    is_active BIT NOT NULL DEFAULT 1
);

CREATE TABLE line_station (
    line_id               INT NOT NULL REFERENCES railway_line (line_id) ON DELETE CASCADE,
    stop_order            INT NOT NULL CHECK (stop_order > 0),
    station_id            INT NOT NULL REFERENCES station (station_id),
    distance_from_prev_km DECIMAL(6,1) NOT NULL DEFAULT 0 CHECK (distance_from_prev_km >= 0),
    PRIMARY KEY (line_id, stop_order),
    CONSTRAINT uq_line_station UNIQUE (line_id, station_id)
);

CREATE TABLE train (
    train_id                  INT IDENTITY PRIMARY KEY,
    code                      VARCHAR(10) NOT NULL UNIQUE,
    model                     VARCHAR(50) NOT NULL,
    status                    VARCHAR(15) NOT NULL DEFAULT 'ACTIVE'
                              CHECK (status IN ('ACTIVE', 'MAINTENANCE', 'RETIRED')),
    maintenance_interval_days INT NOT NULL DEFAULT 90 CHECK (maintenance_interval_days > 0)
);

CREATE TABLE carriage (
    carriage_id  INT IDENTITY PRIMARY KEY,
    train_id     INT NOT NULL REFERENCES train (train_id) ON DELETE CASCADE,
    carriage_no  INT NOT NULL CHECK (carriage_no > 0),
    travel_class VARCHAR(10) NOT NULL CHECK (travel_class IN ('FIRST', 'SECOND')),
    CONSTRAINT uq_carriage UNIQUE (train_id, carriage_no)
);

-- Un siege appartient a une seule voiture (FK NOT NULL) et son numero y est unique.
CREATE TABLE seat (
    seat_id     INT IDENTITY PRIMARY KEY,
    carriage_id INT NOT NULL REFERENCES carriage (carriage_id) ON DELETE CASCADE,
    seat_no     INT NOT NULL CHECK (seat_no > 0),
    CONSTRAINT uq_seat UNIQUE (carriage_id, seat_no)
);

CREATE TABLE journey (
    journey_id   INT IDENTITY PRIMARY KEY,
    line_id      INT NOT NULL REFERENCES railway_line (line_id),
    train_id     INT NOT NULL REFERENCES train (train_id),
    service_date DATE NOT NULL,
    status       VARCHAR(15) NOT NULL DEFAULT 'SCHEDULED'
                 CHECK (status IN ('SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'))
);

CREATE TABLE journey_stop (
    journey_id        INT NOT NULL REFERENCES journey (journey_id) ON DELETE CASCADE,
    stop_order        INT NOT NULL CHECK (stop_order > 0),
    station_id        INT NOT NULL REFERENCES station (station_id),
    planned_arrival   DATETIME2(0) NOT NULL,
    planned_departure DATETIME2(0) NOT NULL,
    actual_arrival    DATETIME2(0) NULL,
    actual_departure  DATETIME2(0) NULL,
    platform          VARCHAR(5) NULL,
    PRIMARY KEY (journey_id, stop_order),
    CONSTRAINT uq_journey_stop_station UNIQUE (journey_id, station_id),
    CONSTRAINT ck_stop_planned CHECK (planned_departure >= planned_arrival),
    CONSTRAINT ck_stop_actual  CHECK (actual_departure >= actual_arrival)
);

CREATE TABLE passenger (
    passenger_id INT IDENTITY PRIMARY KEY,
    first_name   VARCHAR(50) NOT NULL,
    last_name    VARCHAR(50) NOT NULL,
    email        VARCHAR(120) NOT NULL UNIQUE,
    phone        VARCHAR(20) NULL,
    category     VARCHAR(10) NOT NULL DEFAULT 'ADULT'
                 CHECK (category IN ('ADULT', 'CHILD', 'STUDENT', 'SENIOR')),
    created_at   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE passenger_document (
    document_id  INT IDENTITY PRIMARY KEY,
    passenger_id INT NOT NULL REFERENCES passenger (passenger_id) ON DELETE CASCADE,
    doc_type     VARCHAR(10) NOT NULL CHECK (doc_type IN ('ID_CARD', 'PASSPORT')),
    doc_number   VARCHAR(30) NOT NULL,
    expiry_date  DATE NOT NULL,
    CONSTRAINT uq_document UNIQUE (doc_type, doc_number)
);

CREATE TABLE booking (
    booking_id   INT IDENTITY PRIMARY KEY,
    passenger_id INT NOT NULL REFERENCES passenger (passenger_id),
    booked_at    DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    status       VARCHAR(10) NOT NULL DEFAULT 'PENDING'
                 CHECK (status IN ('PENDING', 'PAID', 'CANCELLED')),
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0)
);

-- Les deux FK composees garantissent que origine et destination sont des arrets du trajet.
-- L'ordre origine < destination et le non-chevauchement des sieges sont verifies par trigger (point 27).
CREATE TABLE ticket (
    ticket_id         INT IDENTITY PRIMARY KEY,
    booking_id        INT NOT NULL REFERENCES booking (booking_id),
    journey_id        INT NOT NULL,
    origin_station_id INT NOT NULL,
    dest_station_id   INT NOT NULL,
    seat_id           INT NOT NULL REFERENCES seat (seat_id),
    travel_class      VARCHAR(10) NOT NULL CHECK (travel_class IN ('FIRST', 'SECOND')),
    price             DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    status            VARCHAR(10) NOT NULL DEFAULT 'BOOKED'
                      CHECK (status IN ('BOOKED', 'PAID', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT fk_ticket_origin FOREIGN KEY (journey_id, origin_station_id)
        REFERENCES journey_stop (journey_id, station_id),
    CONSTRAINT fk_ticket_dest FOREIGN KEY (journey_id, dest_station_id)
        REFERENCES journey_stop (journey_id, station_id),
    CONSTRAINT ck_ticket_stations CHECK (origin_station_id <> dest_station_id)
);

CREATE TABLE payment (
    payment_id   INT IDENTITY PRIMARY KEY,
    booking_id   INT NOT NULL REFERENCES booking (booking_id),
    amount       DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    method       VARCHAR(15) NOT NULL CHECK (method IN ('CARD', 'MOBILE_MONEY', 'CASH')),
    status       VARCHAR(10) NOT NULL CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED')),
    attempted_at DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    paid_at      DATETIME2(0) NULL,
    CONSTRAINT ck_payment_dates CHECK (paid_at >= attempted_at)
);

CREATE TABLE refund (
    refund_id   INT IDENTITY PRIMARY KEY,
    ticket_id   INT NOT NULL UNIQUE REFERENCES ticket (ticket_id),
    payment_id  INT NOT NULL REFERENCES payment (payment_id),
    amount      DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    reason      VARCHAR(200) NULL,
    refunded_at DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE pricing_rule (
    rule_id         INT IDENTITY PRIMARY KEY,
    line_id         INT NOT NULL REFERENCES railway_line (line_id),
    travel_class    VARCHAR(10) NOT NULL CHECK (travel_class IN ('FIRST', 'SECOND')),
    min_days_before INT NOT NULL DEFAULT 0 CHECK (min_days_before >= 0),
    price_per_km    DECIMAL(8,2) NOT NULL CHECK (price_per_km > 0),
    demand_factor   DECIMAL(4,2) NOT NULL DEFAULT 1 CHECK (demand_factor > 0),
    valid_from      DATETIME2(0) NOT NULL,
    valid_to        DATETIME2(0) NULL,
    CONSTRAINT ck_rule_dates CHECK (valid_to > valid_from)
);

CREATE TABLE discount (
    discount_id   INT IDENTITY PRIMARY KEY,
    code          VARCHAR(20) NOT NULL UNIQUE,
    discount_type VARCHAR(10) NOT NULL CHECK (discount_type IN ('CATEGORY', 'LOYALTY', 'PROMO')),
    target        VARCHAR(10) NULL,
    percent_off   DECIMAL(5,2) NOT NULL CHECK (percent_off > 0 AND percent_off <= 100),
    valid_from    DATE NOT NULL,
    valid_to      DATE NULL,
    CONSTRAINT ck_discount_dates CHECK (valid_to >= valid_from)
);

CREATE TABLE ticket_discount (
    ticket_id   INT NOT NULL REFERENCES ticket (ticket_id) ON DELETE CASCADE,
    discount_id INT NOT NULL REFERENCES discount (discount_id),
    amount      DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    PRIMARY KEY (ticket_id, discount_id)
);

CREATE TABLE reward (
    reward_id      INT IDENTITY PRIMARY KEY,
    name           VARCHAR(80) NOT NULL UNIQUE,
    points_cost    INT NOT NULL CHECK (points_cost > 0),
    available_from DATE NOT NULL,
    available_to   DATE NULL,
    CONSTRAINT ck_reward_dates CHECK (available_to >= available_from)
);

CREATE TABLE loyalty_account (
    account_id     INT IDENTITY PRIMARY KEY,
    passenger_id   INT NOT NULL UNIQUE REFERENCES passenger (passenger_id),
    tier           VARCHAR(10) NOT NULL DEFAULT 'BRONZE' CHECK (tier IN ('BRONZE', 'SILVER', 'GOLD')),
    points_balance INT NOT NULL DEFAULT 0 CHECK (points_balance >= 0),
    opened_at      DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE loyalty_transaction (
    transaction_id INT IDENTITY PRIMARY KEY,
    account_id     INT NOT NULL REFERENCES loyalty_account (account_id),
    ticket_id      INT NULL REFERENCES ticket (ticket_id),
    reward_id      INT NULL REFERENCES reward (reward_id),
    txn_type       VARCHAR(10) NOT NULL CHECK (txn_type IN ('EARNED', 'SPENT', 'EXPIRED', 'ADJUSTED')),
    points         INT NOT NULL,
    created_at     DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT ck_txn_sign CHECK ((txn_type = 'EARNED' AND points > 0)
                               OR (txn_type IN ('SPENT', 'EXPIRED') AND points < 0)
                               OR (txn_type = 'ADJUSTED' AND points <> 0))
);

CREATE TABLE employee (
    employee_id INT IDENTITY PRIMARY KEY,
    first_name  VARCHAR(50) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,
    email       VARCHAR(120) NOT NULL UNIQUE,
    job_role    VARCHAR(15) NOT NULL
                CHECK (job_role IN ('DRIVER', 'CONDUCTOR', 'CONTROLLER', 'TECHNICIAN', 'ADMIN')),
    hired_on    DATE NOT NULL,
    is_active   BIT NOT NULL DEFAULT 1
);

CREATE TABLE driver_licence (
    licence_id     INT IDENTITY PRIMARY KEY,
    employee_id    INT NOT NULL REFERENCES employee (employee_id) ON DELETE CASCADE,
    licence_number VARCHAR(30) NOT NULL UNIQUE,
    issued_on      DATE NOT NULL,
    expires_on     DATE NOT NULL,
    CONSTRAINT ck_licence_dates CHECK (expires_on > issued_on)
);

CREATE TABLE journey_crew (
    journey_id  INT NOT NULL REFERENCES journey (journey_id) ON DELETE CASCADE,
    employee_id INT NOT NULL REFERENCES employee (employee_id),
    assigned_at DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (journey_id, employee_id)
);

CREATE TABLE maintenance (
    maintenance_id   INT IDENTITY PRIMARY KEY,
    train_id         INT NOT NULL REFERENCES train (train_id),
    maintenance_type VARCHAR(15) NOT NULL CHECK (maintenance_type IN ('ROUTINE', 'INSPECTION', 'REPAIR')),
    start_date       DATE NOT NULL,
    duration_days    INT NOT NULL CHECK (duration_days > 0),
    cost             DECIMAL(12,2) NOT NULL CHECK (cost >= 0),
    result           VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (result IN ('PENDING', 'PASSED', 'FAILED'))
);

CREATE TABLE incident (
    incident_id INT IDENTITY PRIMARY KEY,
    train_id    INT NOT NULL REFERENCES train (train_id),
    journey_id  INT NULL REFERENCES journey (journey_id) ON DELETE SET NULL,
    severity    VARCHAR(10) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    category    VARCHAR(15) NOT NULL CHECK (category IN ('TECHNICAL', 'SAFETY', 'WEATHER', 'OTHER')),
    description VARCHAR(300) NOT NULL,
    status      VARCHAR(15) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED')),
    reported_at DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    resolved_at DATETIME2(0) NULL,
    CONSTRAINT ck_incident_dates CHECK (resolved_at >= reported_at)
);

CREATE TABLE delay (
    delay_id    INT IDENTITY PRIMARY KEY,
    journey_id  INT NOT NULL,
    station_id  INT NOT NULL,
    minutes     INT NOT NULL CHECK (minutes > 0),
    reason      VARCHAR(200) NOT NULL,
    recorded_at DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT fk_delay_stop FOREIGN KEY (journey_id, station_id)
        REFERENCES journey_stop (journey_id, station_id) ON DELETE CASCADE
);

-- Une annulation concerne soit un trajet, soit un billet (exactement l'un des deux).
CREATE TABLE cancellation (
    cancellation_id INT IDENTITY PRIMARY KEY,
    journey_id      INT NULL REFERENCES journey (journey_id),
    ticket_id       INT NULL REFERENCES ticket (ticket_id),
    reason          VARCHAR(200) NOT NULL,
    cancelled_at    DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT ck_cancel_target CHECK ((journey_id IS NOT NULL AND ticket_id IS NULL)
                                    OR (journey_id IS NULL AND ticket_id IS NOT NULL))
);
CREATE UNIQUE INDEX uq_cancel_journey ON cancellation (journey_id) WHERE journey_id IS NOT NULL;
CREATE UNIQUE INDEX uq_cancel_ticket  ON cancellation (ticket_id)  WHERE ticket_id IS NOT NULL;

CREATE TABLE audit_log (
    audit_id   BIGINT IDENTITY PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id  VARCHAR(50) NOT NULL,
    operation  VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    changed_at DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),
    changed_by NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    old_values NVARCHAR(MAX) NULL,
    new_values NVARCHAR(MAX) NULL
);
GO

-- Vues utilitaires reutilisees dans les fichiers suivants

-- Billet + positions (stop_order) de son origine et de sa destination
CREATE VIEW v_ticket_segment AS
SELECT t.ticket_id, t.booking_id, t.journey_id, t.seat_id, t.travel_class, t.price, t.status,
       o.stop_order AS origin_order, d.stop_order AS dest_order
FROM ticket t
JOIN journey_stop o ON o.journey_id = t.journey_id AND o.station_id = t.origin_station_id
JOIN journey_stop d ON d.journey_id = t.journey_id AND d.station_id = t.dest_station_id;
GO

-- Billets comptant comme revenu : non annules et reservation payee avec succes
CREATE VIEW v_paid_ticket AS
SELECT t.ticket_id, t.booking_id, b.passenger_id, t.journey_id, j.line_id, j.train_id, j.service_date,
       t.origin_station_id, t.dest_station_id, t.travel_class, t.price
FROM ticket t
JOIN booking b ON b.booking_id = t.booking_id
JOIN journey j ON j.journey_id = t.journey_id
WHERE t.status IN ('PAID', 'COMPLETED')
  AND EXISTS (SELECT 1 FROM payment p WHERE p.booking_id = b.booking_id AND p.status = 'SUCCESS');
GO

-- Capacite d'un train
CREATE VIEW v_train_capacity AS
SELECT c.train_id, COUNT(DISTINCT c.carriage_id) AS carriages, COUNT(s.seat_id) AS seats
FROM carriage c
LEFT JOIN seat s ON s.carriage_id = c.carriage_id
GROUP BY c.train_id;
GO
