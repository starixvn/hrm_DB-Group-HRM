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
        20250813@Jay: change db structure [Redmine: #235678]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF (ISNULL(@Query, '') <> '')
		SET @Query = '%' + @Query + '%'

	SELECT DISTINCT ce.EmpId AS EmployeeId
		,ce.NickName
		,e.FullName
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		LEFT JOIN dbo.EmployeeSupervisor AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
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
			ce.NickName LIKE '%' + @query + '%'
			OR e.FullName LIKE '%' + @query + '%'
			)
		AND ce.isDeleted = 0
		AND ce.[Enabled] = 1
		AND ce.CompanyId = @CompanyId
	
	UNION
	SELECT DISTINCT ce.EmpId AS EmployeeId
		,ce.NickName
		,e.FullName
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.GroupSupervisor AS gs WITH (NOLOCK) ON ce.GroupId = gs.GroupId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
	WHERE gs.OwnerId = @SupervisorId
		AND ce.EmpId <> @SupervisorId
		AND gs.ActionType = 8
		AND (
			ce.NickName LIKE '%' + @query + '%'
			OR e.FullName LIKE '%' + @query + '%'
			)
		AND ce.isDeleted = 0
		AND ce.[Enabled] = 1
		AND ce.CompanyId = @CompanyId
END