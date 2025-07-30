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

	SELECT e.EmpId AS EmployeeId
		,e.FullName
		,e.NickName
	FROM dbo.Employee AS e WITH (NOLOCK)
	WHERE e.[Enabled] = 1
		AND e.isDeleted = 0
		AND (
			e.NickName LIKE @q
			OR e.FullName LIKE @q
			)
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary AS esum WITH (NOLOCK)
			WHERE esum.EmpId = e.EmpId
				AND esum.IsTopManager = 1
			)
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tblgr
			WHERE e.GroupId = tblgr.GroupId
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
					AND es.OwnerId = e.EmpId
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
				WHERE gs.OwnerId = @ActorId
					AND ISNULL(gs.IsDeleted, 0) = 0
					AND gs.ActionType = @ShiftManagerRoleId
					AND e.GroupId = gs.GroupId
				)
			)
	ORDER BY e.NickName

	DROP TABLE #tblGroupIds
END