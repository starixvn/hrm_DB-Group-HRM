									/*
    Created: 20251020@Lilac
    Task: Initialize data permission for all HRM sites
    DB: bodb_IUC

    Revisions:
        20251020@Lilac: rename LocalSalary to BasicSalary, add column JobLevelAddOn [Redmine: #241810]
*/

USE [bodb_HRM]
GO

EXEC sp_rename 'SalaryStructureDetail.LocalSalary', 'BasicSalary', 'COLUMN';

ALTER TABLE SalaryStructureDetail
ADD JobLevelAddOn VARCHAR(100) NULL;

GO