/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

ALTER FUNCTION [dbo].[fnc_GetEmployeeByActorId] (
	@EmpId INT = NULL
	,@ExcludeUserDelete INT = 1
	,@IsShowUserInTeam BIT = 1
	,@CompanyId INT
	)
RETURNS TABLE
/*
	Created: Quinn.Vo@20151203
	Task: Get employee Id by actor id
	DB: HRM
	Original:

	Revisions:
		Henry.Dinh@2025-04-24: Merge action type 2, 3, 4, 5
	Param's Explanation:

*/
AS
RETURN WITH cteEmployee AS (
		SELECT e.EmpId
		FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = @CompanyId
		WHERE (
				(
					@ExcludeUserDelete = 1
					AND e.isDeleted = 0
					AND e.[Enabled] = 1
					)
				OR @ExcludeUserDelete = 0
				)
			AND (
				@EmpId IS NULL
				OR EXISTS (
					SELECT e1.EmpId
					FROM dbo.Employee AS e1 WITH (NOLOCK)
						INNER JOIN dbo.EmployeeRole AS er WITH (NOLOCK) ON e1.EmpId = er.EmployeeId
						AND er.RoleId IN (6, 7, 12) -- HR, SA, HR Assistant
					WHERE e1.EmpId = @EmpId
					)
				)
		
		UNION
		SELECT es.EmpId
		FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON es.EmpId = e.EmpId
			INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = @CompanyId
		WHERE es.OwnerId = @EmpId
			AND (
				(
					@ExcludeUserDelete = 1
					AND e.isDeleted = 0
					AND e.[Enabled] = 1
					)
				OR @ExcludeUserDelete = 0
				)
			AND es.IsDeleted = 0
			AND es.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
		
		UNION
		SELECT e.EmpId
		FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
			INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON gs.GroupId = e.GroupId
			INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = @CompanyId
		WHERE OwnerId = @EmpId
			AND (
				(
					@ExcludeUserDelete = 1
					AND e.isDeleted = 0
					AND e.[Enabled] = 1
					)
				OR @ExcludeUserDelete = 0
				)
			AND gs.IsDeleted = 0
			AND gs.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
				WHERE es.EmpId = e.EmpId
					AND es.ActionType = gs.ActionType
					AND es.IsDeleted = 0
				)
		
		UNION
		SELECT ee.EmpId
		FROM dbo.Employee AS e WITH (NOLOCK)
			INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.GroupId = e.GroupId
			INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = ee.EmpId AND ce.CompanyId = @CompanyId
		WHERE e.EmpId = @EmpId
			AND (
				(
					@ExcludeUserDelete = 1
					AND ee.isDeleted = 0
					AND ee.[Enabled] = 1
					)
				OR @ExcludeUserDelete = 0
				)
			AND @IsShowUserInTeam = 1

		UNION
		SELECT @EmpId
		FROM dbo.CompanyEmployee ce WITH (NOLOCK)
		WHERE ce.EmpId = @EmpId AND ce.CompanyId = @CompanyId
		)

SELECT EmpId
FROM cteEmployee
