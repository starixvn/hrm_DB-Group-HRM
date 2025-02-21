USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CompanyTimeZone INT;
DECLARE @ServerTimeZone INT;
SET @CompanyId = 3;
SET @ServerTimeZone =  DATEPART(TZOFFSET, SYSDATETIMEOFFSET()) / 60;
SET @CompanyTimeZone = 7;
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


INSERT INTO [dbo].[OTMonthlyRequest]
           (Month
           ,EmpId
           ,NormalHours
           ,OffHours
           ,PublicHours
           ,SpecialHours
           ,CurrentStatus
           ,VerifierId
           ,ApproverId
           ,HRId
           ,VerifiedDate
           ,ApprovedDate
           ,HRDate
           ,VerifiedStatus
           ,ApprovedStatus
           ,HRStatus
           ,ModifiedBy
           ,ModifiedDate
           ,CreatedDate
           ,CreatedBy
		   ,OldRequestId)
     SELECT
           otm.[Month]
           ,emp.EmpId
           ,otm.NormalHours
           ,otm.OffHours
           ,otm.PublicHours
           ,otm.SpecialHours
           ,otm.CurrentStatus
           ,empVerify.EmpId
           ,empApprove.EmpId
           ,empHr.EmpId
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, otm.VerifiedDate)
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, otm.ApprovedDate)
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, otm.HRDate)
           ,otm.VerifiedStatus
           ,otm.ApprovedStatus
           ,otm.HRStatus
           ,empModified.EmpId
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, otm.ModifiedDate)
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, otm.CreatedDate)
           ,empCreated.EmpId
		   ,otm.RequestId
	FROM [SMSHRM].[dbo].[OTMonthlyRequest] as otm  WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON otm.EmpId = emp.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empVerify ON otm.VerifierId = empVerify.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empApprove  ON otm.ApproverId = empApprove.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empHr  ON otm.HRId = empHr.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empCreated ON otm.CreatedBy = empCreated.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empModified  ON otm.ModifiedBy = empModified.OldEmpId;


	
INSERT INTO [dbo].[OTDailyRequest]
           (OvertimeDate
           ,EmpId
           ,RequestId
           ,Schedule
           ,TimeIn
           ,TimeOut
           ,TotalHours
           ,NormalHours
           ,OffHours
           ,PublicHours
           ,SpecialHours
           ,Remark
           ,Status
           ,CreatedBy
           ,CreatedDate
           ,IsUpdated)
     SELECT
           otd.OvertimeDate
           ,emp.EmpId
           ,otm.RequestId
           ,s.ShiftID
           ,otd.TimeIn
           ,otd.TimeOut
           ,otd.TotalHours
           ,otd.NormalHours
           ,otd.OffHours
           ,otd.PublicHours
           ,otd.SpecialHours
           ,otd.Remark
           ,otd.Status
           ,empCreated.EmpId
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, otd.CreatedDate)
           ,otd.IsUpdated
	FROM [SMSHRM].[dbo].[OTDailyRequest] as otd  WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON otd.EmpId = emp.OldEmpId 
	LEFT JOIN dbo.OTMonthlyRequest AS otm WITH (NOLOCK) ON otd.RequestId = otm.OldRequestId 
	LEFT JOIN dbo.Shift AS s ON otd.Schedule = s.OldShiftId AND s.CompanyId = @CompanyId
	LEFT JOIN @EmployeeMapping AS empCreated ON otd.CreatedBy = empCreated.OldEmpId 


GO

