USE bodb_HRM
GO

ALTER TABLE EmployeeWorkFromHome
ALTER COLUMN ToDate DATE NULL;
GO

ALTER TABLE EmployeeWorkFromHome
ADD IsCountInHeadcount BIT NULL;
GO
