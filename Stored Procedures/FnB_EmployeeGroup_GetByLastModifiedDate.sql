/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[FnB_EmployeeGroup_GetByLastModifiedDate] 
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
AS
/*
Created: 20140320@Quinn.Vo
Task: Get all groups from change date
DB: HRM
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NOT NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(HH, - 1, @LastModifiedDate)
	END

	SELECT CASE WHEN s.OldSectionId IS NOT NULL THEN s.OldSectionId ELSE s.SectionId END  AS DepartmentId
		,g.Code
		,g.[Name]
		,g.[Rank]
		,ISNULL(g.IsDeleted, 0) AS IsDeleted
		,CASE 
			WHEN g.ModifiedDate IS NULL THEN g.CreatedDate
			ELSE g.ModifiedDate
			END AS ModifiedDate
		,CASE 
			WHEN OldGroupId IS NULL THEN g.GroupId
			ELSE OldGroupId
			END AS TeamId
		,g.SectionId
	FROM dbo.[Group] AS g WITH (NOLOCK)
		LEFT JOIN dbo.Section AS s WITH (NOLOCK) ON g.SectionId = s.SectionId
	WHERE g.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR ISNULL(g.ModifiedDate, g.CreatedDate) > @LastModifiedDate)
	ORDER BY g.ModifiedDate
END
