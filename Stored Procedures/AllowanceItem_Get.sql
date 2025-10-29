/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[AllowanceItem_Get]
(
    @PayrollItemSettingId INT = NULL,
    @CompanyId SMALLINT = NULL
)
AS
/*
    Created: Henry
    Task: Get AllowanceItemSetting records
    DB: bodb_HRM

    Revisions:
        - 20251017@Henry: create SP to get allowance item settings [Redmine: #241812]
    
    Param's Explanation:
        @AllowanceItemSettingId - Allowance Item Setting ID (optional filter)
        @PayrollItemSettingId - Payroll Item Setting ID (optional filter)
        @CompanyId - Company ID (optional filter)
*/
BEGIN
    SET NOCOUNT ON;

    SELECT 
        pis.[PayrollItemSettingId],
        pis.[Type],
        ais.[AllowanceItemSettingId],
        ais.[ItemName],
        ais.[Amount],
        ais.[IsPercent]
    FROM [dbo].[AllowanceItemSetting] ais WITH (NOLOCK)
    INNER JOIN [dbo].[PayrollItemSetting] pis WITH (NOLOCK) 
        ON ais.[PayrollItemSettingId] = pis.[PayrollItemSettingId]
        AND (@CompanyId IS NULL OR pis.[CompanyId] = @CompanyId)
    WHERE (@PayrollItemSettingId IS NULL OR ais.[PayrollItemSettingId] = @PayrollItemSettingId)
    ORDER BY pis.[Type] ASC, ais.[ItemName] ASC;
END
