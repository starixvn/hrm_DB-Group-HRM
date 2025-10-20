/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER       PROCEDURE [dbo].[Payroll_GetAttendantEmployee]
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

	DECLARE @TempPendingCheckInOut TABLE(
		EmpId INT,
		RequestTime DATETIME,
		RequestType INT,
		OnDate DATETIME
	)

	INSERT INTO @TempPendingCheckInOut
	SELECT cior.EmpId,
		RequestTime,
		wtr.RequestType,
		OnDate
	FROM CheckInOutRequest cior
		INNER JOIN WorkingTimeRequest wtr WITH (NOLOCK) ON cior.RequestId = wtr.RequestId
			AND RequestType IN (@CheckInId, @CheckOutId)
			AND CurrentStatus = @PendingStatusId
	WHERE MONTH(OnDate) = MONTH(@Date)
		AND YEAR(OnDate) = YEAR(@Date)

	DECLARE @TempEmployeeWorkingCalendar TABLE(
		EmpId INT,
		[WorkDate] DATETIME,
		IsHoliday BIT,
		IsOffDay BIT,
		CheckIn DATETIME,
		CheckOut DATETIME,
		UnpaidLeaveDay DECIMAL(18, 2),
		LeaveTypeId INT
	)

	INSERT INTO @TempEmployeeWorkingCalendar
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
		tec.LeaveTypeId
	FROM tmpEmployeeCalendar tec WITH (NOLOCK)
		INNER JOIN CompanyEmployee ce WITH (NOLOCK) ON tec.EmpId = ce.EmpId 
			AND ISNULL(ce.isDeleted, 0) = 0
		INNER JOIN Employee e (NOLOCK) ON ce.UserId = e.UserId
		LEFT JOIN EmployeeAttendance ea WITH(NOLOCK) ON ea.EmpId = tec.EmpId 
			AND tec.WorkDate = ea.AttendanceDate
		INNER JOIN EmployeeSummary es WITH (NOLOCK) ON tec.EmpId = es.EmpId
	WHERE MONTH(WorkDate) = MONTH(@Date)
		AND YEAR(WorkDate) = YEAR(@Date)
		AND ce.CompanyId = @CompanyId
		AND IsOffDay = 0
		AND (e.ResignedDate IS NULL OR e.ResignedDate >  @Date)
		AND ce.IsSpecialUser = 0

	UPDATE tewc
	SET CheckIn = pdco.RequestTime
	FROM @TempEmployeeWorkingCalendar tewc
		INNER JOIN @TempPendingCheckInOut pdco ON tewc.EmpId = pdco.EmpId
			AND tewc.WorkDate = pdco.OnDate
	WHERE pdco.RequestType = @CheckInId

	UPDATE tewc
	SET CheckOut = pdco.RequestTime
	FROM @TempEmployeeWorkingCalendar tewc
		INNER JOIN @TempPendingCheckInOut pdco ON tewc.EmpId = pdco.EmpId
			AND tewc.WorkDate = pdco.OnDate
	WHERE pdco.RequestType = @CheckOutId

	
	SELECT 
		tewc.EmpId,

		SUM(
			CASE 
				WHEN tewc.WorkDate >= e.ConfirmedDate 
						AND (
								IsHoliday = 1 
								OR (CheckIn IS NOT NULL AND CheckOut IS NOT NULL)
								OR LeaveTypeId IS NOT NULL
							)
					THEN 1.0
				ELSE 0.0
			END
		)
		- SUM(
			CASE 
				WHEN tewc.WorkDate >= e.ConfirmedDate 
					AND (e.ResignedDate IS NULL OR tewc.WorkDate < e.ResignedDate)
				THEN ISNULL(tewc.UnpaidLeaveDay, 0)
				ELSE 0
			END
		) AS TotalWorkingDays,

		SUM(
			CASE 
				WHEN (tewc.WorkDate < e.ConfirmedDate OR e.ConfirmedDate IS NULL)
						AND (
								IsHoliday = 1 
								OR (CheckIn IS NOT NULL AND CheckOut IS NOT NULL)
								OR LeaveTypeId IS NOT NULL
							)
					THEN 1.0
				ELSE 0.0
			END
		)
		- SUM(
			CASE 
				WHEN (tewc.WorkDate < e.ConfirmedDate OR e.ConfirmedDate IS NULL)
				THEN ISNULL(tewc.UnpaidLeaveDay, 0)
				ELSE 0
			END
		) AS TotalNewHireWorkingDays,

		MAX(CASE 
				WHEN e.ResignedDate IS NOT NULL AND Month(e.ResignedDate) = Month(@Date) AND Year(e.ResignedDate) = Year(@Date)
					THEN 1
				ELSE 0
		END) AS IsResigned,

		MAX(e.ResignedDate) AS ResignedDate,

		MAX(CASE 
			WHEN tewc.LeaveTypeId = @MaternityLeaveId THEN 1
			ELSE 0
		END) AS IsMaternity,

		SUM(UnpaidLeaveDay) AS TotalUnpaidLeaveDays,

		MAX(CASE 
				WHEN ce.Salary IS NOT NULL
					THEN ce.Salary
				WHEN es.IsLocal = 1
					THEN BasicSalary
				ELSE ExpatSalary
			END
		) AS Salary,

		MAX(
			CASE 
				WHEN es.WorkingDays IS NOT NULL 
					THEN es.WorkingDays
				WHEN es.IsLocal = 1
					THEN g.LocalWorkingDays
				ELSE g.ExpatWorkingDays
			END
		) AS WorkingDays,

		MAX(ce.CompanyDate) AS CompanyDate,
		MAX(e.ConfirmedDate) AS ConfirmedDate,
		MAX(e.JoinedDate) AS JoinedDate
	FROM @TempEmployeeWorkingCalendar tewc
		INNER JOIN CompanyEmployee ce WITH (NOLOCK) ON tewc.EmpId = ce.EmpId 
			AND ISNULL(ce.isDeleted, 0) = 0
		INNER JOIN EmployeeSummary es WITH (NOLOCK) ON tewc.EmpId = es.EmpId 
		LEFT JOIN [Group] g WITH (NOLOCK) ON g.GroupId = ce.GroupId
		INNER JOIN Employee e WITH (NOLOCK) ON e.UserId = ce.UserId
		LEFT JOIN SalaryStructureDetail std WITH (NOLOCK) ON std.JobLevelId = ce.JobLevelId 
			AND ce.SalaryStructureId = std.SalaryStructureId
	GROUP BY tewc.EmpId
	order by tewc.empid
END