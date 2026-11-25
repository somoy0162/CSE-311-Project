-- =====================================================================
--  CSE311L - Database Systems Lab | North South University
--  Project   : GarmentTrack - Garment Factory Order Tracking System
--  Section 4 | Group 3
--  Members   : Fahia Afroze Dia (2012849042), Md. Mohaiminul Islam (2013697042),
--              Md Sakibur Rahman Somoy (1921382642), Mashnoor Monowar Khan (2021166042)
--  Contents  : Schema (10 tables) + constraints + sample data + views + triggers
--  Tested on : MySQL 8.0+ (CHECK constraints need 8.0.16+)
-- =====================================================================

DROP DATABASE IF EXISTS garmenttrack;
CREATE DATABASE garmenttrack CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE garmenttrack;

-- =====================================================================
--  1. TABLES
-- =====================================================================

-- 1. BUYER
CREATE TABLE buyer (
    buyer_id       INT AUTO_INCREMENT,
    buyer_name     VARCHAR(100) NOT NULL,
    country        VARCHAR(60)  NOT NULL,
    contact_person VARCHAR(100) NOT NULL,
    email          VARCHAR(120) NOT NULL,
    phone          VARCHAR(30),
    CONSTRAINT pk_buyer       PRIMARY KEY (buyer_id),
    CONSTRAINT uq_buyer_name  UNIQUE (buyer_name),
    CONSTRAINT uq_buyer_email UNIQUE (email)
) ENGINE=InnoDB;

-- 2. PRODUCTION_LINE
CREATE TABLE production_line (
    line_id         INT AUTO_INCREMENT,
    line_name       VARCHAR(50)  NOT NULL,
    supervisor_name VARCHAR(100) NOT NULL,
    no_of_workers   INT          NOT NULL,
    daily_capacity  INT          NOT NULL,
    CONSTRAINT pk_line          PRIMARY KEY (line_id),
    CONSTRAINT uq_line_name     UNIQUE (line_name),
    CONSTRAINT ck_line_workers  CHECK (no_of_workers > 0),
    CONSTRAINT ck_line_capacity CHECK (daily_capacity > 0)
) ENGINE=InnoDB;

-- 3. DEFECT_TYPE
CREATE TABLE defect_type (
    defect_type_id INT AUTO_INCREMENT,
    defect_name    VARCHAR(80) NOT NULL,
    severity       ENUM('Minor','Major','Critical') NOT NULL,
    description    VARCHAR(255),
    CONSTRAINT pk_defect_type PRIMARY KEY (defect_type_id),
    CONSTRAINT uq_defect_name UNIQUE (defect_name)
) ENGINE=InnoDB;

-- 4. ORDERS
CREATE TABLE orders (
    order_id       INT AUTO_INCREMENT,
    buyer_id       INT         NOT NULL,
    order_no       VARCHAR(30) NOT NULL,
    order_date     DATE        NOT NULL,
    shipment_date  DATE        NOT NULL,
    total_quantity INT         NOT NULL,
    status         ENUM('Pending','In Production','Partially Shipped','Shipped')
                   NOT NULL DEFAULT 'Pending',
    CONSTRAINT pk_orders       PRIMARY KEY (order_id),
    CONSTRAINT uq_order_no     UNIQUE (order_no),
    CONSTRAINT fk_orders_buyer FOREIGN KEY (buyer_id)
        REFERENCES buyer(buyer_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_orders_qty   CHECK (total_quantity > 0),
    CONSTRAINT ck_orders_dates CHECK (shipment_date >= order_date)
) ENGINE=InnoDB;

-- 5. STYLE
CREATE TABLE style (
    style_id    INT AUTO_INCREMENT,
    order_id    INT          NOT NULL,
    style_name  VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    quantity    INT          NOT NULL,
    unit_price  DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_style       PRIMARY KEY (style_id),
    CONSTRAINT uq_style_order UNIQUE (order_id, style_name),
    CONSTRAINT fk_style_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_style_qty   CHECK (quantity > 0),
    CONSTRAINT ck_style_price CHECK (unit_price > 0)
) ENGINE=InnoDB;

-- 6. LINE_ASSIGNMENT
CREATE TABLE line_assignment (
    assignment_id INT AUTO_INCREMENT,
    order_id      INT  NOT NULL,
    line_id       INT  NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE,
    daily_target  INT  NOT NULL,
    CONSTRAINT pk_assignment       PRIMARY KEY (assignment_id),
    CONSTRAINT uq_assignment       UNIQUE (order_id, line_id, start_date),
    CONSTRAINT fk_assign_order     FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_assign_line      FOREIGN KEY (line_id)
        REFERENCES production_line(line_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_assign_target    CHECK (daily_target > 0),
    CONSTRAINT ck_assign_dates     CHECK (end_date IS NULL OR end_date >= start_date)
) ENGINE=InnoDB;

-- 7. PRODUCTION_LOG
CREATE TABLE production_log (
    log_id       INT AUTO_INCREMENT,
    order_id     INT  NOT NULL,
    line_id      INT  NOT NULL,
    stage        ENUM('Cutting','Sewing','Finishing','Packing') NOT NULL,
    log_date     DATE NOT NULL,
    pieces_count INT  NOT NULL,
    remarks      VARCHAR(255),
    CONSTRAINT pk_prodlog      PRIMARY KEY (log_id),
    CONSTRAINT fk_plog_order   FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_plog_line    FOREIGN KEY (line_id)
        REFERENCES production_line(line_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_plog_pieces  CHECK (pieces_count >= 0)
) ENGINE=InnoDB;

-- 8. QUALITY_CHECK
CREATE TABLE quality_check (
    qc_id          INT AUTO_INCREMENT,
    order_id       INT  NOT NULL,
    line_id        INT  NOT NULL,
    check_date     DATE NOT NULL,
    inspector_name VARCHAR(100) NOT NULL,
    inspected_qty  INT  NOT NULL,
    passed_qty     INT  NOT NULL,
    rejected_qty   INT  NOT NULL,
    CONSTRAINT pk_qc          PRIMARY KEY (qc_id),
    CONSTRAINT fk_qc_order    FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_qc_line     FOREIGN KEY (line_id)
        REFERENCES production_line(line_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_qc_nonneg   CHECK (inspected_qty > 0 AND passed_qty >= 0 AND rejected_qty >= 0),
    CONSTRAINT ck_qc_balance  CHECK (passed_qty + rejected_qty = inspected_qty)
) ENGINE=InnoDB;

-- 9. QC_DEFECT  (resolves the M:N between QUALITY_CHECK and DEFECT_TYPE)
CREATE TABLE qc_defect (
    qc_defect_id   INT AUTO_INCREMENT,
    qc_id          INT NOT NULL,
    defect_type_id INT NOT NULL,
    defect_count   INT NOT NULL,
    CONSTRAINT pk_qc_defect     PRIMARY KEY (qc_defect_id),
    CONSTRAINT uq_qc_defect     UNIQUE (qc_id, defect_type_id),
    CONSTRAINT fk_qcd_qc        FOREIGN KEY (qc_id)
        REFERENCES quality_check(qc_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_qcd_defect    FOREIGN KEY (defect_type_id)
        REFERENCES defect_type(defect_type_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_qcd_count     CHECK (defect_count > 0)
) ENGINE=InnoDB;

-- 10. SHIPMENT
CREATE TABLE shipment (
    shipment_id   INT AUTO_INCREMENT,
    order_id      INT         NOT NULL,
    invoice_no    VARCHAR(30) NOT NULL,
    shipment_date DATE        NOT NULL,
    shipped_qty   INT         NOT NULL,
    ship_mode     ENUM('Sea','Air','Road') NOT NULL,
    status        ENUM('Scheduled','In Transit','Delivered') NOT NULL DEFAULT 'Scheduled',
    CONSTRAINT pk_shipment      PRIMARY KEY (shipment_id),
    CONSTRAINT uq_invoice_no    UNIQUE (invoice_no),
    CONSTRAINT fk_ship_order    FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_ship_qty      CHECK (shipped_qty > 0)
) ENGINE=InnoDB;

-- Helpful indexes for reporting queries
CREATE INDEX idx_orders_status   ON orders(status, shipment_date);
CREATE INDEX idx_plog_order_stage ON production_log(order_id, stage);
CREATE INDEX idx_plog_line_date  ON production_log(line_id, log_date);
CREATE INDEX idx_qc_order        ON quality_check(order_id);

-- =====================================================================
--  2. SAMPLE DATA
-- =====================================================================

-- ---------- BUYER (5) ----------
INSERT INTO buyer (buyer_id, buyer_name, country, contact_person, email, phone) VALUES
(1, 'Nordic Fashion AB',     'Sweden',  'Erik Lindqvist',  'erik.lindqvist@nordicfashion.example', '+46-8-5551-2034'),
(2, 'Iberia Apparel S.L.',   'Spain',   'Lucia Fernandez', 'lucia.f@iberiaapparel.example',        '+34-91-555-0172'),
(3, 'Liberty Retail Group',  'USA',     'Michael Carter',  'm.carter@libertyretail.example',       '+1-212-555-0148'),
(4, 'Britannia Value Wear',  'UK',      'Emily Thompson',  'emily.t@britanniavalue.example',       '+44-20-5550-0193'),
(5, 'Rhein Textil GmbH',     'Germany', 'Hans Becker',     'hans.becker@rheintextil.example',      '+49-221-555-0166');

-- ---------- PRODUCTION_LINE (5) ----------
INSERT INTO production_line (line_id, line_name, supervisor_name, no_of_workers, daily_capacity) VALUES
(1, 'Line-01', 'Abdul Karim',    45, 1200),
(2, 'Line-02', 'Shahidul Islam', 50, 1400),
(3, 'Line-03', 'Nasima Akter',   40, 1000),
(4, 'Line-04', 'Rafiqul Hasan',  55, 1600),
(5, 'Line-05', 'Jesmin Begum',   48, 1300);

-- ---------- DEFECT_TYPE (8) ----------
INSERT INTO defect_type (defect_type_id, defect_name, severity, description) VALUES
(1, 'Broken Stitch',     'Minor',    'Stitch thread is broken along the seam'),
(2, 'Skipped Stitch',    'Minor',    'One or more stitches missing in a seam'),
(3, 'Open Seam',         'Major',    'Seam has separated or is not fully joined'),
(4, 'Oil / Dirt Stain',  'Major',    'Visible oil or dirt mark on the fabric'),
(5, 'Wrong Measurement', 'Major',    'Garment size is outside the tolerance in the spec sheet'),
(6, 'Fabric Hole',       'Critical', 'Hole or tear in the fabric'),
(7, 'Color Shading',     'Major',    'Color difference between panels of the same garment'),
(8, 'Loose Thread',      'Minor',    'Untrimmed or hanging thread on the garment');

-- ---------- ORDERS (6) ----------
INSERT INTO orders (order_id, buyer_id, order_no, order_date, shipment_date, total_quantity, status) VALUES
(1, 1, 'ORD-2026-001', '2026-08-15', '2026-11-10', 12000, 'Shipped'),
(2, 2, 'ORD-2026-002', '2026-09-10', '2026-12-05',  8000, 'Partially Shipped'),
(3, 3, 'ORD-2026-003', '2026-10-01', '2026-12-20', 15000, 'In Production'),
(4, 4, 'ORD-2026-004', '2026-10-15', '2026-12-10',  6000, 'In Production'),
(5, 5, 'ORD-2026-005', '2026-11-05', '2027-01-15', 10000, 'In Production'),
(6, 1, 'ORD-2026-006', '2026-11-15', '2027-02-10',  9000, 'Pending');

-- ---------- STYLE (10)  (style quantities add up to total_quantity) ----------
INSERT INTO style (style_id, order_id, style_name, description, quantity, unit_price) VALUES
( 1, 1, 'Basic Crew Neck T-Shirt', '100% cotton, 180 GSM, round neck, short sleeve', 7000,  4.20),
( 2, 1, 'Classic Polo Shirt',      'Cotton pique polo with 2-button placket',        5000,  6.50),
( 3, 2, 'Denim Jacket',            'Men''s washed denim jacket, button front',       5000, 14.00),
( 4, 2, 'Slim Fit Jeans',          'Women''s stretch denim, 5-pocket slim fit',      3000, 11.50),
( 5, 3, 'Kids Pullover Hoodie',    'Fleece hoodie with kangaroo pocket',             9000,  7.80),
( 6, 3, 'Jogger Pants',            'Cotton-poly jogger with elastic cuff',           6000,  6.90),
( 7, 4, 'Ladies Printed Blouse',   'Viscose blouse with all-over print',             6000,  5.40),
( 8, 5, 'Cargo Shorts',            'Cotton twill cargo shorts, 6 pockets',           6000,  6.10),
( 9, 5, 'Slim Polo Shirt',         'Slim fit polo with contrast collar',             4000,  6.80),
(10, 6, 'Fleece Sweatshirt',       'Brushed fleece crew neck sweatshirt',            9000,  8.90);

-- ---------- LINE_ASSIGNMENT (9) ----------
INSERT INTO line_assignment (assignment_id, order_id, line_id, start_date, end_date, daily_target) VALUES
(1, 1, 1, '2026-08-25', '2026-11-05',  700),
(2, 1, 2, '2026-08-25', '2026-11-05',  800),
(3, 2, 3, '2026-09-20', '2026-11-25',  600),
(4, 2, 4, '2026-09-20', '2026-11-25',  700),
(5, 3, 2, '2026-10-26', '2026-12-15',  800),
(6, 3, 5, '2026-10-10', '2026-12-15',  700),
(7, 4, 1, '2026-10-26', '2026-12-05',  500),
(8, 5, 4, '2026-11-10', '2027-01-10',  600),
(9, 5, 3, '2026-11-20', '2027-01-10',  400);

-- ---------- PRODUCTION_LOG (28) ----------
-- Each row is a stage-wise batch entry (pieces completed in that stage on that date).
INSERT INTO production_log (log_id, order_id, line_id, stage, log_date, pieces_count, remarks) VALUES
-- Order 1 : fully produced (12,000 pcs)
( 1, 1, 1, 'Cutting',   '2026-09-05',  5000, 'Cutting completed for Line-01 share'),
( 2, 1, 2, 'Cutting',   '2026-09-06',  7000, 'Cutting completed for Line-02 share'),
( 3, 1, 1, 'Sewing',    '2026-10-05',  5000, 'Sewing completed'),
( 4, 1, 2, 'Sewing',    '2026-10-08',  7000, 'Sewing completed'),
( 5, 1, 1, 'Finishing', '2026-10-20',  5000, 'Pressing and trimming done'),
( 6, 1, 2, 'Finishing', '2026-10-22',  7000, 'Pressing and trimming done'),
( 7, 1, 1, 'Packing',   '2026-10-30',  5000, 'Packed in cartons'),
( 8, 1, 2, 'Packing',   '2026-11-01',  7000, 'Packed in cartons'),
-- Order 2 : 6,000 of 8,000 packed
( 9, 2, 3, 'Cutting',   '2026-10-01',  3000, 'Denim cutting done'),
(10, 2, 4, 'Cutting',   '2026-10-02',  5000, 'Denim cutting done'),
(11, 2, 3, 'Sewing',    '2026-10-25',  3000, 'Sewing completed'),
(12, 2, 4, 'Sewing',    '2026-10-27',  5000, 'Sewing completed'),
(13, 2, 3, 'Finishing', '2026-11-08',  3000, 'Washing and finishing done'),
(14, 2, 4, 'Finishing', '2026-11-10',  5000, 'Washing and finishing done'),
(15, 2, 3, 'Packing',   '2026-11-15',  3000, 'Packed in cartons'),
(16, 2, 4, 'Packing',   '2026-11-18',  3000, 'Partial packing, remaining 2000 pending'),
-- Order 3 : in production
(17, 3, 2, 'Cutting',   '2026-11-02',  8000, 'Cutting completed for Line-02 share'),
(18, 3, 5, 'Cutting',   '2026-11-03',  7000, 'Cutting completed for Line-05 share'),
(19, 3, 2, 'Sewing',    '2026-11-12',  4500, 'Sewing in progress'),
(20, 3, 5, 'Sewing',    '2026-11-14',  3500, 'Sewing in progress'),
(21, 3, 2, 'Finishing', '2026-11-20',  2000, 'First batch finished'),
-- Order 4 : behind schedule (low sewing output)
(22, 4, 1, 'Cutting',   '2026-10-30',  6000, 'Cutting completed'),
(23, 4, 1, 'Sewing',    '2026-11-10',  1500, 'Delay: print approval late'),
(24, 4, 1, 'Sewing',    '2026-11-22',  1300, 'Machine breakdown for 2 days'),
(25, 4, 1, 'Finishing', '2026-11-22',   600, 'First batch finished'),
-- Order 5 : just started
(26, 5, 4, 'Cutting',   '2026-11-18',  3000, 'Cutting started'),
(27, 5, 3, 'Cutting',   '2026-11-22',  1500, 'Cutting started'),
(28, 5, 4, 'Sewing',    '2026-11-23',   800, 'Sewing started');

-- ---------- QUALITY_CHECK (8) ----------
INSERT INTO quality_check (qc_id, order_id, line_id, check_date, inspector_name, inspected_qty, passed_qty, rejected_qty) VALUES
(1, 1, 1, '2026-10-18', 'Anwar Hossain', 500, 470, 30),
(2, 1, 2, '2026-10-21', 'Anwar Hossain', 600, 566, 34),
(3, 1, 2, '2026-10-29', 'Kamrul Hasan',  800, 768, 32),
(4, 2, 3, '2026-11-05', 'Kamrul Hasan',  400, 372, 28),
(5, 2, 4, '2026-11-12', 'Sumon Mia',     500, 468, 32),
(6, 3, 5, '2026-11-17', 'Sumon Mia',     350, 327, 23),
(7, 4, 1, '2026-11-21', 'Anwar Hossain', 300, 268, 32),
(8, 5, 4, '2026-11-24', 'Kamrul Hasan',  250, 240, 10);

-- ---------- QC_DEFECT (29)  (defect counts add up to rejected_qty of each QC) ----------
INSERT INTO qc_defect (qc_defect_id, qc_id, defect_type_id, defect_count) VALUES
-- QC 1 (30)
( 1, 1, 1, 10), ( 2, 1, 3,  8), ( 3, 1, 4,  7), ( 4, 1, 8,  5),
-- QC 2 (34)
( 5, 2, 2, 12), ( 6, 2, 3,  9), ( 7, 2, 7,  6), ( 8, 2, 6,  3), ( 9, 2, 8, 4),
-- QC 3 (32)
(10, 3, 1, 10), (11, 3, 5,  9), (12, 3, 4,  8), (13, 3, 8,  5),
-- QC 4 (28)
(14, 4, 3, 11), (15, 4, 6,  5), (16, 4, 2,  7), (17, 4, 1,  5),
-- QC 5 (32)
(18, 5, 5, 12), (19, 5, 7, 10), (20, 5, 4,  6), (21, 5, 8,  4),
-- QC 6 (23)
(22, 6, 1,  9), (23, 6, 2,  8), (24, 6, 3,  6),
-- QC 7 (32)
(25, 7, 3, 14), (26, 7, 5, 10), (27, 7, 4,  4), (28, 7, 6,  4),
-- QC 8 (10)
(29, 8, 8,  6), (30, 8, 1,  4);

-- ---------- SHIPMENT (4) ----------
INSERT INTO shipment (shipment_id, order_id, invoice_no, shipment_date, shipped_qty, ship_mode, status) VALUES
(1, 1, 'INV-2026-0101', '2026-11-05', 2000, 'Air', 'Delivered'),
(2, 1, 'INV-2026-0102', '2026-11-08', 5000, 'Sea', 'In Transit'),
(3, 1, 'INV-2026-0103', '2026-11-10', 5000, 'Sea', 'In Transit'),
(4, 2, 'INV-2026-0104', '2026-11-20', 5000, 'Sea', 'In Transit');

-- =====================================================================
--  3. VIEWS  (Reports & Delay Alerts)
-- =====================================================================

-- 3.1 Order progress: pieces passed each stage + completion % (based on packed pieces)
CREATE OR REPLACE VIEW v_order_progress AS
SELECT  o.order_id,
        o.order_no,
        b.buyer_name,
        o.total_quantity,
        o.shipment_date,
        o.status,
        COALESCE(SUM(CASE WHEN pl.stage = 'Cutting'   THEN pl.pieces_count END), 0) AS cut_qty,
        COALESCE(SUM(CASE WHEN pl.stage = 'Sewing'    THEN pl.pieces_count END), 0) AS sewn_qty,
        COALESCE(SUM(CASE WHEN pl.stage = 'Finishing' THEN pl.pieces_count END), 0) AS finished_qty,
        COALESCE(SUM(CASE WHEN pl.stage = 'Packing'   THEN pl.pieces_count END), 0) AS packed_qty,
        ROUND(COALESCE(SUM(CASE WHEN pl.stage = 'Packing' THEN pl.pieces_count END), 0)
              * 100.0 / o.total_quantity, 1) AS completion_pct
FROM orders o
JOIN buyer b              ON b.buyer_id = o.buyer_id
LEFT JOIN production_log pl ON pl.order_id = o.order_id
GROUP BY o.order_id, o.order_no, b.buyer_name, o.total_quantity, o.shipment_date, o.status;

-- 3.2 Orders at risk of delay: not fully shipped, due within 30 days (or overdue) and < 90% packed
CREATE OR REPLACE VIEW v_orders_at_risk AS
SELECT  order_id, order_no, buyer_name, shipment_date,
        DATEDIFF(shipment_date, CURDATE()) AS days_left,
        total_quantity, packed_qty, completion_pct
FROM v_order_progress
WHERE status <> 'Shipped'
  AND DATEDIFF(shipment_date, CURDATE()) <= 30
  AND completion_pct < 90;

-- 3.3 Line performance: output per line, QC pass/reject rates
CREATE OR REPLACE VIEW v_line_performance AS
SELECT  l.line_id,
        l.line_name,
        l.supervisor_name,
        l.daily_capacity,
        COALESCE(p.sewn_qty, 0)      AS total_sewn_qty,
        COALESCE(q.inspected, 0)     AS inspected_qty,
        COALESCE(q.rejected, 0)      AS rejected_qty,
        ROUND(COALESCE(q.rejected, 0) * 100.0 / NULLIF(q.inspected, 0), 2) AS reject_rate_pct
FROM production_line l
LEFT JOIN (SELECT line_id, SUM(pieces_count) AS sewn_qty
           FROM production_log WHERE stage = 'Sewing' GROUP BY line_id) p ON p.line_id = l.line_id
LEFT JOIN (SELECT line_id, SUM(inspected_qty) AS inspected, SUM(rejected_qty) AS rejected
           FROM quality_check GROUP BY line_id) q ON q.line_id = l.line_id;

-- 3.4 Shipment summary per order
CREATE OR REPLACE VIEW v_shipment_summary AS
SELECT  o.order_no,
        o.total_quantity,
        COALESCE(SUM(s.shipped_qty), 0)                   AS shipped_qty,
        o.total_quantity - COALESCE(SUM(s.shipped_qty), 0) AS balance_qty,
        COUNT(s.shipment_id)                              AS no_of_shipments
FROM orders o
LEFT JOIN shipment s ON s.order_id = o.order_id
GROUP BY o.order_id, o.order_no, o.total_quantity;

-- =====================================================================
--  4. TRIGGERS  (automatic order status update on shipment)
-- =====================================================================
DELIMITER $$

CREATE TRIGGER trg_shipment_after_insert
AFTER INSERT ON shipment
FOR EACH ROW
BEGIN
    DECLARE v_total   INT;
    DECLARE v_shipped INT;

    SELECT total_quantity INTO v_total FROM orders WHERE order_id = NEW.order_id;
    SELECT COALESCE(SUM(shipped_qty), 0) INTO v_shipped FROM shipment WHERE order_id = NEW.order_id;

    UPDATE orders
       SET status = IF(v_shipped >= v_total, 'Shipped', 'Partially Shipped')
     WHERE order_id = NEW.order_id;
END$$

-- Prevent shipping more than the ordered quantity
CREATE TRIGGER trg_shipment_before_insert
BEFORE INSERT ON shipment
FOR EACH ROW
BEGIN
    DECLARE v_total   INT;
    DECLARE v_shipped INT;

    SELECT total_quantity INTO v_total FROM orders WHERE order_id = NEW.order_id;
    SELECT COALESCE(SUM(shipped_qty), 0) INTO v_shipped FROM shipment WHERE order_id = NEW.order_id;

    IF v_shipped + NEW.shipped_qty > v_total THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Shipped quantity exceeds the total order quantity';
    END IF;
END$$

DELIMITER ;

-- =====================================================================
--  5. VERIFICATION QUERIES  (run these during the in-person review)
-- =====================================================================
-- SHOW TABLES;
-- SELECT * FROM v_order_progress;
-- SELECT * FROM v_orders_at_risk;
-- SELECT * FROM v_line_performance;
-- SELECT * FROM v_shipment_summary;
--
-- Defects per order:
-- SELECT o.order_no, dt.defect_name, SUM(qd.defect_count) AS total_defects
-- FROM qc_defect qd
-- JOIN quality_check qc ON qc.qc_id = qd.qc_id
-- JOIN orders o         ON o.order_id = qc.order_id
-- JOIN defect_type dt   ON dt.defect_type_id = qd.defect_type_id
-- GROUP BY o.order_no, dt.defect_name
-- ORDER BY o.order_no, total_defects DESC;
