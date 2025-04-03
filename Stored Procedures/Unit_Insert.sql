/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Unit_Insert] @Code VARCHAR(20)
	,@Name VARCHAR(100)
	,@IsActive BIT = 1
	,@CreatedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: 20200521@Patsy.Doan
Task: Insert Unit.
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.Unit WITH (NOLOCK)
			WHERE CompanyId = @CompanyId
                AND Code = @Code
                AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Unit code ' + @Code + ' has already exists'

		RETURN
	END
	
    DECLARE @OldUnitId INT
	
    SELECT @OldUnitId = MAX(OldUnitId)
    FROM dbo.Unit WITH (NOLOCK)
    WHERE CompanyId = @CompanyId

    SET @OldUnitId = ISNULL(@OldUnitId, 0) + 1

	INSERT INTO dbo.Unit(
		[Code]
		,[Name]
		,[ModifiedBy]
		,[ModifiedDate]
		,[IsActive]
		,[IsDeleted]
		,[CompanyId]
		,[OldUnitId]
		)
	VALUES (
		@Code
		,@Name
		,@CreatedBy
		,GETDATE()
		,@IsActive
		,0
		,@CompanyId
		,@OldUnitId
		)
END