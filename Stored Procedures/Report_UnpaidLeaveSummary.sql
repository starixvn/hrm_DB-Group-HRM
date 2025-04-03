/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_UnpaidLeaveSummary] @Year INT
	,@EmpId INT = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
	,@SupervisorId INT = NULL
	,@LeaveType VARCHAR(MAX) = ''
	,@CompanyId INT
AS
/*
Created: 20151028@Quinn.Vo
Task: Get unpaid leave report.
DB: SMS-HRM
Original:

Revisions: by Oliver.Dang on 20190531
Param's Explanation:
LeaveType:
- 1: UPL
- 2: UPL Insurance
- 3: Paternity
- 4: Maternity
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromDate DATE = CAST(@year AS VARCHAR(5)) + '-01-01'
		,@toDate DATE = CAST(@year AS VARCHAR(5)) + '-12-31'
	DECLARE @tblLeaveTypes TABLE (LeaveTypeId INT)

	CREATE TABLE #tblRptGroupIds (GroupId INT)

	CREATE TABLE #tblRptEmployeeIds (EmpId INT)

	IF ISNULL(@LeaveType, '') <> ''
	BEGIN
		INSERT INTO @tblLeaveTypes (LeaveTypeId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@LeaveType, ',')
	END

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblRptGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END
	ELSE
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.Employee AS e WITH (NOLOCK)
					INNER JOIN dbo.EmployeeRole AS er WITH (NOLOCK) ON e.EmpId = er.EmployeeId
				WHERE EmpId = @SupervisorId
					AND er.RoleId IN (2, 3, 4, 5, 6, 7)
				)
		BEGIN
			SET @EmpId = @SupervisorId
		END
	END

	IF @EmpId IS NULL
	BEGIN
		INSERT INTO #tblRptEmployeeIds (EmpId)
		SELECT DISTINCT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 0, @CompanyId)
	END
	ELSE
	BEGIN
		INSERT INTO #tblRptEmployeeIds (EmpId)
		VALUES (@EmpId)
	END

	SELECT SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 1
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Jan
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 2
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Feb
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 3
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Mar
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 4
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Apr
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 5
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS May
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 6
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Jun
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 7
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Jul
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 8
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Aug
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 9
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Sep
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 10
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Oct
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 11
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Nov
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 12
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS [Dec]
		,SUM((CASE 
				WHEN lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS [LeaveBalance]
		,emp.EmpId
		,emp.NickName
		,emp.FullName
		,g.GroupId AS TeamId
		,g.[Name] AS Team
		,sec.Code AS Section
		,dep.Code AS Department
	FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
		AND ISNULL(emp.isDeleted, 0) = 0
		AND ISNULL(emp.[Enabled], 0) = 1
		INNER JOIN EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = emp.GroupId
		INNER JOIN dbo.Section AS sec WITH (NOLOCK) ON sec.SectionId = g.SectionId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = sec.DepartmentId
		LEFT JOIN @tblLeaveTypes AS lt ON lt.LeaveTypeId = empca.LeaveTypeId
		OR lt.LeaveTypeId = empca.LeaveTypeId2
	WHERE (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
		AND empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND empca.IsOffday = 0
		AND empca.IsHoliday = 0
		AND empca.IsLeaveDay = 1
		AND EXISTS (
			SELECT 1
			FROM #tblRptGroupIds AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND EXISTS (
			SELECT 1
			FROM #tblRptEmployeeIds AS tbl WITH (NOLOCK)
			WHERE emp.EmpId = tbl.EmpId
			)
	GROUP BY emp.EmpId
		,emp.NickName
		,emp.FullName
		,g.GroupId
		,g.[Name]
		,sec.Code
		,dep.Code
	HAVING SUM((CASE 
				WHEN lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) > 0
	ORDER BY g.[Name]

	DROP TABLE #tblRptGroupIds

	DROP TABLE #tblRptEmployeeIds
END






