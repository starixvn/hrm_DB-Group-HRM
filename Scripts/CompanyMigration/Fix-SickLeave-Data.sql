
USE [bodb_HRM]
GO


  -- Delete duplicate Cymabell SickLeaveTrans
WITH DuplicateSickLeave AS (
    SELECT EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate,
        ROW_NUMBER() OVER (PARTITION BY EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate ORDER BY (SELECT NULL)) AS RowNum
    FROM dbo.SickLeaveTrans
    WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = 13)
)
DELETE FROM DuplicateSickLeave 
WHERE RowNum > 1

GO


  -- Delete duplicate Xpeed SickLeaveTrans
WITH DuplicateSickLeave AS (
    SELECT EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate,
        ROW_NUMBER() OVER (PARTITION BY EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate ORDER BY (SELECT NULL)) AS RowNum
    FROM dbo.SickLeaveTrans
    WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = 28)
)
DELETE FROM DuplicateSickLeave 
WHERE RowNum > 1

GO


  -- Delete duplicate Sandsdover SickLeaveTrans
WITH DuplicateSickLeave AS (
    SELECT EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate,
        ROW_NUMBER() OVER (PARTITION BY EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate ORDER BY (SELECT NULL)) AS RowNum
    FROM dbo.SickLeaveTrans
    WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = 26)
)
DELETE FROM DuplicateSickLeave 
WHERE RowNum > 1

GO


  -- Delete Duplicate Element SickLeaveTrans
WITH DuplicateSickLeave AS (
    SELECT EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate,
        ROW_NUMBER() OVER (PARTITION BY EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate ORDER BY (SELECT NULL)) AS RowNum
    FROM dbo.SickLeaveTrans
    WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = 16)
)
DELETE FROM DuplicateSickLeave 
WHERE RowNum > 1

GO

  -- Delete Duplicate Digibytesky SickLeaveTrans
WITH DuplicateSickLeave AS (
    SELECT EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate,
        ROW_NUMBER() OVER (PARTITION BY EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate ORDER BY (SELECT NULL)) AS RowNum
    FROM dbo.SickLeaveTrans
    WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = 15)
)
DELETE FROM DuplicateSickLeave 
WHERE RowNum > 1

GO


  -- Delete Duplicate Connectshore SickLeaveTrans
WITH DuplicateSickLeave AS (
    SELECT EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate,
        ROW_NUMBER() OVER (PARTITION BY EmpId, RequestId, FromDate, DeductDays, CreditDays, IsDeleted, CreatedDate ORDER BY (SELECT NULL)) AS RowNum
    FROM dbo.SickLeaveTrans
    WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = 12)
)
DELETE FROM DuplicateSickLeave 
WHERE RowNum > 1

GO





