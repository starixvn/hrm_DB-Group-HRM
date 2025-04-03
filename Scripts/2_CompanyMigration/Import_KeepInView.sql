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




INSERT INTO [dbo].[KeepInViewByDayTrans]
           (EmpId
           ,RequestId
           ,CreditDays
           ,DeductDays
           ,InYear
           ,InsertedDate)
     SELECT
           emp.EmpId
           ,wkr.RequestId
           ,kivd.CreditDays
           ,kivd.DeductDays
           ,kivd.InYear
           ,kivd.InsertedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
	FROM [SMSHRM].[dbo].[KeepInViewByDayTrans] AS kivd WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON kivd.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON kivd.EmpId = emp.OldEmpId



INSERT INTO [dbo].[KeepInViewByHourTrans]
           (EmpId
           ,WorkDate
           ,RequestId
           ,CreditMinutes
           ,DeductMinutes
           ,InsertedDate
           ,MinutesBalance)
     SELECT
           emp.EmpId
           ,kivh.WorkDate
           ,wkr.RequestId
           ,kivh.CreditMinutes
           ,kivh.DeductMinutes
           ,kivh.InsertedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,kivh.MinutesBalance
	FROM [SMSHRM].[dbo].[KeepInViewByHourTrans] AS kivh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON kivh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON kivh.EmpId = emp.OldEmpId


INSERT INTO [dbo].[KeepInViewRequest]
           (RequestId
           ,EmpId
           ,IsHalfDay
           ,FromTime
           ,ToTime
           ,RefNo
           ,OnDate
           ,KeepInViewType
           ,ShiftId)
     SELECT
          wkr.RequestId
           ,emp.EmpId
           ,kiv.IsHalfDay
           ,kiv.FromTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,kiv.ToTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,kiv.RefNo
           ,kiv.OnDate
           ,kiv.KeepInViewType
           ,s.ShiftId
	FROM [SMSHRM].[dbo].[KeepInViewRequest] AS kiv WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON kiv.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON kiv.EmpId = emp.OldEmpId
	LEFT JOIN dbo.Shift AS s WITH (NOLOCK) ON kiv.ShiftId = s.OldShiftId AND s.CompanyId = @CompanyId



INSERT INTO [dbo].[KeepInViewRequestHistory]
           (RequestId
           ,EmpId
           ,OnDate
           ,IsHalfDay
           ,FromTime
           ,ToTime
           ,HistoryId
           ,KeepInViewType)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,kivh.OnDate
           ,kivh.IsHalfDay
           ,kivh.FromTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,kivh.ToTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wkrh.HistoryId
           ,kivh.KeepInViewType
	FROM  [SMSHRM].[dbo].[KeepInViewRequestHistory] AS kivh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON kivh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON kivh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON kivh.EmpId = emp.OldEmpId
	


GO


