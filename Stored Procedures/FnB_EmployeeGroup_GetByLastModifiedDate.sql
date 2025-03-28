/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR  PROCEDURE [dbo].[FnB_EmployeeGroup_GetByLastModifiedDate] 
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
		,CASE WHEN e.OldEmpId IS NOT NULL THEN e.OldEmpId ELSE e.EmpId END AS LeaderId
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
		LEFT JOIN dbo.GroupManager AS mng WITH (NOLOCK) ON g.GroupId = mng.GroupId
		LEFT JOIN dbo.Section AS s WITH (NOLOCK) ON g.SectionId = s.SectionId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON mng.EmpId = e.EmpId
		AND mng.RoleId = 1
	WHERE g.CompanyId = @CompanyId
		AND @LastModifiedDate IS NULL
		OR ISNULL(g.ModifiedDate, g.CreatedDate) > @LastModifiedDate
	ORDER BY g.ModifiedDate
END
GO
