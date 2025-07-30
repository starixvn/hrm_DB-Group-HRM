/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[SupervisorCompanies_GetByEmpId] @EmpId INT
AS
/*
Created: Jay.Do@20250704
Task: get supervisor companies
DB: HRM

Revisions:
	- 20250730@Jay: Add personal filter [Redmine: #233324]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT DISTINCT CompanyId 
	FROM GroupSupervisor gs  WITH (NOLOCK)
		INNER JOIN dbo.[Group] g WITH (NOLOCK) ON gs.GroupId = g.GroupId AND ISNULL(g.IsDeleted, 0) = 0
	WHERE gs.OwnerId = @EmpId
	    AND gs.IsDeleted = 0
	UNION

	SELECT DISTINCT CompanyId 
	FROM EmployeeSupervisor es  WITH (NOLOCK)
		INNER JOIN dbo.[CompanyEmployee] ce WITH (NOLOCK) ON ce.EmpId = es.EmpId AND ISNULL(ce.IsDeleted, 0) = 0
	WHERE es.OwnerId = @EmpId
	    AND es.IsDeleted = 0
END