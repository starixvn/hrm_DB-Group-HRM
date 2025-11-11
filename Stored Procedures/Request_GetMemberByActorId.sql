/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Request_GetMemberByActorId] @EmpId INT = NULL
	,@ExcludeUserDelete INT = 1
	,@IsShowUserInTeam BIT = 1
AS
/*
Created: Otis.Vu@20230309
Task: Get member by actor id
DB: HRM
Original:

Revisions:
        20250813@Jay: change db structure [Redmine: #235678]
		20251111@Lilac: merge ActionType [Redmine: #243412]
Param's Explanation:
*/
BEGIN
	CREATE TABLE #tblEmployee (EmpId INT PRIMARY KEY)

	INSERT INTO #tblEmployee (EmpId)
	SELECT es.EmpId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON es.EmpId = ce.EmpId
	WHERE es.OwnerId = @EmpId
		AND (
			(
				@ExcludeUserDelete = 1
				AND ce.isDeleted = 0
				AND ce.[Enabled] = 1
				)
			OR @ExcludeUserDelete = 0
			)
		AND es.IsDeleted = 0
		AND es.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
	
	UNION
	SELECT ce.EmpId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON gs.GroupId = ce.GroupId
	WHERE OwnerId = @EmpId
		AND (
			(
				@ExcludeUserDelete = 1
				AND ce.isDeleted = 0
				AND ce.[Enabled] = 1
				)
			OR @ExcludeUserDelete = 0
			)
		AND gs.IsDeleted = 0
		AND gs.ActionType IN (2, 3)
	
	
	UNION
	SELECT ce.EmpId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON gs.GroupId = ce.GroupId
	WHERE OwnerId = @EmpId
		AND (
			(
				@ExcludeUserDelete = 1
				AND ce.isDeleted = 0
				AND ce.[Enabled] = 1
				)
			OR @ExcludeUserDelete = 0
			)
		AND gs.IsDeleted = 0
		AND gs.ActionType IN (4, 5)
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			WHERE es.EmpId = ce.EmpId
				AND es.ActionType = gs.ActionType
				AND es.IsDeleted = 0
			)
	
	UNION
	SELECT ce.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS cee WITH (NOLOCK) ON cee.GroupId = ce.GroupId
	WHERE ce.EmpId = @EmpId
		AND (
			(
				@ExcludeUserDelete = 1
				AND cee.isDeleted = 0
				AND cee.[Enabled] = 1
				)
			OR @ExcludeUserDelete = 0
			)
		AND @IsShowUserInTeam = 1
	
	UNION
	SELECT @EmpId

	SELECT DISTINCT EmpId
	FROM #tblEmployee WITH (NOLOCK)

	DROP TABLE #tblEmployee
END

