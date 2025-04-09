/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SyncEPA_Department]
(
	@CompanyId INT,
    @FromDate DATETIME = NULL
)
AS
/*
    Created: 20171108@Tim.Trinh
    Task: Get all departments from change date
    DB: bodb_HRM

    Revisions:
        20250409@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @DepartmentIndex INT = 1000000
		,@UnitIndex INT = 2000000

	CREATE TABLE #tblDepartment (
		DepartmentId INT
		,Code VARCHAR(50)
		,[Name] NVARCHAR(200)
		,ParentId INT NULL
		,IsDeleted BIT
		,ModifiedDate DATETIME
		)

	INSERT INTO #tblDepartment (
		DepartmentId
		,Code
		,[Name]
		,ParentId
		,IsDeleted
		,ModifiedDate
		)
	SELECT d.DepartmentId AS SectionId
		,d.Code
		,d.[Name]
		,@DepartmentIndex + d.DepartmentId
		,CASE 
			WHEN d.IsActive = 0
				OR d.IsDeleted = 1 THEN 1
			ELSE 0
			END
		,d.ModifiedDate
	FROM dbo.Department AS d WITH (NOLOCK)
        INNER JOIN dbo.[Group] AS t WITH (NOLOCK) ON d.DepartmentId = t.DepartmentId
    WHERE t.CompanyId = @CompanyId

	INSERT INTO #tblDepartment (
		DepartmentId
		,Code
		,[Name]
		,ParentId
		,IsDeleted
		,ModifiedDate
		)
	SELECT @DepartmentIndex + d.DepartmentId
		,d.Code
		,d.[Name]
		,@UnitIndex + u.UnitId
		,CASE 
			WHEN d.IsActive = 0
				OR d.IsDeleted = 1 THEN 1
			ELSE 0
			END
		,d.ModifiedDate
	FROM dbo.Department d WITH (NOLOCK)
        INNER JOIN dbo.[Group] AS t WITH (NOLOCK) ON d.DepartmentId = t.DepartmentId
	    INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = d.UnitId
    WHERE t.CompanyId = @CompanyId

	INSERT INTO #tblDepartment (
		DepartmentId
		,Code
		,[Name]
		,IsDeleted
		,ModifiedDate
		)
	SELECT @UnitIndex + u.UnitId
		,u.Code
		,u.[Name]
		,CASE 
			WHEN u.IsActive = 0
				OR u.IsDeleted = 1 THEN 1
			ELSE 0
			END
		,u.ModifiedDate
	FROM dbo.Unit AS u WITH (NOLOCK)
        INNER JOIN dbo.Department d WITH (NOLOCK) ON u.UnitId = d.UnitId
        INNER JOIN dbo.[Group] AS t WITH (NOLOCK) ON d.DepartmentId = t.DepartmentId
    WHERE t.CompanyId = @CompanyId

	SELECT *
	FROM #tblDepartment WITH (NOLOCK)
	WHERE @FromDate IS NULL
		OR ModifiedDate > @FromDate
	ORDER BY DepartmentId

	DROP TABLE #tblDepartment
END