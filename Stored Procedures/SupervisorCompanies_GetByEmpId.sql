/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[SupervisorCompanies_GetByEmpId] @EmpId INT
AS
/*
Created: Jay.Do@20250704
Task: get supervisor companies
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT DISTINCT CompanyId 
	FROM GroupSupervisor gs  WITH (NOLOCK)
	INNER JOIN dbo.[Group] g WITH (NOLOCK) ON gs.GroupId = g.GroupId
	WHERE gs.OwnerId = @EmpId
END
GO


