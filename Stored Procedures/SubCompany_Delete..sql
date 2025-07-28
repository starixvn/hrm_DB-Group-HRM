/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[SubCompany_Delete]
	@SubCompanyId INT
	,@DeletedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
    Created: 20250724@Lilac.Nguyen
    Task: delete sub company
    DB: bodb_HRM

    Revisions:

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @xml XML
        ,@logOldData NVARCHAR(MAX)

	IF EXISTS (
		SELECT 1
		FROM dbo.CompanyEmployee WITH (NOLOCK)
		WHERE SubCompanyId = @SubCompanyId
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The sub company cannot be deleted because it is already in use.'

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
	
	DELETE dbo.SubCompany WITH (ROWLOCK)
    WHERE SubCompanyId = @SubCompanyId

	EXEC dbo.ActivityLog_Insert @UserId = @DeletedBy
		,@ObjectTypeId = 6
		,@ObjectId = @SubCompanyId
		,@OldData = @logOldData
		,@Data = NULL
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END