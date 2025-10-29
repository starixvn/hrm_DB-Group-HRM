/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/
CREATE   PROCEDURE [dbo].[PayrollItemSettingType_Get]
(
    @CompanyId INT,
	@PayrollSettingCategory INT = 2
)
AS
/*
    Created: 20251029@Jay.Do
    Task: Get payroll item setting
    DB: bodb_HRM
    Revisions:
        20251029@Jay.Do: Get payroll item setting [Redmine: #241812]
    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

	SELECT 
		PayrollItemSettingId,
		[Type]
	FROM PayrollItemSetting
	WHERE @CompanyId = CompanyId 
		AND IsActive = 1
		AND IsDeleted = 0
		AND Category = @PayrollSettingCategory
END