/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[EmployeePayrollAllowance_GetByEmpId]
(
    @EmpId INT
)
AS
/*
    Created: Henry
    Task: Get EmployeePayrollAllowance by EmpId
    DB: bodb_HRM

    Revisions:
        - 20251017@Henry: create SP to get employee payroll allowance [Redmine: #241812]
    
    Param's Explanation:
        @EmpId - Employee ID
*/
BEGIN
    SET NOCOUNT ON;

    SELECT 
        ais.[AllowanceItemSettingId],
        ais.[ItemName],
        ais.[Amount],
        ais.[IsPercent],
        pis.[Type] AS AllowanceName,
        pis.[Taxable],
        pis.[IsMultiSelect]
    FROM [dbo].[EmployeePayrollAllowance] epa WITH (NOLOCK)
    INNER JOIN [dbo].[AllowanceItemSetting] ais WITH (NOLOCK) 
        ON epa.[AllowanceItemSettingId] = ais.[AllowanceItemSettingId]
    INNER JOIN [dbo].[PayrollItemSetting] pis WITH (NOLOCK) 
        ON ais.[PayrollItemSettingId] = pis.[PayrollItemSettingId]
    WHERE epa.[EmpId] = @EmpId
    ORDER BY pis.[Type] ASC, ais.[ItemName] ASC;

END
