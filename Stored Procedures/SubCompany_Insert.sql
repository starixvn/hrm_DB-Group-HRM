/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[SubCompany_Insert] @CompanyId INT
	,@Name NVARCHAR(100)
	,@CreatedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20250724@Lilac.Nguyen
Task: insert sub company
DB: bodb_HRM
Original: 

Revisions:  

Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
    DECLARE @SubCompanyId INT
		,@xml XML
		,@logData NVARCHAR(MAX)

	IF EXISTS (
			SELECT 1
			FROM dbo.SubCompany WITH (NOLOCK)
			WHERE CompanyId = @CompanyId 
				AND [Name] = @Name
				AND IsActivated = 1
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The sub company ' + CONVERT(NVARCHAR(100), @Name) + ' has already exists.'

		RETURN
	END

	INSERT INTO dbo.SubCompany (
			CompanyId,
			[Name],
			CountryCode,
			IsActivated,
			ModifiedBy,
			ModifiedDate
		)
		VALUES (
			@CompanyId,
			@Name,
			NULL,
			1,
			@CreatedBy,
			GETDATE()
		)

	SELECT @SubCompanyId = SCOPE_IDENTITY()

	SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
			,SubCompanyId AS '@SubCompanyId'
		FROM dbo.SubCompany WITH (NOLOCK)
		WHERE SubCompanyId = @SubCompanyId
		FOR XML PATH('Row'), TYPE
		)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @CreatedBy
		,@ObjectTypeId = 4
		,@ObjectId = @SubCompanyId
		,@OldData = NULL
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

END;