-- =========================
-- データベース作成
-- =========================
-- 既存接続をすべて切断してからデータベース削除
USE master;
GO

-- すべての接続をクローズ
ALTER DATABASE appdb SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

-- データベース削除
DROP DATABASE IF EXISTS appdb;
GO

-- 新しいデータベースを作成
CREATE DATABASE appdb COLLATE Japanese_90_CI_AS_SC_UTF8;
GO

USE appdb;
GO

-- =========================
-- 顧客テーブル作成
-- =========================
CREATE TABLE dbo.Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) COLLATE Japanese_90_CI_AS_SC_UTF8 NOT NULL,
    Email NVARCHAR(255) UNIQUE NOT NULL,
    Phone NVARCHAR(20),
    Address NVARCHAR(255) COLLATE Japanese_90_CI_AS_SC_UTF8,
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

-- =========================
-- 注文テーブル作成
-- =========================
CREATE TABLE dbo.Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME2 DEFAULT SYSUTCDATETIME(),
    ProductName NVARCHAR(100) COLLATE Japanese_90_CI_AS_SC_UTF8 NOT NULL,
    Quantity INT NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID)
);
GO

-- =========================
-- 顧客データ挿入
-- =========================
INSERT INTO dbo.Customers (Name, Email, Phone, Address)
VALUES
(N'山田太郎', 'taro.yamada@example.com', '090-1234-5678', N'東京都品川区'),
(N'佐藤花子', 'hanako.sato@example.com', '080-9876-5432', N'大阪府大阪市'),
(N'徳川家康', 'tokugawa@example.com', '070-5555-6666', N'東京都千代田区');
GO

-- =========================
-- 注文データ挿入
-- =========================
INSERT INTO dbo.Orders (CustomerID, ProductName, Quantity, Price)
VALUES
(1, N'ノートPC', 1, 150000),
(1, N'マウス', 2, 3000),
(2, N'プリンター', 1, 25000),
(3, N'外付けSSD', 1, 12000);
GO

-- =========================
-- 複数注文用テーブル型定義
-- =========================
CREATE TYPE dbo.OrderList AS TABLE
(
    ProductName NVARCHAR(100) COLLATE Japanese_90_CI_AS_SC_UTF8,
    Quantity INT,
    Price DECIMAL(10,2)
);
GO

-- =========================
-- 顧客別注文履歴ビュー作成
-- =========================
CREATE VIEW dbo.CustomerOrderHistory AS
SELECT
    c.CustomerID,
    c.Name AS CustomerName,
    c.Email,
    o.OrderID,
    o.ProductName,
    o.Quantity,
    o.Price,
    (o.Quantity * o.Price) AS TotalPrice,
    o.OrderDate
FROM dbo.Customers c
INNER JOIN dbo.Orders o ON c.CustomerID = o.CustomerID;
GO

-- =========================
-- 単一注文追加プロシージャ
-- =========================
CREATE PROCEDURE dbo.AddOrder
    @CustomerID INT,
    @ProductName NVARCHAR(100),
    @Quantity INT,
    @Price DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerID = @CustomerID)
    BEGIN
        RAISERROR(N'指定された顧客IDは存在しません。', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.Orders (CustomerID, ProductName, Quantity, Price)
    VALUES (@CustomerID, @ProductName, @Quantity, @Price);

    SELECT OrderID, CustomerID, ProductName, Quantity, Price, OrderDate
    FROM dbo.Orders
    WHERE OrderID = SCOPE_IDENTITY();
END;
GO

-- =========================
-- 複数注文追加プロシージャ（トランザクション対応）
-- =========================
CREATE PROCEDURE dbo.AddMultipleOrders
        @CustomerID INT,
        @Orders dbo.OrderList READONLY
    AS
    BEGIN
        SET NOCOUNT ON;

        BEGIN TRY
            BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerID = @CustomerID)
            BEGIN
                RAISERROR('指定された顧客IDは存在しません。', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END;

            INSERT INTO dbo.Orders (CustomerID, ProductName, Quantity, Price)
            SELECT @CustomerID, ProductName, Quantity, Price FROM @Orders;

            COMMIT TRANSACTION;

            SELECT OrderID, CustomerID, ProductName, Quantity, Price, OrderDate
            FROM dbo.Orders
            WHERE CustomerID = @CustomerID
            ORDER BY OrderDate DESC;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
            RAISERROR(@ErrMsg, 16, 1);
        END CATCH
    END;
GO
