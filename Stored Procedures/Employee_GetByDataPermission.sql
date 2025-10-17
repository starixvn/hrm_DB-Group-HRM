/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetByDataPermission]
(
	@UserId INT
	,@CompanyId INT
	,@ActionType INT = NULL
	,@IsViewAll BIT = 0
	,@IsViewEmployeeAssigned BIT = 0
	,@IsShowUserInTeam BIT = 0
)
AS
/*
	Created: 20251001@Mira
	Task: Setting one account manages across HRM
	DB: bodb_HRM

	Revisions:
		20251001@Mira: GetEmployeeAssigned [Redmine: #240215]
        20251017@Tim: get employee by UserId

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @tmpEmp TABLE (EmpId INT)

    INSERT INTO @tmpEmp (EmpId)
    SELECT EmpId
    FROM dbo.CompanyEmployee WITH (NOLOCK)
    WHERE UserId = @UserId
        AND [Enabled] = 1
        AND IsDeleted = 0;

	WITH cteByViewAllEmpCompany AS (
		SELECT ce.EmpId
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
			INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId 
		WHERE ce.CompanyId = @CompanyId
            AND @IsViewAll = 1
	), 
	cteBySupervisor AS (
		SELECT ce.EmpId
		FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = es.EmpId
		WHERE ce.CompanyId = @CompanyId
            AND es.OwnerId IN (
                SELECT EmpId FROM @tmpEmp
            )
		    AND es.IsDeleted = 0
		    AND @IsViewEmployeeAssigned = 1
	),
	cteByGroupSupervisor AS (
		SELECT ce.EmpId
		FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.GroupId = gs.GroupId
		WHERE ce.CompanyId = @CompanyId
            AND gs.OwnerId IN (
                SELECT EmpId FROM @tmpEmp
            )
		    AND gs.IsDeleted = 0
		    AND ce.EmpId NOT IN (
			    SELECT es.EmpId
			    FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			    WHERE es.EmpId = ce.EmpId
				    AND es.ActionType = gs.ActionType
				    AND es.IsDeleted = 0
		    )
		    AND @IsViewEmployeeAssigned = 1
	),
	cteBySameGroup AS (
		SELECT ce.EmpId
		FROM dbo.CompanyEmployee AS e WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.GroupId = e.GroupId
		WHERE ce.CompanyId = @CompanyId
            AND e.EmpId IN (
                SELECT EmpId FROM @tmpEmp
            )
            AND @IsShowUserInTeam = 1
			AND @IsViewEmployeeAssigned = 1
	),
	cteBySelf AS (
		SELECT ce.EmpId
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		WHERE ce.CompanyId = @CompanyId
            AND ce.EmpId IN (
                SELECT EmpId FROM @tmpEmp
            )
			AND @IsViewEmployeeAssigned = 1
	),
	cteAll AS (
		SELECT EmpId FROM cteByViewAllEmpCompany
		UNION
		SELECT EmpId FROM cteBySupervisor
		UNION
		SELECT EmpId FROM cteByGroupSupervisor
		UNION
		SELECT EmpId FROM cteBySameGroup
		UNION
		SELECT EmpId FROM cteBySelf
	)

	SELECT DISTINCT EmpId
	FROM cteAll 
END