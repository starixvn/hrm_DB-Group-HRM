/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[AllowanceItem_Create] (
	@PayrollItemSettingId INT,
	@ItemName NVARCHAR(255),
	@Amount NVARCHAR(255),
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
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @xml XML,
		@NewId INT,
		@logData NVARCHAR(MAX),
		@logOldData NVARCHAR(MAX) = NULL;
	
	INSERT INTO [dbo].[AllowanceItemSetting] 
			(PayrollItemSettingId, ItemName, Amount, IsPercent, CreatedBy, CreatedDate, IsActive, IsDeleted)
	VALUES	(@PayrollItemSettingId, @ItemName, @Amount, @IsPercent, @ModifiedBy, GETDATE(), @IsActive, 0)

    SET @NewId = SCOPE_IDENTITY();
	
	SET @xml = (
			SELECT PayrollItemSettingId AS '@PayrollItemSettingId',
				ItemName AS '@ItemName',
				Amount AS '@Amount',
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