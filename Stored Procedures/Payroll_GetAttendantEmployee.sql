/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Payroll_GetAttendantEmployee]
(
	@CompanyId INT,
	@Date DATETIME
)
AS
/*
    Created: Jay.Do@20250730
    Task: get monthly payroll calculation data
    DB: bodb_HRM

    Revisions:
        20250730@Jay.Do: init function [Redmine: #217977]
		20250821@Jay: restructure for transfer [Redmine: #235678]
		20251020@Lilac: rename LocalSalary to BasicSalary [Redmine: #241810]
		20251128@Mira: calculate allowance [Redmine: #245214]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @UnpaidLeaveId INT = 25,
        @InsuranceLeaveId INT = 41,
        @PaternityLeaveId INT = 14,
        @MaternityLeaveId INT = 12,
		@PendingStatusId INT = 1,
        @CheckInId INT = 1,
		@CheckOutId INT = 2;

	-- Calculate date range for the month to enable index usage
	DECLARE @StartDate DATETIME = DATEFROMPARTS(YEAR(@Date), MONTH(@Date), 1);
	DECLARE @EndDate DATETIME = DATEADD(MONTH, 1, @StartDate); -- Start of next month (exclusive)

	DECLARE @TempEmployeeWorkingCalendar TABLE(
		EmpId INT,
		[WorkDate] DATETIME,
		IsHoliday BIT,
		IsOffDay BIT,
		CheckIn DATETIME,
		CheckOut DATETIME,
		UnpaidLeaveDay DECIMAL(18, 2),
		LeaveTypeId INT,
		IsWorkDay BIT, -- Computed: IsHoliday = 1 OR (CheckIn IS NOT NULL AND CheckOut IS NOT NULL) OR LeaveTypeId IS NOT NULL
		ConfirmedDate DATETIME, -- Cache for performance
		ResignedDate DATETIME, -- Cache for performance
		INDEX IX_TempEmployeeWorkingCalendar_EmpId_WorkDate (EmpId, WorkDate)
	)
	DECLARE @TempWorkingSummary TABLE (
		EmpId INT PRIMARY KEY,
		TotalWorkingDays DECIMAL(18,2),
		TotalNewHireWorkingDays DECIMAL(18,2),
		IsMaternity BIT,
		TotalUnpaidLeaveDays DECIMAL(18,2)
	);
	DECLARE @TempPendingCheckInOut TABLE(
		EmpId INT,
		RequestTime DATETIME,
		RequestType INT,
		OnDate DATETIME,
		INDEX IX_TempPendingCheckInOut_EmpId_OnDate (EmpId, OnDate)
	)

	-- Cache Currency config for the company to avoid repeated queries
	DECLARE @CurrencyId INT;
	SELECT TOP 1 @CurrencyId = CAST(tmp.value AS INT)
	FROM SystemConfigs sc WITH (NOLOCK)
	CROSS APPLY STRING_SPLIT(sc.[Value], ',') tmp
	WHERE sc.[Key] = 'Currency'
	  AND sc.CompanyId = @CompanyId
	ORDER BY tmp.value ASC;

	INSERT INTO @TempPendingCheckInOut (EmpId, RequestTime, RequestType, OnDate)
	SELECT cior.EmpId,
		RequestTime,
		wtr.RequestType,
		OnDate
	FROM CheckInOutRequest cior WITH (NOLOCK)
		INNER JOIN WorkingTimeRequest wtr WITH (NOLOCK) ON cior.RequestId = wtr.RequestId
			AND RequestType IN (@CheckInId, @CheckOutId)
			AND CurrentStatus = @PendingStatusId
	WHERE cior.OnDate >= @StartDate
		AND cior.OnDate < @EndDate

	INSERT INTO @TempEmployeeWorkingCalendar (EmpId, WorkDate, IsHoliday, IsOffDay, CheckIn, CheckOut, UnpaidLeaveDay, LeaveTypeId, IsWorkDay, ConfirmedDate, ResignedDate)
	SELECT tec.EmpId,
		tec.WorkDate,
		tec.IsHoliday,
		tec.IsOffDay,
		ea.InFixed AS CheckIn,
		ea.OutFixed AS CheckOut,
		CASE
			WHEN tec.LeaveTypeId IN (@UnpaidLeaveId, @InsuranceLeaveId, @PaternityLeaveId, @MaternityLeaveId)
				THEN ISNULL(tec.LeaveDay, 0)
			ELSE 0
		END AS UnpaidLeaveDay,
		tec.LeaveTypeId,
		-- Pre-compute IsWorkDay to avoid repeated calculations
		CASE 
			WHEN tec.IsHoliday = 1 
				OR (ea.InFixed IS NOT NULL AND ea.OutFixed IS NOT NULL)
				OR tec.LeaveTypeId IS NOT NULL
			THEN 1 
			ELSE 0 
		END AS IsWorkDay,
		e.ConfirmedDate,
		e.ResignedDate
	FROM tmpEmployeeCalendar tec WITH (NOLOCK)
		INNER JOIN CompanyEmployee ce WITH (NOLOCK) ON tec.EmpId = ce.EmpId 
			AND ce.CompanyId = @CompanyId 
			AND ISNULL(ce.isDeleted, 0) = 0 
			AND ce.IsSpecialUser = 0
		INNER JOIN Employee e WITH (NOLOCK) ON ce.UserId = e.UserId 
			AND (e.ResignedDate IS NULL OR e.ResignedDate > @Date)
		LEFT JOIN EmployeeAttendance ea WITH(NOLOCK) ON ea.EmpId = tec.EmpId 
			AND tec.WorkDate = ea.AttendanceDate
		INNER JOIN EmployeeSummary es WITH (NOLOCK) ON tec.EmpId = es.EmpId
	WHERE tec.WorkDate >= @StartDate
		AND tec.WorkDate < @EndDate
		AND tec.IsOffDay = 0

	-- Update CheckIn and CheckOut in a single pass
	UPDATE tewc
	SET CheckIn = CASE WHEN pdco.RequestType = @CheckInId THEN pdco.RequestTime ELSE tewc.CheckIn END,
		CheckOut = CASE WHEN pdco.RequestType = @CheckOutId THEN pdco.RequestTime ELSE tewc.CheckOut END
	FROM @TempEmployeeWorkingCalendar tewc
		INNER JOIN @TempPendingCheckInOut pdco ON tewc.EmpId = pdco.EmpId
			AND tewc.WorkDate = pdco.OnDate
			AND pdco.RequestType IN (@CheckInId, @CheckOutId)

	-- Recalculate IsWorkDay only for rows that were updated with pending CheckIn/CheckOut
	UPDATE tewc
	SET IsWorkDay = 1
	FROM @TempEmployeeWorkingCalendar tewc
		INNER JOIN @TempPendingCheckInOut pdco ON tewc.EmpId = pdco.EmpId
			AND tewc.WorkDate = pdco.OnDate
	WHERE tewc.IsWorkDay = 0
		AND (tewc.IsHoliday = 1 
			OR (tewc.CheckIn IS NOT NULL AND tewc.CheckOut IS NOT NULL)
			OR tewc.LeaveTypeId IS NOT NULL)

	INSERT INTO @TempWorkingSummary(
		EmpId,
		TotalWorkingDays,
		TotalNewHireWorkingDays,
		TotalUnpaidLeaveDays,
		IsMaternity
	)
	SELECT 
		tewc.EmpId,
		-- TotalWorkingDays: confirmed employees
		SUM(CASE 
			WHEN tewc.WorkDate >= tewc.ConfirmedDate 
				AND tewc.IsWorkDay = 1
			THEN 1.0
			ELSE 0.0
		END)
		- SUM(CASE 
			WHEN tewc.WorkDate >= tewc.ConfirmedDate 
				AND (tewc.ResignedDate IS NULL OR tewc.WorkDate < tewc.ResignedDate)
			THEN tewc.UnpaidLeaveDay
			ELSE 0
		END) AS TotalWorkingDays,
		-- TotalNewHireWorkingDays: before confirmation
		SUM(CASE 
			WHEN (tewc.WorkDate < tewc.ConfirmedDate OR tewc.ConfirmedDate IS NULL)
				AND tewc.IsWorkDay = 1
			THEN 1.0
			ELSE 0.0
		END)
		- SUM(CASE 
			WHEN (tewc.WorkDate < tewc.ConfirmedDate OR tewc.ConfirmedDate IS NULL)
			THEN tewc.UnpaidLeaveDay
			ELSE 0
		END) AS TotalNewHireWorkingDays,
		SUM(tewc.UnpaidLeaveDay) AS TotalUnpaidLeaveDays,
		MAX(CASE WHEN tewc.LeaveTypeId = @MaternityLeaveId THEN 1 ELSE 0 END) AS IsMaternity
	FROM @TempEmployeeWorkingCalendar tewc
	GROUP BY tewc.EmpId
	ORDER BY tewc.EmpId ASC

	-- Select data
	SELECT
		ws.EmpId,
		ws.TotalWorkingDays,
		ws.TotalNewHireWorkingDays,
		ws.IsMaternity,
		ws.TotalUnpaidLeaveDays,
		-- salary & currency
		IIF(es.IsLocal = 1, salary.BasicSalary, salary.ExpatSalary) AS EncryptBasicSalary,
		IIF(es.IsLocal = 1, salary.JobLevelAddOn, salary.ExpatJobLevelAddOn) AS EncryptJobLevelAddOn,
		IIF(es.IsLocal = 1, currency.CurrencyCode, 'USD') AS CurrencyCode,
		payroll.SpecialSubsidy AS EncryptSpecialSubsidy,
		ISNULL(subsidyCurrency.CurrencyCode, currency.CurrencyCode) AS SpecialSubsidyCurrencyCode,
		-- working days config
		CASE 
			WHEN es.WorkingDays IS NOT NULL THEN es.WorkingDays
			WHEN es.IsLocal = 1 THEN g.LocalWorkingDays
			ELSE g.ExpatWorkingDays
		END AS WorkingDays,
		ce.CompanyDate,
		e.ConfirmedDate,
		e.JoinedDate,
		CASE 
            WHEN e.ResignedDate IS NOT NULL 
                 AND e.ResignedDate >= @StartDate
                 AND e.ResignedDate < @EndDate
            THEN 1 ELSE 0
		END AS IsResigned,
		e.ResignedDate,
		CASE 
            WHEN e.ConfirmedDate IS NULL OR e.ConfirmedDate > @StartDate THEN 1
			ELSE 0
		END AS IsNewHire
	FROM @TempWorkingSummary ws
	INNER JOIN CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = ws.EmpId
	INNER JOIN EmployeeSummary es WITH (NOLOCK) ON es.EmpId = ws.EmpId
	INNER JOIN Employee e WITH (NOLOCK) ON e.UserId = ce.UserId
	LEFT JOIN [Group] g WITH (NOLOCK) ON g.GroupId = ce.GroupId
	LEFT JOIN EmployeePayroll payroll WITH (NOLOCK) ON payroll.EmpId = ws.EmpId
	LEFT JOIN SalaryStructureDetail salary WITH (NOLOCK) ON salary.SalaryStructureId = payroll.SalaryStructureId AND salary.JobLevelId = ce.JobLevelId
	LEFT JOIN Currency subsidyCurrency WITH (NOLOCK) ON subsidyCurrency.Id = payroll.SpecialSubsidyCurrencyId
	LEFT JOIN Currency currency WITH (NOLOCK) ON currency.Id = @CurrencyId
	ORDER BY ws.EmpId ASC;
END