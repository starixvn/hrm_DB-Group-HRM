/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Unit_Update] @UnitId INT
	,@Code VARCHAR(20)
	,@Name VARCHAR(100)
	,@IsActive BIT = NULL
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20200521@Patsy.Doan
Task: Update Unit.
DB: HRM

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @CompanyId SMALLINT

    SELECT @CompanyId = CompanyId
    FROM dbo.Unit WITH (NOLOCK)
    WHERE UnitId = @UnitId

	IF EXISTS (
			SELECT 1
			FROM dbo.Unit WITH (NOLOCK)
			WHERE CompanyId = @CompanyId
                AND Code = @Code
				AND UnitId <> @UnitId
                AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Unit code ' + @Code + ' has already exists'

		RETURN
	END

	UPDATE dbo.Unit WITH (ROWLOCK, UPDLOCK)
	SET [Code] = @Code
		,[Name] = @Name
		,[IsActive] = @IsActive
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = GETDATE()
	WHERE UnitId = @UnitId
END