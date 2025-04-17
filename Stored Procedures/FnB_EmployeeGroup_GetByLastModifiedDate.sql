/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NOT NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(HH, - 1, @LastModifiedDate)
	END

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
	FROM dbo.[Group] AS g WITH (NOLOCK)
	    LEFT JOIN dbo.Department AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
	WHERE g.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR ISNULL(g.ModifiedDate, g.CreatedDate) > @LastModifiedDate)
END