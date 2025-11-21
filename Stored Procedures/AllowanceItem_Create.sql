/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AllowanceItem_Create] (
	@PayrollItemSettingId INT,
	@ItemName NVARCHAR(255),
	@Amount NVARCHAR(255),
	@CurrencyId INT,
	@IsPercent BIT,
	@IsActive BIT,
	@ModifiedBy INT
)
AS
/*
	Created: 20251021@Jay.Do
	Task: create allowance item
	DB: HRM
	Original: 

	Revisions:  
		20251029@Jay.Do: allowance item [Redmine: #241812]
		20251114@Jay: enhance salary [Redmine: #244343]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @xml XML,
		@NewId INT,
		@logData NVARCHAR(MAX),
		@logOldData NVARCHAR(MAX) = NULL;
	
	INSERT INTO [dbo].[AllowanceItemSetting] 
			(PayrollItemSettingId, ItemName, Amount, IsPercent, CreatedBy, CreatedDate, IsActive, IsDeleted, CurrencyId)
	VALUES	(@PayrollItemSettingId, @ItemName, @Amount, @IsPercent, @ModifiedBy, GETDATE(), @IsActive, 0, @CurrencyId)

    SET @NewId = SCOPE_IDENTITY();
	
	SET @xml = (
			SELECT PayrollItemSettingId AS '@PayrollItemSettingId',
				ItemName AS '@ItemName',
				Amount AS '@Amount',
				CurrencyId AS '@CurrencyId',
				IsPercent AS '@IsPercent',
				CreatedBy AS '@CreatedBy',
				CreatedDate AS '@CreatedDate',
				IsActive AS '@IsActive',
				IsDeleted AS '@IsDeleted'
			FROM dbo.[AllowanceItemSetting] WITH (NOLOCK)
			WHERE AllowanceItemSettingId = @NewId
			FOR XML PATH('Row')
				,TYPE
			)

	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 8
		,@ActionId = 18
		,@ObjectId = @NewId
		,@OldData = @logOldData
		,@Data = @logData
END