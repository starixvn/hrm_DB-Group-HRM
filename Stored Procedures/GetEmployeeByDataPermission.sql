/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[GetEmployeeByDataPermission] 
	@EmpId INT = NULL
	,@ActionType INT = NULL
	,@CompanyId INT
	,@IsViewAll BIT = 0
	,@IsViewEmployeeAssigned BIT = 0
	,@IsShowUserInTeam BIT = 0
AS
/*
	Created: 20251001@Mira
	Task: Setting one account manages across HRM
	DB: bodb_HRM

	Revisions:
		20251001@Mira: GetEmployeeAssigned [Redmine: #240215]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	WITH cteByViewAllEmpCompany AS (
		SELECT ce.EmpId
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
			INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId 
		WHERE ce.CompanyId = @CompanyId AND @IsViewAll = 1
	), 
	cteBySupervisor AS (
		SELECT e.EmpId
		FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS e WITH (NOLOCK) ON e.EmpId = es.EmpId
		WHERE es.OwnerId = @EmpId
		  AND es.IsDeleted = 0
		  AND @IsViewEmployeeAssigned = 1
	),
	cteByGroupSupervisor AS (
		SELECT ce.EmpId
		FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.GroupId = gs.GroupId
		WHERE gs.OwnerId = @EmpId
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
		SELECT ee.EmpId
		FROM dbo.CompanyEmployee AS e WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS ee WITH (NOLOCK) ON ee.GroupId = e.GroupId AND ee.CompanyId = @CompanyId
		WHERE e.EmpId = @EmpId AND @IsShowUserInTeam = 1
			AND @IsViewEmployeeAssigned = 1
	),
	cteBySelf AS (
		SELECT ce.EmpId
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		WHERE ce.EmpId = @EmpId
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
END;