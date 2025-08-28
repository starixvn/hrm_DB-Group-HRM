/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_ShiftStatisticDetail] @WorkDate DATE
	,@ShiftId INT = NULL
	,@EmployeeId INT = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
	,@SupervisorId INT = NULL
	,@IsShowWholeCompany BIT = 0
	,@CompanyId INT
AS
/*
Created: Tim.Trinh@2019-11-13
Task: shift statistic detail
DB: HRM_SMS
Original:
Revisions:
	- 20250619@Henry: fix ambiguous column error migrate nex
	- 20250814@Lilac: restructure for transfer [Redmine: #235678]
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tblGroupId TABLE (GroupId INT)
	DECLARE @tblEmployeeId TABLE (EmpId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO @tblGroupId (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	IF @isShowWholeCompany = 0
	BEGIN
		INSERT INTO @tblEmployeeId (EmpId)
		SELECT es.OwnerId
		FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = es.OwnerId AND ce.CompanyId = @CompanyId
		WHERE es.ActionType = 4
			AND es.EmpId = @SupervisorId
			AND ce.[Enabled] = 1
			AND ISNULL(es.IsDeleted, 0) = 0
		
		UNION
		SELECT ce.EmpId
		FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON gs.GroupId = ce.GroupId AND ce.CompanyId = @CompanyId
		WHERE gs.OwnerId = @SupervisorId
			AND gs.ActionType = 4
			AND ce.[Enabled] = 1
			AND ISNULL(gs.IsDeleted, 0) = 0
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
				WHERE ce.EmpId = es.OwnerId
					AND es.ActionType = 4
					AND ISNULL(es.IsDeleted, 0) = 0
				)
	END
	ELSE
	BEGIN
		INSERT INTO @tblEmployeeId (EmpId)
		SELECT ce.EmpId
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK) 
		WHERE ce.[Enabled] = 1 AND ce.CompanyId = @CompanyId
	END

	SELECT empca.WorkDate
		,ce.EmpId
		,ce.NickName
		,emp.FullName
		,gr.[Name] AS Team
		,shift.[Name] AS [Shift]
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce ON emp.UserId = ce.UserId
		INNER JOIN @tblEmployeeId AS tblemp ON ce.EmpId = tblemp.EmpId
		INNER JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON ce.EmpId = empca.EmpId
		AND empca.WorkDate = @WorkDate
		AND ISNULL(empca.ShiftId, 0) <> 0
		AND empca.IsLeaveDay = 0
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		INNER JOIN dbo.[Shift] AS shift WITH (NOLOCK) ON empca.ShiftId = shift.ShiftId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
	WHERE (
			@employeeId IS NULL
			OR ce.EmpId = @employeeId
			)
		AND (
			@isLocal IS NULL
			OR empsum.IsLocal = @isLocal
			)
		AND (
			@ShiftId IS NULL
			OR ISNULL(empca.ShiftId, 0) = @ShiftId
			)
		AND EXISTS (
			SELECT 1
			FROM @tblGroupId AS tblgr
			WHERE tblgr.GroupId = ce.GroupId
			)
END

