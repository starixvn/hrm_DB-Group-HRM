/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ScheduleArrangement_GetGroup]
(
    @ActorId INT
	,@IsIFrame BIT = 0
    ,@IsEditScheduleUnlimited BIT = 0
)
AS
/*
    Created: 20190502@Tim
    Task: get group
    DB: bodb_HRM

    Revisions:
	    20250812@Mira: change DB structure [Redmine: #235678]
        20251110@Tim: unify team and personal setting [Redmine: #243412]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ShiftManagerRoleId TINYINT = 4

	SELECT gr.GroupId AS TeamId
		,gr.Code
		,gr.[Name]
	FROM dbo.[Group] AS gr WITH (NOLOCK)
	WHERE gr.IsDeleted = 0
		AND (
			@IsIFrame = 1
			OR @IsEditScheduleUnlimited = 1
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
					INNER JOIN dbo.CompanyEmployee AS e WITH (NOLOCK) ON es.EmpId = e.EmpId
					AND e.[Enabled] = 1
					AND e.isDeleted = 0
				WHERE es.OwnerId = @ActorId
					AND ISNULL(es.IsDeleted, 0) = 0
					AND es.ActionType = @ShiftManagerRoleId
					AND gr.GroupId = e.GroupId
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
				WHERE gs.OwnerId = @ActorId
					AND ISNULL(gs.IsDeleted, 0) = 0
					AND gs.ActionType = @ShiftManagerRoleId
					AND gr.GroupId = gs.GroupId
				)
			)
	ORDER BY gr.Code ASC
END