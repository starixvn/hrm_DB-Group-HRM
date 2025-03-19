/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Section_Get]
	@IsActive BIT = NULL,
	@CompanyId SMALLINT
AS
/*
Created: 20200520@Quinn.Vo
Task: Get all sections from change date
DB: NexEPA
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT sec.SectionId AS Id
      ,sec.Code
      ,sec.[Name]
      ,sec.IsActive
	  ,sec.ModifiedBy
      ,sec.ModifiedDate
	  ,dep.DepartmentId
	  ,dep.Code
	  ,dep.[Name]
	FROM dbo.Section AS sec WITH (NOLOCK)
	LEFT JOIN dbo.Department AS dep WITH (NOLOCK) ON sec.DepartmentId = dep.DepartmentId
	WHERE (sec.IsActive = @IsActive OR @IsActive IS NULL)
		AND sec.CompanyId = @CompanyId
		AND sec.IsDeleted  = 0
END
