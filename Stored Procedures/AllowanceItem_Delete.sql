/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE   PROCEDURE [dbo].[AllowanceItem_Delete] (
	@AllowanceItemSettingId INT
)
AS
/*
Created: 20251021@Jay.Do
Task: delete allowance item
DB: HRM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	UPDATE AllowanceItemSetting
	SET IsDeleted = 1
	WHERE @AllowanceItemSettingId = AllowanceItemSettingId
END