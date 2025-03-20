/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Sync_Department] @FromDate DATETIME = NULL
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
	SELECT SectionId
		,Code
		,[Name]
		,@DepartmentIndex + DepartmentId
		,CASE 
			WHEN IsActive = 0
				OR IsDeleted = 1 THEN 1
			ELSE 0
			END
		,ModifiedDate
	FROM dbo.Section WITH (NOLOCK)


	INSERT INTO #tblDepartment (
		DepartmentId
		,Code
		,[Name]
		,ParentId
		,IsDeleted
		,ModifiedDate
		)
	SELECT @DepartmentIndex + DepartmentId
		,Code
		,[Name]
		,@UnitIndex + UnitId
		,CASE 
			WHEN IsActive = 0
				OR IsDeleted = 1 THEN 1
			ELSE 0
			END
		,ModifiedDate
	FROM dbo.Department WITH (NOLOCK)

	INSERT INTO #tblDepartment (DepartmentId, Code, [Name], ParentId, IsDeleted, ModifiedDate)
	VALUES (@RootIndex, 'SMS', 'SMS', NULL, 0, GETDATE())

	INSERT INTO #tblDepartment (
		DepartmentId
		,Code
		,[Name]
		,ParentId
		,IsDeleted
		,ModifiedDate
		)
	SELECT @UnitIndex + UnitId
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

	SELECT *
	FROM #tblDepartment WITH (NOLOCK)
	WHERE @FromDate IS NULL
		OR ModifiedDate > @FromDate

	DROP TABLE #tblDepartment
END


