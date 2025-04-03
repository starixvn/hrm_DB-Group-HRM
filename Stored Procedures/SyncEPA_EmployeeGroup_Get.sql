
/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[SyncEPA_EmployeeGroup_Get] 
	@FromDate DATETIME = NULL
	,@CompanyId INT 
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

	IF @FromDate IS NOT NULL
	BEGIN
		SELECT @FromDate = DATEADD(HH, - 1, @FromDate)
	END

	SELECT CASE WHEN g.OldGroupId IS NOT NULL THEN g.OldGroupId ELSE g.GroupId END  AS TeamId
		,CASE WHEN s.OldSectionId IS NOT NULL THEN s.OldSectionId ELSE s.SectionId END AS DepartmentId
		,g.Code
		,g.[Name]
		,CASE WHEN emp.OldEmpId IS NOT NULL THEN emp.OldEmpId ELSE emp.EmpId END  AS LeaderId
		,g.[Rank]
		,ISNULL(g.IsDeleted, 0) AS IsDeleted
		,CASE 
			WHEN g.ModifiedDate IS NULL THEN g.CreatedDate
			ELSE g.ModifiedDate
			END AS ModifiedDate
	FROM dbo.[Group] AS g WITH (NOLOCK)
		LEFT JOIN dbo.GroupManager AS mng WITH (NOLOCK) ON g.GroupId = mng.GroupId
		AND mng.RoleId = 1 -- head
		LEFT JOIN dbo.Employee AS emp ON mng.EmpId = emp.EmpId 
		LEFT JOIN dbo.CompanyEmployee AS ce ON ce.EmpId = emp.EmpId AND ce.CompanyId = @CompanyId
		LEFT JOIN dbo.Section AS s ON g.SectionId = s.SectionId AND s.CompanyId = @CompanyId
	WHERE g.CompanyId = @CompanyId  AND (@FromDate IS NULL OR ISNULL(g.ModifiedDate, g.CreatedDate) > @FromDate)
	ORDER BY TeamId
END





