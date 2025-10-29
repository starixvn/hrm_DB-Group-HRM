/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[AllowanceItem_Edit] (
	@AllowanceItemSettingId INT,
	@ItemName NVARCHAR(255),
	@Amount NVARCHAR(255),
	@IsPercent BIT,
	@IsActive BIT,
	@ModifiedBy INT
)
AS
/*
Created: 20251021@Jay.Do
Task: edit allowance item
DB: HRM
Original: 

Revisions:  
		20251029@Jay.Do: allowance item [Redmine: #241812]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @xml XML,
		@logData NVARCHAR(MAX),
		@logOldData NVARCHAR(MAX) = NULL;

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
			WHERE AllowanceItemSettingId = @AllowanceItemSettingId
			FOR XML PATH('Row')
				,TYPE
			)

	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	
	UPDATE [dbo].[AllowanceItemSetting]
	SET [ItemName] = @ItemName,
		[Amount] = @Amount,
		[IsPercent] = @IsPercent,
		[IsActive] = @IsActive,
		[ModifiedBy] = @ModifiedBy,
		[ModifiedDate] = GETDATE()
	WHERE [AllowanceItemSettingId] = @AllowanceItemSettingId

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
			WHERE AllowanceItemSettingId = @AllowanceItemSettingId
			FOR XML PATH('Row')
				,TYPE
			)

	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 8
		,@ActionId = 19
		,@ObjectId = @AllowanceItemSettingId
		,@OldData = @logOldData
		,@Data = @logData
END