/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[Currency_UpdateRounding] @CurrencyId INT
	,@Rounding SMALLINT
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20251119@Lilac.Nguyen
Task: update currency rounding
DB: HRM
Original: 

Revisions:  
	- 20251119@Lilac: init [Redmine: #244343]

Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	-- Initialize error variables
	SET @ErrCode = 0;
	SET @ErrMsg = '';

	DECLARE @xml XML;
	DECLARE @logData NVARCHAR(MAX);
	DECLARE @logOldData NVARCHAR(MAX);

	-- Validation: Check if currency exists
	IF NOT EXISTS (SELECT 1 FROM Currency WHERE Id = @CurrencyId)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'Currency not found';
		RETURN;
	END

	-- Get old data for activity log
	SET @xml = (
		SELECT Id AS '@Id'
			,CurrencyCode AS '@CurrencyCode'
			,Rounding AS '@Rounding'
		FROM dbo.Currency WITH (NOLOCK)
		WHERE Id = @CurrencyId
		FOR XML PATH('Row'), TYPE
	);
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

	-- Update currency rounding
	UPDATE dbo.Currency WITH (ROWLOCK, UPDLOCK)
	SET Rounding = @Rounding
	WHERE Id = @CurrencyId;

	-- Check if update was successful
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'No records were updated';
		RETURN;
	END

	-- Get new data for activity log
	SET @xml = (
		SELECT Id AS '@Id'
			,CurrencyCode AS '@CurrencyCode'
			,Rounding AS '@Rounding'
		FROM dbo.Currency WITH (NOLOCK)
		WHERE Id = @CurrencyId
		FOR XML PATH('Row'), TYPE
	);
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

	-- Log activity
	EXEC dbo.ActivityLog_Insert
		@ObjectTypeId = 11
		,@ObjectId = @CurrencyId
		,@UserId = @ModifiedBy
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT;

	-- Check if ActivityLog_Insert failed
	IF @ErrCode <> 0
	BEGIN
		RETURN;
	END

	SELECT @ErrCode = 0
		,@ErrMsg = 'Currency rounding updated successfully';
	RETURN;
END
GO