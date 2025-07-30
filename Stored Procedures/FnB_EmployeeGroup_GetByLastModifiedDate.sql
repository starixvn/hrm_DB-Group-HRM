/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[FnB_EmployeeGroup_GetByLastModifiedDate]
(
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
)
AS
/*
    Created: 20140320@Quinn.Vo
    Task: Get all groups from change date
    DB: bodb_HRM

    Revisions:
    - 2024-03-21: Added support for secondment employee groups
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NOT NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(HH, - 1, @LastModifiedDate)
	END

	-- Get regular employee groups
	SELECT DISTINCT d.DepartmentId AS SectionId
		,g.Code
		,g.[Name]
		,g.[Rank]
		,ISNULL(g.IsDeleted, 0) AS IsDeleted
		,CASE 
			WHEN g.ModifiedDate IS NULL THEN g.CreatedDate
			ELSE g.ModifiedDate
			END AS ModifiedDate
		,g.GroupId AS TeamId
		,1 as DataSource
	FROM dbo.[Group] AS g WITH (NOLOCK)
	    LEFT JOIN dbo.Department AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
	WHERE g.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR ISNULL(g.ModifiedDate, g.CreatedDate) > @LastModifiedDate)

	UNION

	-- Get secondment employee groups
	SELECT DISTINCT d.DepartmentId AS SectionId
		,g.Code
		,g.[Name]
		,g.[Rank]
		,ISNULL(g.IsDeleted, 0) AS IsDeleted
		,CASE 
			WHEN g.ModifiedDate IS NULL THEN g.CreatedDate
			ELSE g.ModifiedDate
			END AS ModifiedDate
		,g.GroupId AS TeamId
		,2 as DataSource
	FROM dbo.[Group] AS g WITH (NOLOCK)
	    LEFT JOIN dbo.Department AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
	    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.GroupId = g.GroupId
	    INNER JOIN dbo.CompanySecondmentEmployee AS cse WITH (NOLOCK) ON cse.EmpId = e.EmpId
	WHERE cse.CompanyId = @CompanyId
END