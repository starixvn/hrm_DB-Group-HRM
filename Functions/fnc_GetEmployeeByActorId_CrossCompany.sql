/*<info serverAlias="HRM-bodb_HRM" selecters="wsv_hrm" isFunction="1"></info>*/

ALTER   FUNCTION [dbo].[fnc_GetEmployeeByActorId_CrossCompany] (
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
        20250813@Jay: change db structure [Redmine: #235678]
	Param's Explanation:
*/
AS
RETURN
WITH cteByRole AS (
	SELECT ce.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
	WHERE (@EmpId IS NULL
	   OR EXISTS (
			SELECT 1
			FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
                INNER JOIN dbo.EmployeeRole AS er WITH (NOLOCK) ON ce.EmpId = er.EmployeeId
			WHERE er.EmployeeId = @EmpId
                AND er.RoleId IN (6, 7, 12) -- HR, SA, HR Assistant
	   ))
	   AND ce.CompanyId = @CompanyId
),
cteBySupervisor AS (
	SELECT ce.EmpId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
	    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = es.EmpId
	WHERE es.OwnerId = @EmpId
	  AND es.IsDeleted = 0
	  AND es.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
),
cteByGroupSupervisor AS (
	SELECT ce.EmpId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
	    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON gs.GroupId = ce.GroupId
	WHERE gs.OwnerId = @EmpId
	  AND gs.IsDeleted = 0
	  AND gs.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
	  AND ce.EmpId NOT IN (
			SELECT es.EmpId
			FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			WHERE es.EmpId = ce.EmpId
			  AND es.ActionType = gs.ActionType
			  AND es.IsDeleted = 0
		)
),
cteBySameGroup AS (
	SELECT cee.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
	    INNER JOIN dbo.CompanyEmployee AS cee WITH (NOLOCK) ON cee.GroupId = ce.GroupId
	WHERE ce.EmpId = @EmpId 
		AND @IsShowUserInTeam = 1
		AND ce.CompanyId = @CompanyId
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

SELECT DISTINCT ce.EmpId
FROM cteAll AS ca
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ca.EmpId
WHERE (
    (@ExcludeUserDelete = 1 AND ce.isDeleted = 0 AND ce.[Enabled] = 1)
	OR @ExcludeUserDelete = 0
    )