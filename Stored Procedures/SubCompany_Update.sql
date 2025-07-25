/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[SubCompany_Update] @CompanyId INT
	,@SubCompanyId INT
	,@Name NVARCHAR(100)
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20250724@Lilac.Nguyen
Task: update sub company
DB: bodb_HRM
Original: 

Revisions:  

Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
    DECLARE @xml XML
		,@logData NVARCHAR(MAX)
        ,@logOldData NVARCHAR(MAX)

	IF EXISTS (
			SELECT 1
			FROM dbo.SubCompany WITH (NOLOCK)
			WHERE CompanyId = @CompanyId 
				AND [Name] = @Name
				AND (@SubCompanyId IS NULL OR SubCompanyId <> @SubCompanyId)
				AND IsActivated = 1
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The sub company ' + CONVERT(NVARCHAR(100), @Name) + ' has already exists.'

		RETURN
	END

	SET @xml = (
			SELECT CompanyId AS '@CompanyId'
				,[Name] AS '@Name'
				,SubCompanyId AS '@SubCompanyId'
			FROM dbo.SubCompany WITH (NOLOCK)
			WHERE SubCompanyId = @SubCompanyId
			FOR XML PATH('Row'), TYPE
			)

		SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

		UPDATE dbo.SubCompany WITH (ROWLOCK, UPDLOCK)
		SET [Name] = @Name
			,[ModifiedBy] = @ModifiedBy
			,[ModifiedDate] = GETDATE()
		WHERE CompanyId = @CompanyId AND SubCompanyId = @SubCompanyId

	SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
			,SubCompanyId AS '@SubCompanyId'
		FROM dbo.SubCompany WITH (NOLOCK)
		WHERE SubCompanyId = @SubCompanyId
		FOR XML PATH('Row'), TYPE
		)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 4
		,@ObjectId = @SubCompanyId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

END;