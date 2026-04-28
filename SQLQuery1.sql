--ЗАДАНИЕ 1

CREATE DATABASE SalesDB
USE SalesDB

CREATE TABLE Customers(
	CustomerID INT IDENTITY(1,1) PRIMARY KEY,
	FullName NVARCHAR(100) NOT NULL,
	Email NVARCHAR(100) UNIQUE NOT NULL,
	RegistrationDate DATETIME NOT NULL DEFAULT GETDATE()
)

CREATE TABLE Orders(
	OrderID INT IDENTITY(1,1) PRIMARY KEY,
	CustomerID INT NOT NULL,
	OrderTotal FLOAT NOT NULL CHECK (OrderTotal > 0),
	OrderDate DATETIME NOT NULL DEFAULT GETDATE(),
	[Status] NVARCHAR(20) NOT NULL DEFAULT 'НОВЫЙ',
	CONSTRAINT FK_1 FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
)



CREATE DATABASE LogisticsDB
USE LogisticsDB

CREATE TABLE Warehouses(
	WarehousesID INT IDENTITY(1,1) PRIMARY KEY,
	[Location] NVARCHAR(100) UNIQUE NOT NULL,
	Capacity FLOAT NOT NULL,
	ManagerContact NVARCHAR(50) NOT NULL DEFAULT 'НЕ НАЗНАЧЕН',
	CreatedDate DATETIME NOT NULL DEFAULT GETDATE()
)

CREATE TABLE Shipments(
	ShipmentID INT IDENTITY(1,1) PRIMARY KEY,
	WarehousesID INT NOT NULL ,
	OrderID INT NOT NULL, 
	TrackingCode NVARCHAR(50) UNIQUE NOT NULL,
	[Weight] FLOAT NOT NULL,
	DispatchDate DATETIME NULL,
	[STATUS] NVARCHAR(20) NOT NULL DEFAULT 'ОЖИДАЕТ ОТПРАВКИ',
	CONSTRAINT FK_2 FOREIGN KEY (WarehousesID) REFERENCES Warehouses(WarehousesID)
)

--ЛОГИЧЕСКАЯ ССЫЛКА НА ЗАКАЗ ИЗ SalesDB

GO

CREATE TRIGGER TR_Shipments_CheckOrder
ON Shipments
FOR INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted i
        LEFT JOIN SalesDB.dbo.Orders o ON i.OrderID = o.OrderID
        WHERE o.OrderID IS NULL
    )
    BEGIN
        RAISERROR ('Ошибка: Указанный OrderID не существует в SalesDB.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;


--ЗАДАНИЕ 2

-- Функции для базы SalesDB
USE SalesDB;
GO

-- 2.1. Функция для получения списка всех клиентов
CREATE FUNCTION dbo.fn_GetCustomers()
RETURNS TABLE
AS
RETURN 
(
    SELECT CustomerID, FullName, Email, RegistrationDate
    FROM dbo.Customers
);
GO

-- 2.2. Функция для получения заказов по статусу
CREATE FUNCTION dbo.fn_GetOrdersByStatus(@status NVARCHAR(20))
RETURNS TABLE
AS
RETURN 
(
    SELECT OrderID, CustomerID, OrderTotal, OrderDate, [Status]
    FROM dbo.Orders
    WHERE [Status] = @status
);
GO

--Функции для базы LogisticsDB
USE LogisticsDB;
GO

--Функция для получения списка всех складов
CREATE FUNCTION dbo.fn_GetWarehouses()
RETURNS TABLE
AS
RETURN 
(
    SELECT WarehousesID, [Location], Capacity, ManagerContact, CreatedDate
    FROM dbo.Warehouses
);
GO

--Функция для получения отгрузок по ID склада
CREATE FUNCTION dbo.fn_GetShipmentsByWarehouse(@wid INT)
RETURNS TABLE
AS
RETURN 
(
    SELECT ShipmentID, WarehousesID, OrderID, TrackingCode, [Weight], DispatchDate, [STATUS]
    FROM dbo.Shipments
    WHERE WarehousesID = @wid
);
GO

--2.3.Выборки

--SalesDB
SELECT * FROM SalesDB.dbo.fn_GetCustomers();

SELECT * FROM SalesDB.dbo.fn_GetOrdersByStatus('НОВЫЙ');

--LogisticsDB
SELECT * FROM LogisticsDB.dbo.fn_GetWarehouses();

SELECT * FROM LogisticsDB.dbo.fn_GetShipmentsByWarehouse(1); 
SELECT * FROM LogisticsDB.dbo.fn_GetShipmentsByWarehouse(2); 



--ЗАДАНИЕ 3

USE SalesDB

CREATE TRIGGER trg_Sales
ON Orders
AFTER INSERT, UPDATE
AS
BEGIN
	BEGIN TRANSACTION
		BEGIN TRY
			INSERT INTO LogisticsDB.dbo.Shipments(WarehousesID, OrderID, TrackingCode, DispatchDate, [Weight], [Status])
				SELECT 1, OrderID,'TRK_' + CONVERT(NVARCHAR(46), NEWID()), NULL, 1, 'Ожидает отправки' FROM inserted
				WHERE inserted.[Status] = 'Подтвержден'
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
			THROW
		END CATCH
END


--ЗАДАНИЕ 4

--4.1 

USE SalesDB;
GO

CREATE PROCEDURE sp_AddCustomer
    @Name NVARCHAR(100),
    @Email NVARCHAR(100)
AS
BEGIN
    INSERT INTO Customers (FullName, Email)
    VALUES (@Name, @Email);
END;
GO

CREATE PROCEDURE sp_AddOrder
    @CustID INT,
    @Total FLOAT
AS
BEGIN
    INSERT INTO Orders (CustomerID, OrderTotal)
    VALUES (@CustID, @Total);
END;
GO

INSERT INTO LogisticsDB.dbo.Warehouses ([Location], Capacity) VALUES ('Склад №1', 5000);

EXEC sp_AddCustomer @Name = 'Алексей Петров', @Email = 'alex@mail.ru';

EXEC sp_AddOrder @CustID = 1, @Total = 500.0;

--4.2 

UPDATE SalesDB.dbo.Orders SET [Status] = 'Подтвержден' WHERE OrderID = 1;

SELECT * FROM LogisticsDB.dbo.fn_GetShipmentsByWarehouse(1);

--4.3 

BEGIN TRY
    EXEC sp_AddOrder @CustID = 1, @Total = -100; 
END TRY
BEGIN CATCH
    PRINT 'Сумма заказа не может быть отрицательной!';
END CATCH;

BEGIN TRY
    EXEC sp_AddCustomer @Name = 'Клон', @Email = 'alex@mail.ru'; 
END TRY
BEGIN CATCH
    PRINT 'Такой Email уже есть в базе!';
END CATCH;

--4.4 

-- Посмотреть всех клиентов
SELECT * FROM SalesDB.dbo.fn_GetCustomers();

-- Посмотреть только подтвержденные заказы
SELECT * FROM SalesDB.dbo.fn_GetOrdersByStatus('Подтвержден');

-- Посмотреть отгрузки на складе
SELECT * FROM LogisticsDB.dbo.fn_GetShipmentsByWarehouse(1);

--4.5 

BEGIN TRY
    BEGIN TRANSACTION;
        
        UPDATE SalesDB.dbo.Orders 
        SET OrderTotal = OrderTotal / 0 
        WHERE OrderID = 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Произошла ошибка все изменения отменены';
END CATCH;
