/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ScheduleArrangement_GetEmployee] @ActorId INT
	,@TeamIds VARCHAR(MAX) = ''
	,@Query NVARCHAR(256) = ''
	,@IsIFrame BIT = 0
    ,@IsEditScheduleUnlimited BIT = 0
AS
/*
Created: Tim.Trinh@2019-05-02
Task: get employee
DB: HRM

Revisions:
        20250813@Jay: change db structure [Redmine: #235678]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ShiftManagerRoleId TINYINT = 4
		,@q NVARCHAR(258) = '%' + ISNULL(@Query, '') + '%'

	CREATE TABLE #tblGroupIds (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	SELECT ce.EmpId AS EmployeeId
		,e.FullName
		,ce.NickName
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN Employee e (NOLOCK) ON ce.UserId = e.UserId
	WHERE ce.[Enabled] = 1
		AND ce.isDeleted = 0
		AND (
			ce.NickName LIKE @q
			OR e.FullName LIKE @q
			)
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary AS esum WITH (NOLOCK)
			WHERE esum.EmpId = ce.EmpId
				AND ce.IsSpecialUser = 1
			)
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tblgr
			WHERE ce.GroupId = tblgr.GroupId
			)
		AND (
			@IsIFrame = 1
			OR @IsEditScheduleUnlimited = 1
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
				WHERE es.EmpId = @ActorId
					AND ISNULL(es.IsDeleted, 0) = 0
					AND es.ActionType = @ShiftManagerRoleId
					AND es.OwnerId = ce.EmpId
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
				WHERE gs.OwnerId = @ActorId
					AND ISNULL(gs.IsDeleted, 0) = 0
					AND gs.ActionType = @ShiftManagerRoleId
					AND ce.GroupId = gs.GroupId
				)
			)
	ORDER BY ce.NickName

	DROP TABLE #tblGroupIds
END