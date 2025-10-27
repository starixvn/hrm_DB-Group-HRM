/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE   PROCEDURE [dbo].[AllowanceItem_Delete] (
	@AllowanceItemSettingId INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(200) = '' OUTPUT
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
	
	IF EXISTS(SELECT 1 
		FROM EmployeePayrollAllowance
		WHERE @AllowanceItemSettingId = AllowanceItemSettingId) 
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'Cannot delete an allowance item that is in use'

		RETURN
	END


	UPDATE AllowanceItemSetting
	SET IsDeleted = 1, IsActive = 0
	WHERE @AllowanceItemSettingId = AllowanceItemSettingId
END