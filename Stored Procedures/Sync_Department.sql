/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Sync_Department] @FromDate DATETIME = NULL
	,@CompanyId INT
AS
/*
Created: 20171108@Tim.Trinh
Task: Get all departments from change date
DB: SMSHRM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @DepartmentIndex INT = 1000000
		,@UnitIndex INT = 2000000
		,@RootIndex INT = 3000000

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
	SELECT CASE WHEN s.OldSectionId IS NOT NULL THEN s.OldSectionId ELSE s.SectionId END
		,s.Code
		,s.[Name]
		,@DepartmentIndex + CASE WHEN d.OldDepartmentId IS NOT NULL THEN d.OldDepartmentId ELSE d.DepartmentId END
		,CASE 
			WHEN s.IsActive = 0
				OR s.IsDeleted = 1 THEN 1
			ELSE 0
			END
		,s.ModifiedDate
	FROM dbo.Section AS s WITH (NOLOCK)
	LEFT JOIN dbo.Department AS d  WITH (NOLOCK) on s.DepartmentId = d.DepartmentId AND d.CompanyId = @CompanyId
	WHERE s.CompanyId = @CompanyId

	INSERT INTO #tblDepartment (
		DepartmentId
		,Code
		,[Name]
		,ParentId
		,IsDeleted
		,ModifiedDate
		)
	SELECT @DepartmentIndex + CASE WHEN d.OldDepartmentId IS NOT NULL THEN d.OldDepartmentId ELSE d.DepartmentId END
		,d.Code
		,d.[Name]
		,@UnitIndex + CASE WHEN u.OldUnitId IS NOT NULL THEN u.OldUnitId ELSE u.UnitId END
		,CASE 
			WHEN d.IsActive = 0
				OR d.IsDeleted = 1 THEN 1
			ELSE 0
			END
		,d.ModifiedDate
	FROM dbo.Department d WITH (NOLOCK)
	LEFT JOIN dbo.Unit AS u WITH (NOLOCK) on u.UnitId = d.UnitId AND u.CompanyId = @CompanyId
	WHERE d.CompanyId = @CompanyId



	INSERT INTO #tblDepartment (
		DepartmentId
		,Code
		,[Name]
		,ParentId
		,IsDeleted
		,ModifiedDate
		)
	SELECT @UnitIndex + CASE WHEN OldUnitId IS NOT NULL THEN OldUnitId ELSE UnitId END
		,Code
		,[Name]
		,@RootIndex
		,CASE 
			WHEN IsActive = 0
				OR IsDeleted = 1 THEN 1
			ELSE 0
			END
		,ModifiedDate
	FROM dbo.Unit WITH (NOLOCK)
	WHERE CompanyId = @CompanyId

	SELECT *
	FROM #tblDepartment WITH (NOLOCK)
	WHERE @FromDate IS NULL
		OR ModifiedDate > @FromDate
	ORDER BY DepartmentId

	DROP TABLE #tblDepartment
END


