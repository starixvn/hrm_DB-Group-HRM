/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER   PROCEDURE [dbo].[FnB_EmployeeGroup_GetByLastModifiedDate] 
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
ALTER   PROCEDURE [dbo].[FnB_EmployeeGroup_GetByLastModifiedDate] 
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

	SELECT g.GroupId AS TeamId
		,g.SectionId AS DepartmentId
		,g.Code
		,g.[Name]
		,mng.EmpId AS LeaderId
		,g.[Rank]
		,ISNULL(g.IsDeleted, 0) AS IsDeleted
		,CASE 
			WHEN g.ModifiedDate IS NULL THEN g.CreatedDate
			ELSE g.ModifiedDate
			END AS ModifiedDate
		,OldGroupId
	FROM dbo.[Group] AS g WITH (NOLOCK)
		LEFT JOIN dbo.GroupManager AS mng WITH (NOLOCK) ON g.GroupId = mng.GroupId
		AND mng.RoleId = 1
	WHERE CompanyId = @CompanyId
		AND @LastModifiedDate IS NULL
		OR ISNULL(g.ModifiedDate, g.CreatedDate) > @LastModifiedDate
	ORDER BY g.ModifiedDate
END
GO
