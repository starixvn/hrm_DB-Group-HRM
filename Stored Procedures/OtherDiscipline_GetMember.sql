/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[OtherDiscipline_GetMember] @SupervisorId INT
	,@Query NVARCHAR(100) = ''
	,@CompanyId SMALLINT
AS
/*
Created: 20191205@Tim.Trinh
Task: Get member by Supervisor.
DB: SMSHRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF (ISNULL(@Query, '') <> '')
		SET @Query = '%' + @Query + '%'

	SELECT DISTINCT emp.EmpId AS EmployeeId
		,emp.NickName
		,emp.FullName
	FROM dbo.Employee AS emp WITH (NOLOCK)
		LEFT JOIN dbo.EmployeeSupervisor AS es WITH (NOLOCK) ON emp.EmpId = es.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
	WHERE (
			EXISTS (
				SELECT 1
				FROM EmployeeRole WITH (NOLOCK)
				WHERE EmployeeId = @SupervisorId
					AND RoleId IN (6, 7)
				)
			OR (
				es.OwnerId = @SupervisorId
				AND es.EmpId <> @SupervisorId
				AND es.ActionType = 8
				)
			)
		AND (
			emp.NickName LIKE '%' + @query + '%'
			OR emp.FullName LIKE '%' + @query + '%'
			)
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		AND ce.CompanyId = @CompanyId
	
	UNION
	SELECT DISTINCT emp.EmpId AS EmployeeId
		,emp.NickName
		,emp.FullName
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.GroupSupervisor AS gs WITH (NOLOCK) ON emp.GroupId = gs.GroupId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
	WHERE gs.OwnerId = @SupervisorId
		AND emp.EmpId <> @SupervisorId
		AND gs.ActionType = 8
		AND (
			emp.NickName LIKE '%' + @query + '%'
			OR emp.FullName LIKE '%' + @query + '%'
			)
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		AND ce.CompanyId = @CompanyId
END



