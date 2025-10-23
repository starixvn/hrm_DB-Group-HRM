/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE AllowanceItem_Edit (
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
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	UPDATE [dbo].[AllowanceItemSetting]
	SET [ItemName] = @ItemName,
		[Amount] = @Amount,
		[IsPercent] = @IsPercent,
		[IsActive] = @IsActive,
		[ModifiedBy] = @ModifiedBy,
		[ModifiedDate] = GETDATE()
	WHERE [AllowanceItemSettingId] = @AllowanceItemSettingId
END