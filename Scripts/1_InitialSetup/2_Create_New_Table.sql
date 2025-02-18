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