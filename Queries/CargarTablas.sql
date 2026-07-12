--Creacion de Base de Dato
CREATE DATABASE BD_GER;
USE BD_GER
--Creacion de Tablas
--1.Tabla Customer
IF OBJECT_ID('Customer','U') IS NOT NULL
    DROP TABLE Customer

CREATE TABLE Customer (
    CustomerKey NVARCHAR(10) PRIMARY KEY,
    Gender      NVARCHAR(10),
    Name        NVARCHAR(50),
    City        NVARCHAR(50),
    State_Code  NVARCHAR(50),
    State       NVARCHAR(50),
    Zip_Code    NVARCHAR(10),
    Country     NVARCHAR(50),
    Continent   NVARCHAR(50),
    Birthday    DATE
);


BULK INSERT Customer
FROM 'D:\Data_proyecto_SQL\Customers.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,          
    FIELDTERMINATOR = ',',  
    ROWTERMINATOR = '\n' 
);
--2.Tabla Product
IF OBJECT_ID('Product','U') IS NOT NULL
    DROP TABLE  Product

CREATE TABLE Product (
    ProductKey      NVARCHAR(10) PRIMARY KEY,
    Name            NVARCHAR(100),
    Brand           NVARCHAR(50),
    Color           NVARCHAR(50),
    Unit_Costo_USD  NVARCHAR(50),
    Unit_Price_USD  NVARCHAR(50),
    SubcategoryKey  NVARCHAR(10),
    Subcategory     NVARCHAR(50),
    CategoryKey     NVARCHAR(50),
    Category        NVARCHAR(50)
);

BULK INSERT Product
FROM 'D:\Data_proyecto_SQL\Products.csv' -- Reemplaza con la ruta real
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,           -- Ignora el encabezado del CSV
    FIELDTERMINATOR = ',',  -- Cambia por ';' si tu CSV usa punto y coma
    ROWTERMINATOR = '\n' -- Salto de línea estándar (LF) o '\n'
);


--3.Tabla Store
IF OBJECT_ID('Store','U') IS NOT NULL
    DROP TABLE  Store

CREATE TABLE Store (
    StoreKey        NVARCHAR(10) PRIMARY KEY,
    Country         NVARCHAR(100),
    State           NVARCHAR(50),
    SquareMeters    NVARCHAR(50),
    OpenDate        date
);

BULK INSERT Store
FROM 'D:\Data_proyecto_SQL\Stores.csv' -- Reemplaza con la ruta real
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,           -- Ignora el encabezado del CSV
    FIELDTERMINATOR = ',',  -- Cambia por ';' si tu CSV usa punto y coma
    ROWTERMINATOR = '\n' -- Salto de línea estándar (LF) o '\n'
);

--4. Tabla Exchange_Rates
IF OBJECT_ID('Exchange_Rates','U') IS NOT NULL
    DROP TABLE  Exchange_Rates

CREATE TABLE Exchange_Rates (
    Date       date,
    Currency   NVARCHAR(20),
    Exchange  DECIMAL(10,5)
);

BULK INSERT Exchange_Rates
FROM 'D:\Data_proyecto_SQL\Exchange_Rates.csv' -- Reemplaza con la ruta real
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,           -- Ignora el encabezado del CSV
    FIELDTERMINATOR = ',',  -- Cambia por ';' si tu CSV usa punto y coma
    ROWTERMINATOR = '\n' -- Salto de línea estándar (LF) o '\n'
);


--5. Tabla Hechos  Sales
IF OBJECT_ID('Sales','U') IS NOT NULL
    DROP TABLE  Sales

CREATE TABLE Sales (
    Order_Number          NVARCHAR(1000) ,
    Line                  NVARCHAR(20),
    Order_Date            DATE,
    Delivery_Date         DATE,
    CustomerKey           NVARCHAR(10),
    StoreKey              NVARCHAR(10),
    ProductKey            NVARCHAR(10),
    Quantity              INT,
    Currency              NVARCHAR(20)
);

BULK INSERT Sales
FROM 'D:\Data_proyecto_SQL\Sales.csv' -- Reemplaza con la ruta real
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,           -- Ignora el encabezado del CSV
    FIELDTERMINATOR = ',',  -- Cambia por ';' si tu CSV usa punto y coma
    ROWTERMINATOR = '\n' -- Salto de línea estándar (LF) o '\n'
);

---Limpieza y normalización de tabla Productos
UPDATE Product
SET Unit_Costo_USD=TRIM(REPLACE(REPLACE(Unit_Costo_USD,'$',''),',','')),
    Unit_Price_USD=TRIM(REPLACE(REPLACE(Unit_Price_USD,'$',''),',',''));

--Validamos que no haya ningun valor perdido
SELECT Unit_Costo_USD, Unit_Price_USD
FROM Product
WHERE TRY_CONVERT(DECIMAL(10,3),Unit_Costo_USD) IS NULL
   OR TRY_CONVERT(DECIMAL(10,3),Unit_Price_USD) IS NULL;

ALTER TABLE Product
ALTER COLUMN Unit_Costo_USD DECIMAL(10,3);

ALTER TABLE Product
ALTER COLUMN Unit_Price_USD DECIMAL(10,3);
--Insertar llave primaria en Sales,Como buena practica
--Validamos que es unica la combinacion order_number,line
SELECT ORDER_NUMBER,LINE,
       COUNT(*)
FROM Sales
GROUP BY Order_Number,LINE
HAVING COUNT(*)>1;

SELECT ORDER_NUMBER,LINE
FROM Sales
where Order_Number is null or line is null;

ALTER TABLE SALES
ALTER COLUMN Order_Number NVARCHAR(100) NOT NULL;
ALTER TABLE SALES
ALTER COLUMN Line NVARCHAR(20) NOT NULL;

ALTER TABLE Sales
ADD CONSTRAINT PK_Sales PRIMARY KEY (Order_Number, Line);


