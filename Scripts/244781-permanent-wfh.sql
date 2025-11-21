/*
    Created: Lilac@20251121
    Task: Add IsCountInHeadcount, change ToDate to nullable
    DB: bodb_HRM

    Revisions:
        20251121@Lilac: add IsCountInHeadcount, change ToDate to nullable [Redmine: #244781]
*/

USE bodb_HRM
GO

ALTER TABLE EmployeeWorkFromHome
ALTER COLUMN ToDate DATE NULL;
GO

ALTER TABLE EmployeeWorkFromHome
ADD IsCountInHeadcount BIT NULL;
GO
