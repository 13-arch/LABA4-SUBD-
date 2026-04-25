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
				WHERE inserted.[Status] = 'Подтверждён'
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
			THROW
		END CATCH
END


--ЗАДАНИЕ 4

