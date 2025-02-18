USE [bodb_HRM]
GO

-- CREATE TABLE
CREATE TABLE Company (
    CompanyId INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(255),
    CountryCode NVARCHAR(10),  -- Đổi từ 'Country' thành 'CountryCode'
    ModifiedBy INT,
    ModifiedDate DATE,
    IsActive BIT,
    IsDeleted BIT
);

CREATE TABLE CompanyEmployee (
    EmpId INT,
    CompanyId INT
);

-- MAP COMPANY TỪ UIC
SET IDENTITY_INSERT bodb_HRM.dbo.Company ON; 

INSERT INTO bodb_HRM.dbo.Company (CompanyId, Name, CountryCode, IsActive)
SELECT 
    CompanyId, 
    Name, 
    CASE 
        WHEN Country = 'Vietnam' THEN 'VN'
        WHEN Country = 'Philippines' THEN 'PH'
        ELSE NULL 
    END AS CountryCode,
    IsActive
FROM bodb_IUC.dbo.Company;

SET IDENTITY_INSERT bodb_HRM.dbo.Company OFF;