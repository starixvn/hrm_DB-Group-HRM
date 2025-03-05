USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'UTC'; 
DECLARE @TargetTimeZone NVARCHAR(50) = 'SE Asia Standard Time'; 
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




INSERT INTO [dbo].[CheckInOutRequest]
           (RequestId
           ,EmpId
           ,OnDate
           ,RequestTime
           ,ReasonId
           ,RefNo)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,cio.OnDate
           ,cio.RequestTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone --Actual Request time
           ,cio.ReasonId
           ,cio.RefNo
	FROM SMSHRM.dbo.CheckInOutRequest AS cio WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON cio.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON cio.EmpId = emp.OldEmpId


INSERT INTO [dbo].[CheckInOutRequestHistory]
           (RequestId
           ,EmpId
           ,OnDate
           ,RequestTime 
           ,ReasonId
           ,RefNo
           ,HistoryId)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,cioh.OnDate
           ,cioh.RequestTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,cioh.ReasonId
           ,cioh.RefNo
           ,wkrh.HistoryId
	FROM SMSHRM.dbo.CheckInOutRequestHistory AS cioh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON cioh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON cioh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON cioh.EmpId = emp.OldEmpId
GO



