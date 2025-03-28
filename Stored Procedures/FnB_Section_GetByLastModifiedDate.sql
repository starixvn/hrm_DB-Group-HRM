/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[FnB_Section_GetByLastModifiedDate]
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
AS
/*
Created: 20230220@Quinn.Vo
Task: Get section by last modified date.
DB: HRM
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(YYYY, -10, GETDATE())
	END

	SELECT CASE WHEN s.OldSectionId IS NOT NULL THEN s.OldSectionId ELSE s.SectionId END as SectionId
      ,s.[Code]
      ,s.[Name]
      ,CASE WHEN d.OldDepartmentId IS NOT NULL THEN d.OldDepartmentId ELSE d.DepartmentId END as DepartmentId
      ,s.[IsActive]
      ,s.[ModifiedDate]
      ,s.[IsDeleted]
	FROM dbo.Section AS s WITH (NOLOCK) 
	LEFT JOIN dbo.Department as d WITH (NOLOCK) ON s.DepartmentId = d.DepartmentId
	WHERE s.ModifiedDate > @LastModifiedDate
		AND s.CompanyId = @CompanyId
	
END