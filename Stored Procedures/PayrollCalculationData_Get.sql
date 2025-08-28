/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[PayrollCalculationData_Get]
(
	@CompanyId INT,
	@Date DATETIME
)
AS
/*
    Created: Jay.Do@20250730
    Task: get pay roll calculation data
    DB: bodb_HRM

    Revisions:
        20250730@Jay.Do: Get data for payroll calculation [Redmine: #233324]
		20250821@Jay: restructure for transfer [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @UnpaidLeaveId INT = 25,
        @InsuranceLeaveId INT = 41,
        @PaternityLeaveId INT = 14,
        @MaternityLeaveId INT = 12;

	SELECT 
		ea.EmpId,
		SUM(
			CASE 
				WHEN ea.AttendanceDate >= ce.CompanyDate THEN
					CASE 
						WHEN TotalWorkHours >= 8.92 THEN 1
						WHEN TotalWorkHours >= 3.92 THEN 0.5
						ELSE 0
					END
				ELSE 0
			END
		) AS TotalWorkingDays,

		SUM(
			CASE 
				WHEN ea.AttendanceDate < ce.CompanyDate THEN
					CASE 
						WHEN TotalWorkHours >= 8.92 THEN 1
						WHEN TotalWorkHours >= 3.92 THEN 0.5
						ELSE 0
					END
				ELSE 0
			END
		) AS TotalNewHireWorkingDays,
		MAX(CASE 
			WHEN e.ResignedDate IS NULL THEN 0
			ELSE 1
		END) AS IsResigned,
		MAX(CASE 
				WHEN ea.LeaveTypeId = @MaternityLeaveId THEN 1
				ELSE 0
			END) AS IsMaternityLeave,
		SUM(
			CASE 
				WHEN ea.LeaveTypeId IN (
					@UnpaidLeaveId, 
					@InsuranceLeaveId, 
					@PaternityLeaveId, 
					@MaternityLeaveId
				) THEN 1 
				ELSE 0 
			END
		) AS TotalUnpaidLeaves,
		MAX(LocalSalary) AS Salary,
		MAX(
			CASE 
				WHEN es.WorkingDays IS NOT NULL THEN es.WorkingDays
				ELSE g.LocalWorkingDays
			END
		) AS WorkingDays
	FROM EmployeeAttendance ea WITH (NOLOCK)
		LEFT JOIN EmployeeSummary es WITH (NOLOCK) ON ea.EmpId = es.EmpId 
		LEFT JOIN CompanyEmployee ce WITH (NOLOCK) ON ea.EmpId = ce.EmpId 
			AND ISNULL(ce.isDeleted, 0) = 0
		LEFT JOIN [Group] g WITH (NOLOCK) ON g.GroupId = ce.GroupId
		LEFT JOIN Employee e WITH (NOLOCK) ON e.UserId = ce.UserId
		LEFT JOIN SalaryStructureDetail std WITH (NOLOCK) ON std.JobLevelId = ce.JobLevelId 
			AND ce.SalaryStructureId = std.SalaryStructureId
	WHERE MONTH(AttendanceDate) = MONTH(@Date)
		AND YEAR(AttendanceDate) = YEAR(@Date)
		AND ce.CompanyId = @CompanyId
		AND ShiftId IS NOT NULL
		AND ISNULL(ce.isDeleted, 0) = 0
	GROUP BY ea.EmpId;
END