/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Section_GetById]
	@SectionId INT,
	@CompanyId SMALLINT
AS
/*
Created: 20200520@Quinn.Vo
Task: Get by dectionId.
DB: HRM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT sec.[SectionId]
		,sec.[Code]
		,sec.[Name]
		,sec.IsActive
		,dep.DepartmentId
		,dep.Name
	FROM dbo.Section AS sec WITH (NOLOCK)
	LEFT JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = sec.DepartmentId
	WHERE sec.SectionId = @SectionId
		AND sec.CompanyId = @CompanyId

END

