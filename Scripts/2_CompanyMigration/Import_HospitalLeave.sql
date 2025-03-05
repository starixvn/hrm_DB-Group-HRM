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


INSERT INTO [dbo].[HospitalizationLeaveTrans]
           (EmpId
           ,RequestId
           ,Description
           ,FromDate
           ,ToDate
           ,DeductDays
           ,CreditDays
           ,IsDeleted
           ,CreatedDate
           ,CreatedBy
           ,ModifiedDate
           ,ModifiedBy
		   ,OldTransId)
     SELECT
           emp.EmpId
           ,wkr.RequestId
           ,hpl.Description
           ,hpl.FromDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,hpl.ToDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,hpl.DeductDays
           ,hpl.CreditDays
           ,hpl.IsDeleted
           ,hpl.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,empCreated.EmpId
           ,hpl.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,empModified.EmpId
		   ,hpl.TransId
	FROM [SMSHRM].[dbo].[HospitalizationLeaveTrans] AS hpl WITH (NOLOCK)
    INNER JOIN @EmployeeMapping AS emp ON hpl.EmpId = emp.OldEmpId
	LEFT JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON hpl.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN @EmployeeMapping AS empCreated ON hpl.CreatedBy = empCreated.OldEmpId
	LEFT JOIN @EmployeeMapping AS empModified ON hpl.ModifiedBy = empModified.OldEmpId;


INSERT INTO [dbo].[HospitalLeave]
           (RequestId
           ,IsHospitalApplication)
     SELECT
           wkr.RequestId
           ,IsHospitalApplication
	FROM [SMSHRM].[dbo].[HospitalLeave] AS hl WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON hl.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId


INSERT INTO [dbo].[WeekendLeaveTrans]
           (EmpId
           ,WorkDate
           ,LeaveTypeId
           ,LeaveDay
           ,RequestId
           ,IsDiscipline
           ,InsertedDate)
     SELECT
          emp.EmpId
           ,wl.WorkDate
           ,wl.LeaveTypeId
           ,wl.LeaveDay
           ,wkr.RequestId
           ,wl.IsDiscipline
           ,wl.InsertedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
	FROM [SMSHRM].[dbo].[WeekendLeaveTrans] AS wl WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON wl.EmpId = emp.OldEmpId
	LEFT JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON wl.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	




GO


