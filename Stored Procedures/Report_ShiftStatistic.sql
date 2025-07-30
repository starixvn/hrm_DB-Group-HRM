/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Report_ShiftStatistic] @SupervisorId INT
	,@fromDate DATE
	,@toDate DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@isShowWholeCompany BIT = 0
	,@isLocal BIT = NULL
	,@companyId INT
AS
/*
Created: Tim.Trinh@2019-11-12
Task: shift statistic report
DB: HRM_SMS
Original:
Revisions:
	- 20250619@Henry: fix ambiguous column error migrate nex
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tblGroupId TABLE (GroupId INT)
	DECLARE @tblEmployeeId TABLE (EmpId INT)

	IF ISNULL(@TeamIds, '') <> ''
		INSERT INTO @tblGroupId (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	--ELSE
	--BEGIN
	--	INSERT INTO @tblGroupId (GroupId)
	--	SELECT GroupId
	--	FROM dbo.[Group] WITH (NOLOCK)
	--	WHERE IsDeleted = 0
	--END

	IF @isShowWholeCompany = 0
	BEGIN
		INSERT INTO @tblEmployeeId (EmpId)
		SELECT es.OwnerId
		FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON es.OwnerId = emp.EmpId
			INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId AND ce.CompanyId = @companyId
		WHERE es.ActionType = 4
			AND es.EmpId = @SupervisorId
			AND emp.[Enabled] = 1
			AND ISNULL(es.IsDeleted, 0) = 0
		
		UNION
		SELECT emp.EmpId
		FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
			INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
			INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId AND ce.CompanyId = @companyId
		WHERE gs.OwnerId = @SupervisorId
			AND gs.ActionType = 4
			AND emp.[Enabled] = 1
			AND ISNULL(gs.IsDeleted, 0) = 0
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
				WHERE emp.EmpId = es.OwnerId
					AND es.ActionType = 4
					AND ISNULL(es.IsDeleted, 0) = 0
				)
	END
	ELSE
	BEGIN
		INSERT INTO @tblEmployeeId (EmpId)
		SELECT emp.EmpId
		FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId AND ce.CompanyId = @companyId
		WHERE emp.[Enabled] = 1
	END

	SELECT shift.ShiftId
		,shift.Code
		,empca.WorkDate
		,COUNT(1) AS Total
	FROM dbo.Shift AS shift WITH (NOLOCK)
		INNER JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON shift.ShiftId = empca.ShiftId
		AND ISNULL(empca.ShiftId, 0) <> 0
		AND empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND empca.IsLeaveDay = 0
		INNER JOIN @tblEmployeeId AS tblemp ON empca.EmpId = tblemp.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON tblemp.EmpId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON tblemp.EmpId = empsum.EmpId
	WHERE (
			@isLocal IS NULL
			OR empsum.IsLocal = @isLocal
			)
		AND EXISTS (
			SELECT 1
			FROM @tblGroupId AS tblgr
			WHERE tblgr.GroupId = emp.GroupId
			)
	GROUP BY shift.ShiftId
		,shift.Code
		,empca.WorkDate
END

