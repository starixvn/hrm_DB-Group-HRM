/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE FnB_EmployeeGroup_GetByLastModifiedDate 
	@LastModifiedDate DATETIME
AS
-- Author:		Jay
-- Create date: 17/03/2025
-- Description:	Sync Employee Group to F&B
BEGIN
	SET NOCOUNT ON;

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
	FROM dbo.[Group] AS g WITH (NOLOCK)
		LEFT JOIN dbo.GroupManager AS mng WITH (NOLOCK) ON g.GroupId = mng.GroupId
		AND mng.RoleId = 1
	WHERE @LastModifiedDate IS NULL
		OR ISNULL(g.ModifiedDate, g.CreatedDate) > @LastModifiedDate
	ORDER BY g.ModifiedDate
END
GO
