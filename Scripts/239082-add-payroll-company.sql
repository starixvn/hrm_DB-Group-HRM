USE [bodb_HRM]
GO

/*
    Created: Mira@20250919
    Task: Add payroll company
    DB: bodb_HRM

    Revisions:
        20250919@Mira: Add payroll company [Redmine: #239082]
*/

ALTER TABLE dbo.CompanyEmployee
ADD PayrollCompanyId INT
GO

UPDATE dbo.CompanyEmployee
SET PayrollCompanyId = CompanyId
