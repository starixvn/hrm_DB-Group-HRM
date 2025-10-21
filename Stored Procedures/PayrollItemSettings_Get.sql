/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE PayrollItemSettings_Get (
	@PayrollItemSettingId INT = NULL,
	@CompanyId INT = NULL
)
AS
/*
Created: 20251021@Jay.Do
Task: get payroll item settings
DB: HRM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT 
		pis.PayrollItemSettingId,
		[Type],
		Taxable,
		Category,
		IsMultiSelect,
		CompanyId,
		ais.AllowanceItemSettingId,
		ItemName,
		ais.Amount,
		ais.IsPercent
	FROM PayrollItemSetting pis (NOLOCK)
	LEFT JOIN AllowanceItemSetting ais (NOLOCK) ON pis.PayrollItemSettingId = ais.PayrollItemSettingId
	WHERE (@CompanyId IS NULL OR @CompanyId = pis.CompanyId)
		AND (@PayrollItemSettingId IS NULL OR @PayrollItemSettingId = pis.PayrollItemSettingId)
END