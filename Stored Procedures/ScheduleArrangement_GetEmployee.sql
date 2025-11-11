/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ScheduleArrangement_GetEmployee]
(
    @ActorId INT
	,@TeamIds VARCHAR(MAX) = ''
	,@Query NVARCHAR(256) = ''
	,@IsIFrame BIT = 0
    ,@IsEditScheduleUnlimited BIT = 0
)
AS
/*
    Created: 20190502@Tim
    Task: get employee
    DB: bodb_HRM

    Revisions:
        20250813@Jay: change db structure [Redmine: #235678]
        20251020@Mira: get deleted/disable user [Redmine: #241816]
        20251110@Tim: unify team and personal setting [Redmine: #243412]
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
		INNER JOIN dbo.Employee AS e (NOLOCK) ON ce.UserId = e.UserId
	WHERE (
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
				WHERE es.OwnerId = @ActorId
					AND es.ActionType = @ShiftManagerRoleId
					AND es.EmpId = ce.EmpId
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
				WHERE gs.OwnerId = @ActorId
					AND gs.ActionType = @ShiftManagerRoleId
					AND ce.GroupId = gs.GroupId
				)
			)
	ORDER BY ce.NickName ASC

	DROP TABLE #tblGroupIds
END