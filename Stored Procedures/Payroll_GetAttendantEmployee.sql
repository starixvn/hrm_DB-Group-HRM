/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER   PROCEDURE [dbo].[Payroll_GetAttendantEmployee]
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
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @UnpaidLeaveId INT = 25,
        @InsuranceLeaveId INT = 41,
        @PaternityLeaveId INT = 14,
        @MaternityLeaveId INT = 12;

	SELECT 
		ec.EmpId,

		SUM(
			CASE 
				WHEN ec.WorkDate >= e.ConfirmedDate 
						AND (e.ResignedDate IS NULL OR ec.WorkDate < e.ResignedDate) 
						AND (IsHoliday = 1 
							OR (IsOffDay = 0 AND (ISNULL(TotalWorkHours, 0) > 0 OR ec.LeaveTypeId IS NOT NULL)))
					THEN 1.0
				ELSE 0.0
			END
		)
		- ISNULL(SUM(
			CASE 
				WHEN ec.WorkDate >= e.ConfirmedDate 
					AND (e.ResignedDate IS NULL OR ec.WorkDate < e.ResignedDate)  
					AND ec.LeaveTypeId IN (@UnpaidLeaveId, @InsuranceLeaveId, @PaternityLeaveId, @MaternityLeaveId)
				THEN ISNULL(ec.LeaveDay, 0)
				ELSE 0
			END
		), 0) AS TotalWorkingDays,

		SUM(
			CASE 
				WHEN ec.WorkDate < e.ConfirmedDate 
						AND (IsHoliday = 1 
							OR (IsOffDay = 0 AND (ISNULL(TotalWorkHours, 0) > 0 OR ec.LeaveTypeId IS NOT NULL)))
					THEN 1.0
				ELSE 0.0
			END
		)
		- ISNULL(SUM(
			CASE 
				WHEN ec.WorkDate < e.ConfirmedDate 
					AND ec.LeaveTypeId IN (@UnpaidLeaveId, @InsuranceLeaveId, @PaternityLeaveId, @MaternityLeaveId)
				THEN ISNULL(ec.LeaveDay, 0)
				ELSE 0
			END
		), 0) AS TotalNewHireWorkingDays,

		MAX(CASE 
				WHEN e.ResignedDate IS NOT NULL AND Month(e.ResignedDate) = Month(@Date) AND Year(e.ResignedDate) = Year(@Date)
					THEN 1
				ELSE 0
		END) AS IsResigned,

		MAX(e.ResignedDate) AS ResignedDate,

		MAX(CASE 
			WHEN ec.LeaveTypeId = @MaternityLeaveId THEN 1
			ELSE 0
		END) AS IsMaternityLeave,

		SUM(
			CASE 
				WHEN ec.LeaveTypeId IN (
					@UnpaidLeaveId, 
					@InsuranceLeaveId, 
					@PaternityLeaveId, 
					@MaternityLeaveId
				) THEN ISNULL(ec.LeaveDay, 0)
				ELSE 0.0
			END
		) AS TotalUnpaidLeaveDays,

		MAX(CASE 
				WHEN ce.Salary IS NOT NULL
					THEN ce.Salary
				WHEN es.IsLocal = 1
					THEN LocalSalary
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

		MAX(es.CompanyDate) AS CompanyDate,
		MAX(e.ConfirmedDate) AS ConfirmedDate
	FROM tmpEmployeeCalendar ec WITH (NOLOCK)
		INNER JOIN EmployeeSummary es WITH (NOLOCK) ON ec.EmpId = es.EmpId 
		INNER JOIN Employee e WITH (NOLOCK) ON ec.EmpId = e.EmpId AND ISNULL(e.isDeleted, 0) = 0
		LEFT JOIN EmployeeAttendance ea WITH(NOLOCK) ON ea.EmpId = ec.EmpId AND ec.WorkDate = ea.AttendanceDate
		LEFT JOIN [Group] g WITH (NOLOCK) ON g.GroupId = e.GroupId
		INNER JOIN CompanyEmployee ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
		LEFT JOIN SalaryStructureDetail std WITH (NOLOCK) ON std.JobLevelId = e.JobLevelId 
			AND ce.SalaryStructureId = std.SalaryStructureId
	WHERE MONTH(WorkDate) = MONTH(@Date)
		AND YEAR(WorkDate) = YEAR(@Date)
		AND ce.CompanyId = @CompanyId
		AND IsOffDay = 0
		AND e.ConfirmedDate IS NOT NULL
		AND (e.ResignedDate IS NULL OR e.ResignedDate >  @Date)
		AND IsTopManager = 0
	GROUP BY ec.EmpId
	ORDER BY ec.EmpId DESC
END