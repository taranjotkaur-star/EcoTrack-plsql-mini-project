SET SERVEROUTPUT ON;

-- 1. Create the location table

CREATE TABLE Collection_Locations (
    Location_ID NUMBER PRIMARY KEY,
    Location_Name VARCHAR2(100) NOT NULL,
    Area_Name VARCHAR2(100) NOT NULL
);

-- 2. Create the waste category table

CREATE TABLE Waste_Categories (
    Category_ID NUMBER PRIMARY KEY,
    Category_Name VARCHAR2(50) NOT NULL,
    Is_Recyclable CHAR(1) CHECK (Is_Recyclable IN ('Y', 'N'))
);

-- 3. Create the waste collection table

CREATE TABLE Waste_Collections (
    Collection_ID NUMBER PRIMARY KEY,
    Location_ID NUMBER NOT NULL,
    Category_ID NUMBER NOT NULL,
    Quantity_Kg NUMBER(10,2) NOT NULL,
    Collection_Date DATE DEFAULT SYSDATE,
    CONSTRAINT fk_location
        FOREIGN KEY (Location_ID)
        REFERENCES Collection_Locations(Location_ID),
    CONSTRAINT fk_category
        FOREIGN KEY (Category_ID)
        REFERENCES Waste_Categories(Category_ID),
    CONSTRAINT chk_quantity
        CHECK (Quantity_Kg > 0)
);
-- Insert collection locations

INSERT INTO Collection_Locations
VALUES (1, 'Green Park', 'North Area');

INSERT INTO Collection_Locations
VALUES (2, 'City Market', 'Central Area');

INSERT INTO Collection_Locations
VALUES (3, 'College Road', 'South Area');


-- Insert waste categories

INSERT INTO Waste_Categories
VALUES (1, 'Plastic', 'Y');

INSERT INTO Waste_Categories
VALUES (2, 'Paper', 'Y');

INSERT INTO Waste_Categories
VALUES (3, 'Metal', 'Y');

INSERT INTO Waste_Categories
VALUES (4, 'Organic', 'N');

INSERT INTO Waste_Categories
VALUES (5, 'Mixed Waste', 'N');


-- Insert initial collection records

INSERT INTO Waste_Collections
VALUES (1, 1, 1, 25, DATE '2026-10-20');

INSERT INTO Waste_Collections
VALUES (2, 1, 2, 15, DATE '2026-10-20');

INSERT INTO Waste_Collections
VALUES (3, 2, 3, 20, DATE '2026-10-21');

INSERT INTO Waste_Collections
VALUES (4, 2, 4, 30, DATE '2026-10-21');

INSERT INTO Waste_Collections
VALUES (5, 3, 1, 10, DATE '2026-10-22');

COMMIT;
CREATE OR REPLACE TRIGGER trg_validate_waste
BEFORE INSERT OR UPDATE OF Quantity_Kg
ON Waste_Collections
FOR EACH ROW
BEGIN
    IF :NEW.Quantity_Kg <= 0 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Waste quantity must be greater than zero.'
        );
    END IF;
END;
/
CREATE OR REPLACE PROCEDURE Add_Waste_Collection (
    p_Collection_ID IN NUMBER,
    p_Location_ID IN NUMBER,
    p_Category_ID IN NUMBER,
    p_Quantity_Kg IN NUMBER
)
IS
BEGIN
    IF p_Quantity_Kg IS NULL OR p_Quantity_Kg <= 0 THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Quantity must be greater than zero.'
        );
    END IF;

    INSERT INTO Waste_Collections (
        Collection_ID,
        Location_ID,
        Category_ID,
        Quantity_Kg,
        Collection_Date
    )
    VALUES (
        p_Collection_ID,
        p_Location_ID,
        p_Category_ID,
        p_Quantity_Kg,
        SYSDATE
    );

    DBMS_OUTPUT.PUT_LINE(
        'Waste collection record added successfully.'
    );

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE(
            'Error: Collection ID already exists.'
        );

    WHEN OTHERS THEN
        IF SQLCODE = -2291 THEN
            DBMS_OUTPUT.PUT_LINE(
                'Error: Invalid location ID or category ID.'
            );
        ELSE
            RAISE;
        END IF;
END;
/
BEGIN
    Add_Waste_Collection(6, 1, 1, 12);
END;
/
CREATE OR REPLACE FUNCTION Calculate_Recycling_Percentage
RETURN NUMBER
IS
    v_Total_Waste NUMBER;
    v_Recyclable_Waste NUMBER;
BEGIN
    SELECT NVL(SUM(Quantity_Kg), 0)
    INTO v_Total_Waste
    FROM Waste_Collections;

    SELECT NVL(SUM(wc.Quantity_Kg), 0)
    INTO v_Recyclable_Waste
    FROM Waste_Collections wc
    JOIN Waste_Categories c
        ON wc.Category_ID = c.Category_ID
    WHERE c.Is_Recyclable = 'Y';

    IF v_Total_Waste = 0 THEN
        RETURN 0;
    END IF;

    RETURN ROUND(
        (v_Recyclable_Waste / v_Total_Waste) * 100,
        2
    );
END;
/
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        'Recycling Percentage: ' ||
        Calculate_Recycling_Percentage() || '%'
    );
END;
/
CREATE OR REPLACE PROCEDURE Display_Waste_Collections
IS
    CURSOR waste_cursor IS
        SELECT
            wc.Collection_ID,
            l.Location_Name,
            c.Category_Name,
            wc.Quantity_Kg,
            wc.Collection_Date
        FROM Waste_Collections wc
        JOIN Collection_Locations l
            ON wc.Location_ID = l.Location_ID
        JOIN Waste_Categories c
            ON wc.Category_ID = c.Category_ID
        ORDER BY wc.Collection_ID;

BEGIN
    DBMS_OUTPUT.PUT_LINE('SMART WASTE COLLECTION REPORT');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');

    FOR rec IN waste_cursor LOOP
        DBMS_OUTPUT.PUT_LINE(
            'ID: ' || rec.Collection_ID ||
            ' | Location: ' || rec.Location_Name ||
            ' | Type: ' || rec.Category_Name ||
            ' | Quantity: ' || rec.Quantity_Kg || ' kg'
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            'Error displaying collection records: ' || SQLERRM
        );
END;
/
BEGIN
    Display_Waste_Collections;
END;
/
SELECT SUM(Quantity_Kg) AS Total_Waste_Kg
FROM Waste_Collections;
SELECT
    c.Category_Name,
    SUM(wc.Quantity_Kg) AS Total_Quantity_Kg
FROM Waste_Collections wc
JOIN Waste_Categories c
    ON wc.Category_ID = c.Category_ID
GROUP BY c.Category_Name
ORDER BY Total_Quantity_Kg DESC;