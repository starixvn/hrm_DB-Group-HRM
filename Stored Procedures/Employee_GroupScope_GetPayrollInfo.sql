/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GroupScope_GetPayrollInfo]
(
    @EmpIds NVARCHAR(MAX)
)
AS
/*
	Created: 20251022@Mira
	Task: get salary in group space 
	DB: bodb_HRM

	Revisions:
		20251022@Mira: get salary [Redmine: #241812]
*/
BEGIN
	SET NOCOUNT ON;
	CREATE TABLE #tmpEmp(EmpId INT PRIMARY KEY)

	INSERT INTO #tmpEmp(EmpId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@EmpIds, ',');

	-- get salary structure
	SELECT 
		e.EmpId,
		salary.BasicSalary AS EncryptBasicSalary,
		salary.ExpatSalary AS EncryptExpatSalary,
		salary.JobLevelAddOn AS EncryptJobLevelAddOn,
		payroll.SpecialSubsidy AS EncryptSpecialSubsidy
	FROM #tmpEmp AS e
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
	INNER JOIN dbo.EmployeePayroll AS payroll WITH (NOLOCK) ON payroll.EmpId = e.EmpId
	INNER JOIN dbo.SalaryStructureDetail AS salary WITH (NOLOCK) ON salary.SalaryStructureId = payroll.SalaryStructureId AND salary.JoblevelId = ce.JobLevelId
	
	-- get allowances
	SELECT
		e.EmpId,
		p.Type,
		p.Taxable,
		item.ItemName,
		item.Amount AS EncryptAmount
	FROM #tmpEmp AS e
	INNER JOIN dbo.EmployeePayrollAllowance AS epa WITH (NOLOCK) ON epa.EmpId = e.EmpId
	INNER JOIN dbo.AllowanceItemSetting AS item WITH (NOLOCK) ON item.AllowanceItemSettingId = epa.AllowanceItemSettingId
	INNER JOIN dbo.PayrollItemSetting AS p WITH (NOLOCK) ON p.PayrollItemSettingId = item.PayrollItemSettingId  AND p.Category = 2 -- Allowance
	WHERE p.IsActive = 1 AND p.IsDeleted = 0

	DROP TABLE #tmpEmp
END