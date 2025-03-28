USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'SE Asia Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone NVARCHAR(50) = 'SA Western Standard Time'; 
SET @CompanyId = 3;

DECLARE @EmployeeMapping TABLE (
    EmpId INT,
    OldEmpId INT,
    CompanyId INT
);


INSERT INTO @EmployeeMapping (EmpId, OldEmpId, CompanyId)
SELECT DISTINCT tmpEmp.EmpId, tmpEmp.OldEmpId, ce.CompanyId  
FROM dbo.Employee AS tmpEmp WITH (NOLOCK) 
INNER JOIN dbo.CompanyEmployee AS ce  WITH (NOLOCK)
    ON tmpEmp.EmpId = ce.EmpId 
WHERE ce.CompanyId = @CompanyId

INSERT INTO dbo.DisciplineType (DisciplineTypeId, Name, Score, IsActive)
SELECT DisciplineTypeId, Name, Score, IsActive 
FROM HRM.dbo.DisciplineType;


INSERT INTO dbo.LogAction (
    LogActionId, Name, SpName
)
SELECT 
    la.LogActionId, 
    la.Name, 
    la.SpName
FROM HRM.dbo.LogAction la;


SET IDENTITY_INSERT dbo.JobLevel ON;
INSERT INTO [dbo].[JobLevel]
           (JobLevelId
		   ,Name
           ,IsDeleted
           ,ModifiedBy
           ,ModifiedDate)
     SELECT
			jl.JobLevelId
           ,jl.Name
           ,jl.IsDeleted
           ,NULL
           ,jl.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
	FROM HRM.dbo.JobLevel AS jl WITH (NOLOCK)
SET IDENTITY_INSERT dbo.JobLevel OFF;



-- #region LOOKUP TABLE
SET IDENTITY_INSERT dbo.Lookup ON;

INSERT INTO dbo.Lookup (Id, Code, Name)
SELECT Id, Code, Name FROM HRM.dbo.Lookup;

SET IDENTITY_INSERT dbo.Lookup OFF;

DECLARE @MaxId INT;
SELECT @MaxId = MAX(Id) FROM dbo.Lookup;
DBCC CHECKIDENT ('dbo.Lookup', RESEED, @MaxId);
-- #endregion



INSERT INTO [dbo].[Country]
           ([CountryCode]
           ,[CountryName]
           ,[CountryOrder]
           ,[Nationality])
     SELECT
           CountryCode
           ,CountryName
           ,CountryOrder
           ,Nationality
    FROM [HRM].[dbo].[Country] WITH (NOLOCK)


GO




