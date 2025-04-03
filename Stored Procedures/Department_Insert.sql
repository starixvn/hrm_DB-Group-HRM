/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Department_Insert] @Code VARCHAR(50)
	,@Name NVARCHAR(200)
	,@UnitId INT
	,@IsActive BIT
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: 20200521@Lilac.Nguyen
Task: Insert Department
DB: HRM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.Department WITH (NOLOCK)
			WHERE Code = @Code AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Department  ' + @Code + ' has already exists'

		RETURN
	END
	
    DECLARE @OldDepartmentId INT

    SELECT @OldDepartmentId = MAX(e.OldDepartmentId)
    FROM dbo.Department AS e WITH (NOLOCK)
    WHERE CompanyId = @CompanyId

    SET @OldDepartmentId = ISNULL(@OldDepartmentId, 0) + 1

	INSERT INTO dbo.Department(
		[Code]
		,[Name]
		,[UnitId]
		,[IsActive]
		,[ModifiedBy]
		,[ModifiedDate]
		,[IsDeleted]
		,[CompanyId]
		,[OldDepartmentId]
		)
	VALUES (
		@Code
		,@Name
		,@UnitId
		,@IsActive
		,@ModifiedBy
		,GETDATE()
		,0
		,@CompanyId
		,@OldDepartmentId
		)
END