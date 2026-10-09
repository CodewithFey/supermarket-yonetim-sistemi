
SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS new_schema
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE new_schema;
SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;

DROP TABLE IF EXISTS REORDER_LOG;
DROP TABLE IF EXISTS PAYMENT;
DROP TABLE IF EXISTS SALE_LINE;
DROP TABLE IF EXISTS SALE;
DROP TABLE IF EXISTS WORKS_IN;
DROP TABLE IF EXISTS IN_STOCK;
DROP TABLE IF EXISTS SUPPLIED_BY;
DROP TABLE IF EXISTS PRODUCT;
DROP TABLE IF EXISTS PRODUCT_TYPE;
DROP TABLE IF EXISTS CUSTOMER;
DROP TABLE IF EXISTS SUPPLIER;
DROP TABLE IF EXISTS STAFF;
DROP TABLE IF EXISTS BRANCH;

DROP TRIGGER IF EXISTS trg_check_stock;
DROP TRIGGER IF EXISTS trg_check_stock_upd;
DROP TRIGGER IF EXISTS trg_check_loyalty;
DROP TRIGGER IF EXISTS trg_check_payment;
DROP TRIGGER IF EXISTS trg_after_ins_sale_line;
DROP TRIGGER IF EXISTS trg_after_upd_sale_line;
DROP TRIGGER IF EXISTS trg_after_del_sale_line;
DROP TRIGGER IF EXISTS trg_reorder_alert;

CREATE TABLE BRANCH (
    BranchNo    INT           PRIMARY KEY,
    BranchName  VARCHAR(100)  NOT NULL,
    Location    VARCHAR(255)  NOT NULL,
    Phone       VARCHAR(20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE STAFF (
    StaffID         INT            AUTO_INCREMENT PRIMARY KEY,
    FirstName       VARCHAR(50)    NOT NULL,
    LastName        VARCHAR(50)    NOT NULL,
    BirthDate       DATE           NOT NULL,
    Salary          DECIMAL(10,2)  CHECK (Salary >= 0),
    Position        VARCHAR(50)    NOT NULL,
    Phone           VARCHAR(20),
    SupervisorID    INT            DEFAULT NULL,
    ManagerOfBranch INT            DEFAULT NULL,
    UNIQUE  KEY uq_manager (ManagerOfBranch),
    CONSTRAINT fk_staff_sup  FOREIGN KEY (SupervisorID)    REFERENCES STAFF(StaffID),
    CONSTRAINT fk_staff_mgr  FOREIGN KEY (ManagerOfBranch) REFERENCES BRANCH(BranchNo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE PRODUCT_TYPE (
    TypeID        INT            PRIMARY KEY,
    TypeName      VARCHAR(100)   NOT NULL,
    TaxRate       DECIMAL(5,2)   CHECK (TaxRate BETWEEN 0 AND 100),
    ReorderLevel  INT            DEFAULT 10 CHECK (ReorderLevel >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE PRODUCT (
    ProductID    INT            AUTO_INCREMENT PRIMARY KEY,
    Barcode      VARCHAR(13)    UNIQUE,
    ProductName  VARCHAR(200)   NOT NULL,
    UnitPrice    DECIMAL(10,2)  NOT NULL CHECK (UnitPrice > 0),
    ExpiryDate   DATE,
    TypeID       INT            NOT NULL,
    CONSTRAINT fk_product_type FOREIGN KEY (TypeID) REFERENCES PRODUCT_TYPE(TypeID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE SUPPLIER (
    SupplierID    INT            PRIMARY KEY,
    SupplierName  VARCHAR(150)   NOT NULL,
    Phone         VARCHAR(20)    NOT NULL,
    Email         VARCHAR(150),
    Address       VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE CUSTOMER (
    CustomerID    INT            AUTO_INCREMENT PRIMARY KEY,
    FirstName     VARCHAR(50)    NOT NULL,
    LastName      VARCHAR(50)    NOT NULL,
    Phone         VARCHAR(20),
    Email         VARCHAR(150),
    RegisterDate  DATE           NOT NULL,
    LoyaltyPoints INT            DEFAULT 0 CHECK (LoyaltyPoints >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE WORKS_IN (
    StaffID      INT            NOT NULL,
    BranchNo     INT            NOT NULL,
    ShiftHours  DECIMAL(4,1)   CHECK (ShiftHours > 0),
    PRIMARY KEY (StaffID, BranchNo),
    CONSTRAINT fk_wi_staff  FOREIGN KEY (StaffID)  REFERENCES STAFF(StaffID),
    CONSTRAINT fk_wi_branch FOREIGN KEY (BranchNo) REFERENCES BRANCH(BranchNo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE SUPPLIED_BY (
    ProductID    INT            NOT NULL,
    SupplierID   INT            NOT NULL,
    SupplyPrice  DECIMAL(10,2)  CHECK (SupplyPrice > 0),
    SupplyDate   DATE,
    PRIMARY KEY (ProductID, SupplierID),
    CONSTRAINT fk_sb_product  FOREIGN KEY (ProductID)  REFERENCES PRODUCT(ProductID),
    CONSTRAINT fk_sb_supplier FOREIGN KEY (SupplierID) REFERENCES SUPPLIER(SupplierID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IN_STOCK (
    BranchNo   INT  NOT NULL,
    ProductID  INT  NOT NULL,
    StockQty   INT  DEFAULT 0 CHECK (StockQty >= 0),
    PRIMARY KEY (BranchNo, ProductID),
    CONSTRAINT fk_is_branch  FOREIGN KEY (BranchNo)  REFERENCES BRANCH(BranchNo),
    CONSTRAINT fk_is_product FOREIGN KEY (ProductID) REFERENCES PRODUCT(ProductID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE SALE (
    SaleNo       INT             AUTO_INCREMENT PRIMARY KEY,
    SaleDate     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    TotalAmount  DECIMAL(12,2)   DEFAULT 0 CHECK (TotalAmount >= 0),
    StaffID      INT             NOT NULL,
    BranchNo     INT             NOT NULL,
    CustomerID   INT             DEFAULT NULL,
    CONSTRAINT fk_sale_staff    FOREIGN KEY (StaffID)    REFERENCES STAFF(StaffID),
    CONSTRAINT fk_sale_branch   FOREIGN KEY (BranchNo)   REFERENCES BRANCH(BranchNo),
    CONSTRAINT fk_sale_customer FOREIGN KEY (CustomerID) REFERENCES CUSTOMER(CustomerID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE SALE_LINE (
    SaleNo     INT            NOT NULL,
    LineNo     INT            NOT NULL,
    Quantity   INT            NOT NULL CHECK (Quantity > 0),
    UnitPrice  DECIMAL(10,2)  NOT NULL CHECK (UnitPrice > 0),
    ProductID  INT            NOT NULL,
    PRIMARY KEY (SaleNo, LineNo),
    CONSTRAINT fk_sl_sale    FOREIGN KEY (SaleNo)    REFERENCES SALE(SaleNo) ON DELETE CASCADE,
    CONSTRAINT fk_sl_product FOREIGN KEY (ProductID) REFERENCES PRODUCT(ProductID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE PAYMENT (
    PaymentNo    INT            PRIMARY KEY,
    PaymentType  VARCHAR(50)    NOT NULL
                     CHECK (PaymentType IN ('Nakit','Kredi Kartı','Banka Kartı','Sadakat Puanı')),
    Amount       DECIMAL(12,2)  NOT NULL CHECK (Amount > 0),
    PaymentDate  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    SaleNo       INT            NOT NULL,
    CONSTRAINT fk_pay_sale FOREIGN KEY (SaleNo) REFERENCES SALE(SaleNo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE REORDER_LOG (
    LogID         INT        AUTO_INCREMENT PRIMARY KEY,
    BranchNo      INT        NOT NULL,
    ProductID     INT        NOT NULL,
    StockQty      INT        NOT NULL,
    ReorderLevel  INT        NOT NULL,
    AlertTime     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELIMITER //
CREATE TRIGGER trg_check_stock
BEFORE INSERT ON SALE_LINE
FOR EACH ROW
BEGIN
    DECLARE v_branch  INT;
    DECLARE v_stock   INT;
    DECLARE v_pname   VARCHAR(200);
    DECLARE v_msg     VARCHAR(500);
    DECLARE v_found   TINYINT DEFAULT 1;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = 0;

    SELECT BranchNo INTO v_branch
    FROM   SALE WHERE SaleNo = NEW.SaleNo;

    SET v_found = 1;
    SELECT ist.StockQty, p.ProductName
    INTO   v_stock, v_pname
    FROM   IN_STOCK ist
    JOIN   PRODUCT  p ON ist.ProductID = p.ProductID
    WHERE  ist.BranchNo  = v_branch
      AND  ist.ProductID = NEW.ProductID;

    IF v_found = 0 THEN
        SET v_msg = CONCAT('Stok kaydı bulunamadı | Şube: ', v_branch,
                           ' | Ürün ID: ', NEW.ProductID);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    ELSEIF v_stock < NEW.Quantity THEN
        SET v_msg = CONCAT('YETERSİZ STOK | Ürün: ', v_pname,
                           ' | Mevcut: ', v_stock,
                           ' | İstenen: ', NEW.Quantity);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_check_stock_upd
BEFORE UPDATE ON SALE_LINE
FOR EACH ROW
BEGIN
    DECLARE v_branch    INT;
    DECLARE v_available INT;
    DECLARE v_pname     VARCHAR(200);
    DECLARE v_msg       VARCHAR(500);
    DECLARE v_found     TINYINT DEFAULT 1;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = 0;

    IF NOT (OLD.Quantity = NEW.Quantity AND OLD.ProductID = NEW.ProductID) THEN

        SELECT BranchNo INTO v_branch FROM SALE WHERE SaleNo = NEW.SaleNo;

        IF OLD.ProductID = NEW.ProductID THEN

            SET v_found = 1;
            SELECT ist.StockQty + OLD.Quantity, p.ProductName
            INTO   v_available, v_pname
            FROM   IN_STOCK ist
            JOIN   PRODUCT  p ON ist.ProductID = p.ProductID
            WHERE  ist.BranchNo  = v_branch
              AND  ist.ProductID = NEW.ProductID;

            IF v_found = 0 THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Stok kaydı bulunamadı (güncelleme).';
            ELSEIF v_available < NEW.Quantity THEN
                SET v_msg = CONCAT('YETERSİZ STOK (güncelleme) | Ürün: ', v_pname,
                                   ' | Kullanılabilir: ', v_available,
                                   ' | İstenen: ', NEW.Quantity);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
            END IF;

        ELSE

            SET v_found = 1;
            SELECT ist.StockQty, p.ProductName
            INTO   v_available, v_pname
            FROM   IN_STOCK ist
            JOIN   PRODUCT  p ON ist.ProductID = p.ProductID
            WHERE  ist.BranchNo  = v_branch
              AND  ist.ProductID = NEW.ProductID;

            IF v_found = 0 THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Yeni ürün için stok kaydı bulunamadı.';
            ELSEIF v_available < NEW.Quantity THEN
                SET v_msg = CONCAT('YETERSİZ STOK (ürün değişimi) | Ürün: ', v_pname,
                                   ' | Mevcut: ', v_available,
                                   ' | İstenen: ', NEW.Quantity);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
            END IF;
        END IF;
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_check_loyalty
BEFORE UPDATE ON CUSTOMER
FOR EACH ROW
BEGIN
    IF NEW.LoyaltyPoints < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Yetersiz sadakat puanı: bakiye sıfırın altına inemez.';
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_check_payment
BEFORE INSERT ON PAYMENT
FOR EACH ROW
BEGIN
    DECLARE v_sale_total DECIMAL(12,2);
    DECLARE v_paid       DECIMAL(12,2);
    DECLARE v_msg        VARCHAR(500);

    SELECT TotalAmount INTO v_sale_total
    FROM   SALE WHERE SaleNo = NEW.SaleNo;

    SELECT COALESCE(SUM(Amount), 0) INTO v_paid
    FROM   PAYMENT WHERE SaleNo = NEW.SaleNo;

    IF v_paid + NEW.Amount > v_sale_total THEN
        SET v_msg = CONCAT('ÖDEME HATASI: Toplam ödeme fişi aşıyor',
                           ' | Fiş: ', v_sale_total,
                           ' | Önceki: ', v_paid,
                           ' | Yeni: ', NEW.Amount);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_after_ins_sale_line
AFTER INSERT ON SALE_LINE
FOR EACH ROW
BEGIN
    DECLARE v_branch INT;

    SELECT BranchNo INTO v_branch FROM SALE WHERE SaleNo = NEW.SaleNo;

    UPDATE IN_STOCK
    SET    StockQty = StockQty - NEW.Quantity
    WHERE  BranchNo = v_branch AND ProductID = NEW.ProductID;

    UPDATE SALE
    SET    TotalAmount = (
               SELECT COALESCE(SUM(Quantity * UnitPrice), 0)
               FROM   SALE_LINE WHERE SaleNo = NEW.SaleNo
           )
    WHERE  SaleNo = NEW.SaleNo;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_after_upd_sale_line
AFTER UPDATE ON SALE_LINE
FOR EACH ROW
BEGIN
    DECLARE v_branch INT;

    IF NOT (OLD.Quantity = NEW.Quantity AND OLD.ProductID = NEW.ProductID) THEN

        SELECT BranchNo INTO v_branch FROM SALE WHERE SaleNo = NEW.SaleNo;

        IF OLD.ProductID = NEW.ProductID THEN

            UPDATE IN_STOCK
            SET    StockQty = StockQty + OLD.Quantity - NEW.Quantity
            WHERE  BranchNo = v_branch AND ProductID = NEW.ProductID;
        ELSE

            UPDATE IN_STOCK
            SET    StockQty = StockQty + OLD.Quantity
            WHERE  BranchNo = v_branch AND ProductID = OLD.ProductID;

            UPDATE IN_STOCK
            SET    StockQty = StockQty - NEW.Quantity
            WHERE  BranchNo = v_branch AND ProductID = NEW.ProductID;
        END IF;

        UPDATE SALE
        SET    TotalAmount = (
                   SELECT COALESCE(SUM(Quantity * UnitPrice), 0)
                   FROM   SALE_LINE WHERE SaleNo = NEW.SaleNo
               )
        WHERE  SaleNo = NEW.SaleNo;
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_after_del_sale_line
AFTER DELETE ON SALE_LINE
FOR EACH ROW
BEGIN
    DECLARE v_branch INT;

    SELECT BranchNo INTO v_branch FROM SALE WHERE SaleNo = OLD.SaleNo;

    UPDATE IN_STOCK
    SET    StockQty = StockQty + OLD.Quantity
    WHERE  BranchNo = v_branch AND ProductID = OLD.ProductID;

    UPDATE SALE
    SET    TotalAmount = (
               SELECT COALESCE(SUM(Quantity * UnitPrice), 0)
               FROM   SALE_LINE WHERE SaleNo = OLD.SaleNo
           )
    WHERE  SaleNo = OLD.SaleNo;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_reorder_alert
AFTER UPDATE ON IN_STOCK
FOR EACH ROW
BEGIN
    DECLARE v_reorder INT;

    IF NEW.StockQty < OLD.StockQty THEN
        SELECT pt.ReorderLevel INTO v_reorder
        FROM   PRODUCT p
        JOIN   PRODUCT_TYPE pt ON p.TypeID = pt.TypeID
        WHERE  p.ProductID = NEW.ProductID;

        IF NEW.StockQty <= v_reorder THEN
            INSERT INTO REORDER_LOG (BranchNo, ProductID, StockQty, ReorderLevel)
            VALUES (NEW.BranchNo, NEW.ProductID, NEW.StockQty, v_reorder);
        END IF;
    END IF;
END //
DELIMITER ;

CREATE OR REPLACE VIEW vw_satis_ozeti AS
SELECT
    s.SaleNo,
    s.SaleDate,
    s.TotalAmount,
    CONCAT(st.FirstName, ' ', st.LastName)                               AS Kasiyer,
    b.BranchName                                                          AS Sube,
    COALESCE(CONCAT(c.FirstName, ' ', c.LastName), 'Kayıtsız Müşteri')  AS Musteri
FROM  SALE s
JOIN  STAFF    st ON s.StaffID    = st.StaffID
JOIN  BRANCH   b  ON s.BranchNo   = b.BranchNo
LEFT JOIN CUSTOMER c ON s.CustomerID = c.CustomerID;

CREATE OR REPLACE VIEW vw_stok_durumu AS
SELECT
    b.BranchName                                           AS Sube,
    p.ProductName                                          AS Urun,
    pt.TypeName                                            AS Kategori,
    ist.StockQty                                           AS Stok,
    pt.ReorderLevel                                        AS EsikDeger,
    CASE WHEN ist.StockQty <= pt.ReorderLevel
         THEN 'KRİTİK' ELSE 'NORMAL' END                   AS StokDurumu
FROM  IN_STOCK ist
JOIN  BRANCH       b  ON ist.BranchNo  = b.BranchNo
JOIN  PRODUCT      p  ON ist.ProductID = p.ProductID
JOIN  PRODUCT_TYPE pt ON p.TypeID      = pt.TypeID
ORDER BY Sube, StokDurumu DESC, Stok;

CREATE OR REPLACE VIEW vw_musteri_istatistik AS
SELECT
    c.CustomerID,
    CONCAT(c.FirstName, ' ', c.LastName)  AS AdSoyad,
    c.RegisterDate                         AS KayitTarihi,
    c.LoyaltyPoints                        AS SadakatPuani,
    COUNT(s.SaleNo)                        AS ToplamAlisveris,
    COALESCE(SUM(s.TotalAmount), 0)        AS ToplamHarcama,
    COALESCE(AVG(s.TotalAmount), 0)        AS OrtalamaHarcama
FROM  CUSTOMER c
LEFT JOIN SALE s ON c.CustomerID = s.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName, c.RegisterDate, c.LoyaltyPoints
ORDER BY ToplamHarcama DESC;

CREATE OR REPLACE VIEW vw_sube_gelir AS
SELECT
    b.BranchNo,
    b.BranchName,
    b.Location,
    COUNT(DISTINCT s.SaleNo)          AS ToplamSatis,
    COALESCE(SUM(s.TotalAmount), 0)   AS ToplamGelir,
    COALESCE(AVG(s.TotalAmount), 0)   AS OrtalamaFis
FROM  BRANCH b
LEFT JOIN SALE s ON b.BranchNo = s.BranchNo
GROUP BY b.BranchNo, b.BranchName, b.Location
ORDER BY ToplamGelir DESC;

CREATE OR REPLACE VIEW vw_en_cok_satan AS
SELECT
    p.ProductID,
    p.ProductName                                AS UrunAdi,
    pt.TypeName                                  AS Kategori,
    COUNT(DISTINCT sl.SaleNo)                    AS SatisAdedi,
    COALESCE(SUM(sl.Quantity), 0)                AS ToplamAdet,
    COALESCE(SUM(sl.Quantity * sl.UnitPrice), 0) AS ToplamCiro
FROM  PRODUCT p
JOIN  PRODUCT_TYPE pt ON p.TypeID    = pt.TypeID
LEFT JOIN SALE_LINE sl ON p.ProductID = sl.ProductID
GROUP BY p.ProductID, p.ProductName, pt.TypeName
ORDER BY ToplamCiro DESC;

INSERT INTO BRANCH (BranchNo, BranchName, Location, Phone) VALUES
(1, 'Çankaya Şubesi',  'Kızılay Cad. No:15, Çankaya, Ankara',         '(312) 425-1001'),
(2, 'Keçiören Şubesi', 'Çiçek Sok. No:8, Keçiören, Ankara',           '(312) 380-2002'),
(3, 'Mamak Şubesi',    'Yeni Mah. Atatürk Cad. No:42, Mamak, Ankara', '(312) 361-3003');

INSERT INTO STAFF (StaffID, FirstName, LastName, BirthDate, Salary, Position, Phone, SupervisorID, ManagerOfBranch) VALUES
(1,  'Ahmet',  'Kaya',   '1978-03-15', 18000.00, 'Müdür',   '(555) 101-0001', NULL, 1),
(2,  'Fatma',  'Demir',  '1982-07-22', 17500.00, 'Müdür',   '(555) 101-0002', NULL, 2),
(3,  'Mehmet', 'Yılmaz', '1980-11-08', 17000.00, 'Müdür',   '(555) 101-0003', NULL, 3),
(4,  'Ayşe',   'Çelik',  '1995-04-12',  9500.00, 'Kasiyer', '(555) 101-0004', 1,   NULL),
(5,  'Ali',    'Şahin',  '1993-09-30',  9500.00, 'Kasiyer', '(555) 101-0005', 1,   NULL),
(6,  'Zeynep', 'Kurt',   '1996-01-25',  9500.00, 'Kasiyer', '(555) 101-0006', 2,   NULL),
(7,  'Hasan',  'Arslan', '1994-06-18',  9500.00, 'Kasiyer', '(555) 101-0007', 2,   NULL),
(8,  'Elif',   'Doğan',  '1997-12-03',  9500.00, 'Kasiyer', '(555) 101-0008', 3,   NULL),
(9,  'Murat',  'Öztürk', '1992-08-14',  9500.00, 'Kasiyer', '(555) 101-0009', 3,   NULL),
(10, 'Selin',  'Aydın',  '1998-02-27',  9000.00, 'Kasiyer', '(555) 101-0010', 1,   NULL);

INSERT INTO WORKS_IN (StaffID, BranchNo, ShiftHours) VALUES
(1,1,45.0),(2,2,45.0),(3,3,45.0),
(4,1,40.0),(5,1,40.0),
(6,2,40.0),(7,2,40.0),
(8,3,40.0),(9,3,40.0),
(10,1,32.0),(10,2,8.0);

INSERT INTO PRODUCT_TYPE (TypeID, TypeName, TaxRate, ReorderLevel) VALUES
(1,'Gıda',           1.00, 50),
(2,'İçecek',         8.00, 30),
(3,'Temizlik',      18.00, 20),
(4,'Kişisel Bakım', 18.00, 15),
(5,'Atıştırmalık',   8.00, 25);

INSERT INTO PRODUCT (ProductID, Barcode, ProductName, UnitPrice, ExpiryDate, TypeID) VALUES
(1,  '8690000000001', 'Somun Ekmek 500g',        5.50, '2026-05-26', 1),
(2,  '8690000000002', 'Süt 1L (Tam Yağlı)',      18.90,'2026-06-10', 1),
(3,  '8690000000003', 'Yumurta 10lu',             44.90,'2026-06-15', 1),
(4,  '8690000000004', 'Beyaz Peynir 500g',        89.90,'2026-07-01', 1),
(5,  '8690000000005', 'Tereyağı 250g',            64.90,'2026-08-01', 1),
(6,  '8690000000006', 'Coca-Cola 1.5L',           29.90,'2026-12-31', 2),
(7,  '8690000000007', 'Su 1.5L',                   7.90,'2027-01-01', 2),
(8,  '8690000000008', 'Portakal Suyu 1L',         34.90,'2026-09-30', 2),
(9,  '8690000000009', 'Çamaşır Deterjanı 3kg',  129.90, NULL,         3),
(10, '8690000000010', 'Bulaşık Deterjanı 750ml',  42.90, NULL,         3),
(11, '8690000000011', 'Şampuan 400ml',            54.90, NULL,         4),
(12, '8690000000012', 'Diş Macunu 100ml',         24.90, NULL,         4),
(13, '8690000000013', 'Cips 150g',                19.90,'2026-11-30', 5),
(14, '8690000000014', 'Bisküvi 200g',             12.90,'2026-10-31', 5),
(15, '8690000000015', 'Çikolata 100g',            27.90,'2026-12-31', 5),
(16, '8690000000016', 'Zeytin 400g',              54.90,'2027-06-01', 1);

INSERT INTO SUPPLIER (SupplierID, SupplierName, Phone, Email, Address) VALUES
(1,'Ülker Gıda A.Ş.',          '(212) 555-1001','tedarik@ulker.com.tr', 'Kağıthane, İstanbul'),
(2,'Pınar Süt Mamülleri A.Ş.', '(232) 555-2002','info@pinar.com.tr',    'Bornova, İzmir'),
(3,'Procter & Gamble Türkiye', '(216) 555-3003','pg.tedarik@pg.com',    'Gebze, Kocaeli'),
(4,'Coca-Cola İçecek A.Ş.',    '(212) 555-4004','supply@cci.com.tr',    'Beşiktaş, İstanbul');

INSERT INTO SUPPLIED_BY (ProductID, SupplierID, SupplyPrice, SupplyDate) VALUES
(1,1, 3.20,'2026-05-01'),(2,2,12.50,'2026-05-10'),(2,1,13.00,'2026-05-12'),
(3,2,30.00,'2026-05-10'),(4,2,60.00,'2026-05-08'),(5,2,45.00,'2026-05-08'),
(6,4,18.00,'2026-05-05'),(7,4, 4.50,'2026-05-05'),(8,4,22.00,'2026-05-05'),
(9,3,85.00,'2026-04-20'),(10,3,28.00,'2026-04-20'),(11,3,35.00,'2026-04-25'),
(12,3,15.00,'2026-04-25'),(13,1,12.00,'2026-05-01'),(14,1,7.50,'2026-05-01'),
(15,1,18.00,'2026-05-01'),(16,2,38.00,'2026-05-15');

INSERT INTO IN_STOCK (BranchNo, ProductID, StockQty) VALUES

(1, 1,200),(1, 2,120),(1, 3, 80),(1, 4, 60),(1, 5, 50),(1, 6,150),(1, 7,300),
(1, 8, 90),(1, 9, 40),(1,10,100),(1,11, 60),(1,12,120),(1,13,200),(1,14,180),
(1,15,150),(1,16, 80),

(2, 1,180),(2, 2,100),(2, 3, 70),(2, 4, 50),(2, 5, 45),(2, 6,130),(2, 7,250),
(2, 8, 75),(2, 9, 35),(2,10, 90),(2,11, 50),(2,12,110),(2,13,170),(2,14,160),
(2,15,130),(2,16, 70),

(3, 1,150),(3, 2, 90),(3, 3, 60),(3, 4, 40),(3, 5, 35),(3, 6,100),(3, 7,200),
(3, 8, 60),(3, 9, 25),(3,10, 70),(3,11, 40),(3,12, 90),(3,13,140),(3,14,130),
(3,15,100),(3,16, 60);

INSERT INTO CUSTOMER (CustomerID, FirstName, LastName, Phone, Email, RegisterDate, LoyaltyPoints) VALUES
(1,'Burak',  'Yıldız', '(555) 200-0001','burak.yildiz@email.com',  '2024-01-10',1250),
(2,'Canan',  'Güler',  '(555) 200-0002','canan.guler@email.com',   '2024-02-14', 870),
(3,'Deniz',  'Akar',   '(555) 200-0003','deniz.akar@email.com',    '2024-03-05',2100),
(4,'Emre',   'Koç',    '(555) 200-0004','emre.koc@email.com',      '2024-04-20', 320),
(5,'Gamze',  'Polat',  '(555) 200-0005','gamze.polat@email.com',   '2024-06-15', 540),
(6,'İbrahim','Çetin',  '(555) 200-0006','ibrahim.cetin@email.com', '2025-01-08',  90),
(7,'Kübra',  'Erdoğan','(555) 200-0007','kubra.erdogan@email.com', '2025-03-22', 430),
(8,'Levent', 'Kaplan', '(555) 200-0008','levent.kaplan@email.com', '2025-09-01',   0);

INSERT INTO SALE (SaleNo, SaleDate, StaffID, BranchNo, CustomerID) VALUES
(1001,'2026-05-01 09:15:00',4,1,1),(1002,'2026-05-01 10:30:00',4,1,2),
(1003,'2026-05-01 11:45:00',5,1,NULL),(1004,'2026-05-02 09:00:00',6,2,3),
(1005,'2026-05-02 10:20:00',6,2,NULL),(1006,'2026-05-02 14:30:00',7,2,4),
(1007,'2026-05-03 09:30:00',8,3,5),(1008,'2026-05-03 11:00:00',8,3,NULL),
(1009,'2026-05-03 15:00:00',9,3,1),(1010,'2026-05-05 09:45:00',4,1,6),
(1011,'2026-05-05 13:00:00',5,1,3),(1012,'2026-05-06 10:15:00',6,2,7),
(1013,'2026-05-06 14:00:00',7,2,NULL),(1014,'2026-05-07 09:00:00',8,3,8),
(1015,'2026-05-07 12:30:00',9,3,2),(1016,'2026-05-10 09:00:00',4,1,NULL),
(1017,'2026-05-12 10:30:00',6,2,3),(1018,'2026-05-14 11:00:00',8,3,5),
(1019,'2026-05-20 09:30:00',5,1,1),(1020,'2026-05-22 14:00:00',7,2,NULL);

INSERT INTO SALE_LINE (SaleNo,LineNo,Quantity,UnitPrice,ProductID) VALUES
(1001,1,2, 5.50, 1),(1001,2,1,18.90, 2),(1001,3,1,44.90, 3),
(1002,1,1,89.90, 4),(1002,2,1,64.90, 5),(1002,3,2, 5.50, 1),(1002,4,1,29.90, 6),
(1003,1,3, 7.90, 7),(1003,2,2,19.90,13),
(1004,1,1,18.90, 2),(1004,2,1,44.90, 3),(1004,3,1,89.90, 4),(1004,4,2,29.90, 6),
(1005,1,1,129.90,9),(1005,2,1,42.90,10),
(1006,1,2, 7.90, 7),(1006,2,1,34.90, 8),(1006,3,3,12.90,14),
(1007,1,1,54.90,11),(1007,2,1,24.90,12),(1007,3,2,27.90,15),
(1008,1,5, 5.50, 1),(1008,2,2,18.90, 2),
(1009,1,1,89.90, 4),(1009,2,1,64.90, 5),(1009,3,2,29.90, 6),(1009,4,3, 7.90, 7),
(1010,1,2,12.90,14),(1010,2,1,19.90,13),(1010,3,1,27.90,15),
(1011,1,1,18.90, 2),(1011,2,1,44.90, 3),(1011,3,1, 5.50, 1),(1011,4,1,42.90,10),
(1012,1,2,29.90, 6),(1012,2,2, 7.90, 7),(1012,3,1,34.90, 8),
(1013,1,1,129.90,9),(1013,2,1,54.90,11),(1013,3,1,24.90,12),
(1014,1,3, 5.50, 1),(1014,2,1,18.90, 2),(1014,3,1,44.90, 3),
(1015,1,1,64.90, 5),(1015,2,1,89.90, 4),(1015,3,1,18.90, 2),(1015,4,2,19.90,13),
(1016,1,4, 7.90, 7),(1016,2,2,29.90, 6),
(1017,1,1,89.90, 4),(1017,2,1,44.90, 3),(1017,3,2, 5.50, 1),(1017,4,1,18.90, 2),
(1018,1,1,54.90,11),(1018,2,2,27.90,15),(1018,3,3,12.90,14),
(1019,1,2,18.90, 2),(1019,2,1,44.90, 3),(1019,3,1,89.90, 4),(1019,4,1,64.90, 5),
(1020,1,2,19.90,13),(1020,2,2,12.90,14),(1020,3,1,27.90,15);

INSERT INTO PAYMENT (PaymentNo, PaymentType, Amount, PaymentDate, SaleNo) VALUES
(1, 'Kredi Kartı',   74.80,'2026-05-01 09:16:00',1001),
(2, 'Nakit',        195.70,'2026-05-01 10:31:00',1002),
(3, 'Banka Kartı',   63.50,'2026-05-01 11:46:00',1003),
(4, 'Nakit',        213.50,'2026-05-02 09:01:00',1004),
(5, 'Kredi Kartı',  172.80,'2026-05-02 10:21:00',1005),
(6, 'Sadakat Puanı', 20.00,'2026-05-02 14:30:00',1006),
(7, 'Banka Kartı',   69.40,'2026-05-02 14:31:00',1006),
(8, 'Nakit',        135.60,'2026-05-03 09:31:00',1007),
(9, 'Kredi Kartı',   65.30,'2026-05-03 11:01:00',1008),
(10,'Nakit',        238.30,'2026-05-03 15:01:00',1009),
(11,'Banka Kartı',   73.60,'2026-05-05 09:46:00',1010),
(12,'Kredi Kartı',  112.20,'2026-05-05 13:01:00',1011),
(13,'Nakit',        110.50,'2026-05-06 10:16:00',1012),
(14,'Kredi Kartı',  209.70,'2026-05-06 14:01:00',1013),
(15,'Banka Kartı',   80.30,'2026-05-07 09:01:00',1014),
(16,'Nakit',        213.50,'2026-05-07 12:31:00',1015),
(17,'Kredi Kartı',   91.40,'2026-05-10 09:01:00',1016),
(18,'Banka Kartı',  164.70,'2026-05-12 10:31:00',1017),
(19,'Nakit',        149.40,'2026-05-14 11:01:00',1018),
(20,'Kredi Kartı',  237.50,'2026-05-20 09:31:00',1019),
(21,'Sadakat Puanı', 30.00,'2026-05-22 14:00:00',1020),
(22,'Nakit',         63.50,'2026-05-22 14:01:00',1020);

SELECT
    st.StaffID,
    CONCAT(st.FirstName,' ',st.LastName)                                  AS AdSoyad,
    st.Position                                                            AS Pozisyon,
    st.Salary                                                              AS Maas,
    b.BranchName                                                           AS CalistiguSube,
    COALESCE(CONCAT(sp.FirstName,' ',sp.LastName),'(Üst Yönetici Yok)')  AS Yoneticisi
FROM  STAFF st
JOIN  WORKS_IN wi ON st.StaffID   = wi.StaffID
JOIN  BRANCH   b  ON wi.BranchNo  = b.BranchNo
LEFT JOIN STAFF sp ON st.SupervisorID = sp.StaffID
ORDER BY b.BranchName, st.Position, st.LastName;

SELECT
    b.BranchName                           AS Sube,
    b.Location                             AS Konum,
    b.Phone                                AS SubeTelefon,
    CONCAT(st.FirstName,' ',st.LastName)   AS SubeMuduru,
    st.Phone                               AS MudurTelefon
FROM  BRANCH b
JOIN  STAFF st ON st.ManagerOfBranch = b.BranchNo;

SELECT
    b.BranchName                       AS Sube,
    p.ProductName                      AS Urun,
    pt.TypeName                        AS Kategori,
    ist.StockQty                       AS MevcutStok,
    pt.ReorderLevel                    AS SiparisSiniri,
    pt.ReorderLevel - ist.StockQty    AS Eksik
FROM  IN_STOCK ist
JOIN  BRANCH       b  ON ist.BranchNo  = b.BranchNo
JOIN  PRODUCT      p  ON ist.ProductID = p.ProductID
JOIN  PRODUCT_TYPE pt ON p.TypeID      = pt.TypeID
WHERE ist.StockQty <= pt.ReorderLevel
ORDER BY Eksik DESC;

SELECT
    st.StaffID,
    CONCAT(st.FirstName,' ',st.LastName)  AS Kasiyer,
    b.BranchName                          AS Sube,
    COUNT(s.SaleNo)                       AS FisSayisi,
    SUM(s.TotalAmount)                    AS ToplamCiro,
    ROUND(AVG(s.TotalAmount),2)           AS OrtalamaFis
FROM  STAFF st
JOIN  SALE   s ON st.StaffID = s.StaffID
JOIN  BRANCH b ON s.BranchNo = b.BranchNo
GROUP BY st.StaffID, st.FirstName, st.LastName, b.BranchName
ORDER BY ToplamCiro DESC;

SELECT
    b.BranchName                          AS Sube,
    DATE_FORMAT(s.SaleDate,'%Y-%m')       AS Ay,
    COUNT(s.SaleNo)                       AS FisSayisi,
    SUM(s.TotalAmount)                    AS ToplamCiro,
    ROUND(AVG(s.TotalAmount),2)           AS OrtalamaFis,
    MAX(s.TotalAmount)                    AS EnBuyukFis
FROM  SALE s
JOIN  BRANCH b ON s.BranchNo = b.BranchNo
GROUP BY b.BranchName, DATE_FORMAT(s.SaleDate,'%Y-%m')
ORDER BY Sube, Ay;

SELECT
    p.ProductName                    AS Urun,
    pt.TypeName                      AS Kategori,
    SUM(sl.Quantity)                 AS ToplamAdet,
    SUM(sl.Quantity * sl.UnitPrice)  AS ToplamCiro,
    COUNT(DISTINCT sl.SaleNo)        AS FisSayisi
FROM  SALE_LINE sl
JOIN  PRODUCT      p  ON sl.ProductID = p.ProductID
JOIN  PRODUCT_TYPE pt ON p.TypeID     = pt.TypeID
GROUP BY p.ProductName, pt.TypeName
ORDER BY ToplamAdet DESC
LIMIT 10;

SELECT
    c.CustomerID,
    CONCAT(c.FirstName,' ',c.LastName)  AS Musteri,
    c.LoyaltyPoints                     AS SadakatPuani,
    COUNT(s.SaleNo)                     AS AlisverisAdedi,
    COALESCE(SUM(s.TotalAmount),0)      AS ToplamHarcama
FROM  CUSTOMER c
LEFT JOIN SALE s ON c.CustomerID = s.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName, c.LoyaltyPoints
ORDER BY c.LoyaltyPoints DESC
LIMIT 5;

SELECT
    p.ProductName                                                AS Urun,
    pt.TypeName                                                  AS Kategori,
    su.SupplierName                                              AS Tedarikci,
    sb.SupplyPrice                                               AS TedarikFiyati,
    p.UnitPrice                                                  AS SatisFiyati,
    ROUND((p.UnitPrice-sb.SupplyPrice)/sb.SupplyPrice*100,1)    AS KarMarjiPct
FROM  SUPPLIED_BY sb
JOIN  PRODUCT      p  ON sb.ProductID  = p.ProductID
JOIN  SUPPLIER     su ON sb.SupplierID = su.SupplierID
JOIN  PRODUCT_TYPE pt ON p.TypeID      = pt.TypeID
ORDER BY KarMarjiPct DESC;

SELECT
    p.ProductName                                          AS Urun,
    COUNT(sb.SupplierID)                                   AS TedarikciSayisi,
    GROUP_CONCAT(su.SupplierName SEPARATOR ' | ')         AS Tedarikciler
FROM  PRODUCT      p
JOIN  SUPPLIED_BY sb ON p.ProductID   = sb.ProductID
JOIN  SUPPLIER    su ON sb.SupplierID = su.SupplierID
GROUP BY p.ProductName
HAVING COUNT(sb.SupplierID) > 1;

SELECT
    COALESCE(CONCAT(m.FirstName,' ',m.LastName),'
    CONCAT(p.FirstName,' ',p.LastName)                                  AS Personel,
    p.Position                                                           AS Pozisyon,
    p.Salary                                                             AS Maas
FROM  STAFF p
LEFT JOIN STAFF m ON p.SupervisorID = m.StaffID
ORDER BY (m.LastName IS NOT NULL), m.LastName, p.LastName;

SELECT
    s.SaleNo, s.SaleDate, s.TotalAmount,
    CONCAT(st.FirstName,' ',st.LastName)  AS Kasiyer,
    b.BranchName                          AS Sube
FROM  SALE s
JOIN  STAFF  st ON s.StaffID  = st.StaffID
JOIN  BRANCH b  ON s.BranchNo = b.BranchNo
WHERE s.CustomerID IS NULL
ORDER BY s.SaleDate;

SELECT
    py.PaymentType                                                AS OdemeTuru,
    COUNT(py.PaymentNo)                                          AS OdemeSayisi,
    SUM(py.Amount)                                               AS ToplamTutar,
    ROUND(SUM(py.Amount)*100.0 / SUM(SUM(py.Amount)) OVER(),2)  AS YuzdePay
FROM  PAYMENT py
GROUP BY py.PaymentType
ORDER BY ToplamTutar DESC;

SELECT
    p.ProductName                          AS Urun,
    pt.TypeName                            AS Kategori,
    p.ExpiryDate                           AS SKT,
    DATEDIFF(p.ExpiryDate, CURRENT_DATE)  AS KalanGun
FROM  PRODUCT p
JOIN  PRODUCT_TYPE pt ON p.TypeID = pt.TypeID
WHERE p.ExpiryDate IS NOT NULL
  AND p.ExpiryDate BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL 30 DAY
ORDER BY p.ExpiryDate;

SELECT p.ProductID, p.ProductName AS Urun, pt.TypeName AS Kategori, p.UnitPrice AS Fiyat
FROM  PRODUCT p
JOIN  PRODUCT_TYPE pt ON p.TypeID = pt.TypeID
WHERE NOT EXISTS (SELECT 1 FROM SALE_LINE sl WHERE sl.ProductID = p.ProductID);

SELECT
    CONCAT(c.FirstName,' ',c.LastName)  AS Musteri,
    SUM(s.TotalAmount)                  AS ToplamHarcama
FROM  CUSTOMER c
JOIN  SALE s ON c.CustomerID = s.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName
HAVING SUM(s.TotalAmount) > (
    SELECT AVG(toplam) FROM (
        SELECT SUM(TotalAmount) AS toplam FROM SALE
        WHERE CustomerID IS NOT NULL GROUP BY CustomerID
    ) t
)
ORDER BY ToplamHarcama DESC;

SELECT
    pt.TypeName                             AS Kategori,
    SUM(ist.StockQty)                       AS ToplamStokAdet,
    SUM(ist.StockQty * p.UnitPrice)         AS ToplamStokDegeri,
    CONCAT(ROUND(pt.TaxRate,2), '%')        AS KDVOrani
FROM  IN_STOCK ist
JOIN  PRODUCT      p  ON ist.ProductID = p.ProductID
JOIN  PRODUCT_TYPE pt ON p.TypeID      = pt.TypeID
GROUP BY pt.TypeName, pt.TaxRate
ORDER BY ToplamStokDegeri DESC;

SELECT
    CONCAT(st.FirstName,' ',st.LastName)       AS Personel,
    st.Position                                 AS Pozisyon,
    COUNT(wi.BranchNo)                         AS SubeSayisi,
    GROUP_CONCAT(b.BranchName SEPARATOR ', ')  AS Subeler,
    SUM(wi.ShiftHours)                        AS ToplamHaftalikSaat
FROM  STAFF    st
JOIN  WORKS_IN wi ON st.StaffID  = wi.StaffID
JOIN  BRANCH    b ON wi.BranchNo  = b.BranchNo
GROUP BY st.StaffID, st.FirstName, st.LastName, st.Position
HAVING COUNT(wi.BranchNo) > 1;

SELECT
    DATE(s.SaleDate)              AS Tarih,
    COUNT(s.SaleNo)               AS SatisSayisi,
    SUM(s.TotalAmount)            AS GunlukCiro,
    ROUND(AVG(s.TotalAmount),2)   AS OrtalamaFis
FROM  SALE s
WHERE s.SaleDate >= '2026-05-25' - INTERVAL 30 DAY
GROUP BY DATE(s.SaleDate)
ORDER BY Tarih DESC;

SELECT
    sl.LineNo                     AS Kalem,
    p.ProductName                 AS Urun,
    pt.TypeName                   AS Kategori,
    sl.Quantity                   AS Adet,
    sl.UnitPrice                  AS BirimFiyat,
    sl.Quantity * sl.UnitPrice    AS AraToplam
FROM  SALE_LINE sl
JOIN  PRODUCT      p  ON sl.ProductID = p.ProductID
JOIN  PRODUCT_TYPE pt ON p.TypeID     = pt.TypeID
WHERE sl.SaleNo = 1009
ORDER BY sl.LineNo;

SELECT
    su.SupplierName          AS Tedarikci,
    COUNT(sb.ProductID)      AS UrunSayisi,
    SUM(sb.SupplyPrice)      AS ToplamTedarikDegeri,
    MAX(sb.SupplyDate)       AS SonTedarikTarihi
FROM  SUPPLIER    su
JOIN  SUPPLIED_BY sb ON su.SupplierID = sb.SupplierID
GROUP BY su.SupplierID, su.SupplierName
ORDER BY UrunSayisi DESC;

SELECT 'Personel' AS Tip, CONCAT(FirstName,' ',LastName) AS AdSoyad, Phone AS Telefon
FROM   STAFF    WHERE Phone IS NOT NULL
UNION
SELECT 'Müşteri',          CONCAT(FirstName,' ',LastName),           Phone
FROM   CUSTOMER WHERE Phone IS NOT NULL
ORDER BY Tip, AdSoyad;

SELECT Sube, Urun, ToplamAdet, Sira
FROM (
    SELECT
        b.BranchName      AS Sube,
        p.ProductName     AS Urun,
        SUM(sl.Quantity)  AS ToplamAdet,
        RANK() OVER (PARTITION BY b.BranchNo ORDER BY SUM(sl.Quantity) DESC) AS Sira
    FROM  SALE_LINE sl
    JOIN  SALE    s ON sl.SaleNo    = s.SaleNo
    JOIN  BRANCH  b ON s.BranchNo   = b.BranchNo
    JOIN  PRODUCT p ON sl.ProductID = p.ProductID
    GROUP BY b.BranchNo, b.BranchName, p.ProductID, p.ProductName
) r
WHERE Sira <= 3
ORDER BY Sube, Sira;

INSERT INTO SALE (SaleNo, SaleDate, StaffID, BranchNo, CustomerID)
VALUES (1021, CURRENT_TIMESTAMP, 4, 1, 2);

INSERT INTO SALE_LINE (SaleNo, LineNo, Quantity, UnitPrice, ProductID) VALUES
(1021, 1, 2,  5.50, 1),
(1021, 2, 1, 18.90, 2);

INSERT INTO PAYMENT (PaymentNo, PaymentType, Amount, PaymentDate, SaleNo)
VALUES (23, 'Banka Kartı', 29.90, CURRENT_TIMESTAMP, 1021);

INSERT INTO SALE (SaleNo, SaleDate, StaffID, BranchNo, CustomerID)
VALUES (1022, CURRENT_TIMESTAMP, 6, 2, 3);

INSERT INTO SALE_LINE (SaleNo, LineNo, Quantity, UnitPrice, ProductID) VALUES
(1022, 1, 1, 19.90, 13),
(1022, 2, 1, 12.90, 14);

INSERT INTO PAYMENT (PaymentNo, PaymentType, Amount, PaymentDate, SaleNo) VALUES
(24, 'Sadakat Puanı', 10.00, CURRENT_TIMESTAMP, 1022),
(25, 'Kredi Kartı',   22.80, CURRENT_TIMESTAMP, 1022);

UPDATE CUSTOMER SET LoyaltyPoints = LoyaltyPoints - 10 WHERE CustomerID = 3;

SELECT * FROM vw_stok_durumu       WHERE StokDurumu = 'KRİTİK';
SELECT * FROM vw_satis_ozeti       ORDER BY SaleDate DESC LIMIT 5;
SELECT * FROM vw_musteri_istatistik;
SELECT * FROM vw_sube_gelir;
SELECT * FROM vw_en_cok_satan      LIMIT 5;
SELECT * FROM REORDER_LOG          ORDER BY AlertTime;

SELECT
    'a) Negatif Stok'      AS Test,
    b.BranchName           AS Sube,
    p.ProductName          AS Urun,
    ist.StockQty           AS Stok
FROM  IN_STOCK ist
JOIN  BRANCH  b ON ist.BranchNo  = b.BranchNo
JOIN  PRODUCT p ON ist.ProductID = p.ProductID
WHERE ist.StockQty < 0;

SELECT
    'b) TotalAmount Tutarsızlığı'                             AS Test,
    s.SaleNo,
    s.TotalAmount                                             AS FistekiToplam,
    ROUND(COALESCE(SUM(sl.Quantity * sl.UnitPrice),0),2)     AS HesaplananToplam,
    CASE WHEN ABS(s.TotalAmount
                  - COALESCE(SUM(sl.Quantity * sl.UnitPrice),0)) < 0.01
         THEN 'OK' ELSE 'HATA' END                           AS Durum
FROM  SALE s
LEFT JOIN SALE_LINE sl ON s.SaleNo = sl.SaleNo
GROUP BY s.SaleNo, s.TotalAmount
HAVING Durum = 'HATA';

SELECT
    'c) Ödeme Uyumsuzluğu'                                   AS Test,
    s.SaleNo,
    s.TotalAmount                                             AS FisToplami,
    ROUND(COALESCE(SUM(p.Amount),0),2)                       AS OdemeToplami,
    CASE WHEN ABS(s.TotalAmount
                  - COALESCE(SUM(p.Amount),0)) < 0.01
         THEN 'OK' ELSE 'UYUMSUZ' END                        AS Durum
FROM  SALE s
LEFT JOIN PAYMENT p ON s.SaleNo = p.SaleNo
GROUP BY s.SaleNo, s.TotalAmount
HAVING Durum = 'UYUMSUZ';

SELECT
    'd) Kritik Stok'                   AS Test,
    b.BranchName                       AS Sube,
    p.ProductName                      AS Urun,
    ist.StockQty                       AS MevcutStok,
    pt.ReorderLevel                    AS Esik,
    pt.ReorderLevel - ist.StockQty    AS Eksik
FROM  IN_STOCK ist
JOIN  BRANCH       b  ON ist.BranchNo  = b.BranchNo
JOIN  PRODUCT      p  ON ist.ProductID = p.ProductID
JOIN  PRODUCT_TYPE pt ON p.TypeID      = pt.TypeID
WHERE ist.StockQty <= pt.ReorderLevel
ORDER BY Eksik DESC;

SELECT 'e) SALE_LINE → SALE orphan'    AS Test, COUNT(*) AS Adet
FROM   SALE_LINE sl LEFT JOIN SALE s ON sl.SaleNo = s.SaleNo
WHERE  s.SaleNo IS NULL
UNION ALL
SELECT 'e) PAYMENT → SALE orphan',     COUNT(*)
FROM   PAYMENT p LEFT JOIN SALE s ON p.SaleNo = s.SaleNo
WHERE  s.SaleNo IS NULL
UNION ALL
SELECT 'e) SALE → STAFF orphan',       COUNT(*)
FROM   SALE s LEFT JOIN STAFF st ON s.StaffID = st.StaffID
WHERE  st.StaffID IS NULL
UNION ALL
SELECT 'e) SALE → BRANCH orphan',      COUNT(*)
FROM   SALE s LEFT JOIN BRANCH b ON s.BranchNo = b.BranchNo
WHERE  b.BranchNo IS NULL
UNION ALL
SELECT 'e) IN_STOCK → PRODUCT orphan', COUNT(*)
FROM   IN_STOCK ist LEFT JOIN PRODUCT p ON ist.ProductID = p.ProductID
WHERE  p.ProductID IS NULL;

SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
