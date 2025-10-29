/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE PayrollItemSettings_Get (
	@PayrollItemSettingId INT = NULL,
	@Category NVARCHAR(255) = NULL,
	@CompanyId INT = NULL
)
AS
/*
Created: 20251021@Jay.Do
Task: get payroll item settings
DB: HRM
Original: 

Revisions:  
		20251029@Jay.Do: payroll item settings [Redmine: #241812]
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
		ais.ItemName,
		ais.Amount,
		ais.IsPercent,
		pis.IsActive,
		pis.IsDeleted
	FROM [dbo].[PayrollItemSetting] pis (NOLOCK)
	INNER JOIN [dbo].[AllowanceItemSetting] ais (NOLOCK) ON pis.PayrollItemSettingId = ais.PayrollItemSettingId AND ais.IsActive = 1 AND ais.IsDeleted = 0
	WHERE (@CompanyId IS NULL OR @CompanyId = pis.CompanyId)
		AND (@PayrollItemSettingId IS NULL OR @PayrollItemSettingId = pis.PayrollItemSettingId)
		AND (@Category IS NULL OR @Category = pis.Category)
		AND pis.IsActive = 1
		AND pis.IsDeleted = 0
END