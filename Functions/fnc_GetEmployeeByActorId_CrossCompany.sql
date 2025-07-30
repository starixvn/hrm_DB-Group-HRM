/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

CREATE OR ALTER FUNCTION [dbo].[fnc_GetEmployeeByActorId_CrossCompany] (
	@EmpId INT = NULL
	,@ExcludeUserDelete INT = 1
	,@IsShowUserInTeam BIT = 1
	,@CompanyId INT
	)
RETURNS TABLE
/*
	Created: Hank.Nguyen@20250606
	Task: Get employee Id by actor id
	DB: bodb_HRM

	Revisions:
        20250606@Hank: add @IsShowCrossCompany
	Param's Explanation:
*/
AS
RETURN
WITH cteByRole AS (
	SELECT e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
	    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = @CompanyId
	WHERE @EmpId IS NULL
	   OR EXISTS (
			SELECT 1
			FROM dbo.Employee AS emp WITH (NOLOCK)
                INNER JOIN dbo.EmployeeRole AS er WITH (NOLOCK) ON emp.EmpId = er.EmployeeId
			WHERE er.EmployeeId = @EmpId
                AND er.RoleId IN (6, 7, 12) -- HR, SA, HR Assistant
	   )
),
cteBySupervisor AS (
	SELECT e.EmpId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
	    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = es.EmpId
	WHERE es.OwnerId = @EmpId
	  AND es.IsDeleted = 0
	  AND es.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
),
cteByGroupSupervisor AS (
	SELECT e.EmpId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
	    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON gs.GroupId = e.GroupId
	WHERE gs.OwnerId = @EmpId
	  AND gs.IsDeleted = 0
	  AND gs.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
	  AND e.EmpId NOT IN (
			SELECT es.EmpId
			FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			WHERE es.EmpId = e.EmpId
			  AND es.ActionType = gs.ActionType
			  AND es.IsDeleted = 0
		)
),
cteBySameGroup AS (
	SELECT ee.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
	    INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.GroupId = e.GroupId
	    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ee.EmpId AND ce.CompanyId = @CompanyId
	WHERE e.EmpId = @EmpId AND @IsShowUserInTeam = 1
),
cteBySelf AS (
	SELECT ce.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
	WHERE ce.EmpId = @EmpId AND ce.CompanyId = @CompanyId
),
cteAll AS (
	SELECT EmpId FROM cteByRole
	UNION ALL
	SELECT EmpId FROM cteBySupervisor
	UNION ALL
	SELECT EmpId FROM cteByGroupSupervisor
	UNION ALL
	SELECT EmpId FROM cteBySameGroup
	UNION ALL
	SELECT EmpId FROM cteBySelf
)

SELECT DISTINCT e.EmpId
FROM cteAll AS ca
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = ca.EmpId
WHERE (
    (@ExcludeUserDelete = 1 AND e.isDeleted = 0 AND e.[Enabled] = 1)
	OR @ExcludeUserDelete = 0
    )