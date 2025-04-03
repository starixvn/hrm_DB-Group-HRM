USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'SE Asia Standard Time'; 
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


INSERT INTO [dbo].[LeaveRequest]
           (RequestId
           ,EmpId
           ,FromDate
           ,ToDate
           ,LeaveType
           ,TotalDays
           ,RefNo
           ,ReworkCount)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,lr.FromDate
           ,lr.ToDate
           ,lr.LeaveType
           ,lr.TotalDays
           ,lr.RefNo
           ,lr.ReworkCount
	FROM [SMSHRM].[dbo].[LeaveRequest] AS lr WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lr.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON lr.EmpId = emp.OldEmpId



INSERT INTO [dbo].LeaveRequestDetail
           (RequestId
           ,EmpId
           ,OnDate
           ,ShiftId
           ,LeaveType
           ,IsHalfDay
           ,FromTime
           ,ToTime
           ,WorkType)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,lrd.OnDate
           ,s.ShiftId
           ,lrd.LeaveType
           ,lrd.IsHalfDay
           ,lrd.FromTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,lrd.ToTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,lrd.WorkType
	FROM [SMSHRM].[dbo].[LeaveRequestDetail] AS lrd WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lrd.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON lrd.EmpId = emp.OldEmpId 
	LEFT JOIN dbo.Shift AS s WITH (NOLOCK) ON lrd.ShiftId = s.OldShiftId AND s.CompanyId = @CompanyId


INSERT INTO [dbo].[LeaveRequestDetailHistory]
           (RequestId
           ,EmpId
           ,OnDate
           ,ShiftId
           ,LeaveType
           ,IsHalfDay
           ,FromTime
           ,ToTime
           ,WorkType
           ,HistoryId)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,lrdh.OnDate
           ,s.ShiftId
           ,lrdh.LeaveType
           ,lrdh.IsHalfDay
           ,lrdh.FromTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,lrdh.ToTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,lrdh.WorkType
           ,wkrh.HistoryId
	FROM [SMSHRM].[dbo].[LeaveRequestDetailHistory] AS lrdh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lrdh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON lrdh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON lrdh.EmpId = emp.OldEmpId 
	LEFT JOIN dbo.Shift AS s WITH (NOLOCK) ON lrdh.ShiftId = s.OldShiftId AND s.CompanyId = @CompanyId


INSERT INTO [dbo].[LeaveRequestHistory]
           (RequestId
           ,EmpId
           ,FromDate
           ,ToDate
           ,LeaveType
           ,TotalDays
           ,HistoryId)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,lrh.FromDate
           ,lrh.ToDate
           ,lrh.LeaveType
           ,lrh.TotalDays
           ,wkrh.HistoryId
	FROM [SMSHRM].[dbo].[LeaveRequestHistory] AS lrh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lrh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON lrh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON lrh.EmpId = emp.OldEmpId 


INSERT INTO [dbo].[LeaveTrans]
           (EmpId
           ,RequestId
           ,Description
           ,FromDate
           ,ToDate
           ,DeductDays
           ,CreditDays
           ,Deleted
           ,CreatedDate
           ,CreatedBy
           ,ModifiedDate
           ,ModifiedBy
           ,OldLeaveTransId)
     SELECT
           emp.EmpId
           ,wkr.RequestId
           ,lt.Description
           ,lt.FromDate
           ,lt.ToDate
           ,lt.DeductDays
           ,lt.CreditDays
           ,lt.Deleted
           ,lt.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone 
           ,empCreated.EmpId
           ,lt.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,empModified.EmpId
           ,lt.LeaveTransId
	FROM [SMSHRM].[dbo].[LeaveTrans] AS lt WITH (NOLOCK)
	LEFT JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lt.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON lt.EmpId = emp.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empCreated ON lt.CreatedBy = empCreated.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empModified ON lt.ModifiedBy = empModified.OldEmpId;

GO


