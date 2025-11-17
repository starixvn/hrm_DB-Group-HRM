/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GroupScope_GetPayrollInfo]
(
    @EmpIds NVARCHAR(MAX),
	@IsLocal BIT = 1
)
AS
/*
	Created: 20251022@Mira
	Task: get salary in group space 
	DB: bodb_HRM

	Revisions:
		20251022@Mira: get salary [Redmine: #241812]
        20251106@Tim: fix get job level NEX
*/
BEGIN
	SET NOCOUNT ON;
    DECLARE @NexcelId SMALLINT = 1, @LumiId SMALLINT = 2,  @NexVisionId SMALLINT = 34

	CREATE TABLE #tmpEmp(EmpId INT PRIMARY KEY, JobLevelId INT)

	INSERT INTO #tmpEmp(EmpId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@EmpIds, ',');    

    UPDATE e
    SET e.JobLevelId = ce.JobLevelId
    FROM #tmpEmp AS e
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE ce.CompanyId NOT IN (@NexcelId, @LumiId, @NexVisionId)

    UPDATE e
    SET e.JobLevelId = jl.JobLevelId
    FROM #tmpEmp AS e
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
        INNER JOIN HRM.dbo.EmployeeJobGrade AS ejg WITH (NOLOCK) ON ejg.EmpId = e.EmpId AND ejg.IsCurrentUsed = 1 AND ISNULL(ejg.IsDeleted, 0) = 0
		INNER JOIN dbo.JobLevel AS jl WITH (NOLOCK) ON ejg.JobGradeId = jl.JobLevelId
    WHERE ce.CompanyId IN (@NexcelId, @LumiId, @NexVisionId)

	-- get salary structure
	SELECT 
		e.EmpId,
		IIF(@IsLocal = 1, salary.BasicSalary, salary.ExpatSalary) 'EncryptBasicSalary',
		IIF(@IsLocal = 1, salary.JobLevelAddOn, salary.ExpatJobLevelAddOn) 'EncryptJobLevelAddOn',
		IIF(@IsLocal = 1, currency.CurrencyCode, 'USD') 'CurrencyCode',
		payroll.SpecialSubsidy 'EncryptSpecialSubsidy',
		ISNULL(subsidyCurrency.CurrencyCode, currency.CurrencyCode) 'SpecialSubsidyCurrencyCode'
	FROM #tmpEmp AS e
	    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
	    INNER JOIN dbo.EmployeePayroll AS payroll WITH (NOLOCK) ON payroll.EmpId = e.EmpId
	    LEFT JOIN dbo.SalaryStructureDetail AS salary WITH (NOLOCK) ON salary.SalaryStructureId = payroll.SalaryStructureId AND salary.JoblevelId = e.JobLevelId
	    LEFT JOIN dbo.Currency AS subsidyCurrency WITH (NOLOCK) ON subsidyCurrency.Id = payroll.SpecialSubsidyCurrencyId
	    OUTER APPLY (
            SELECT TOP 1 c.CurrencyCode
            FROM dbo.Currency AS c WITH (NOLOCK)
            WHERE c.Id = (
                SELECT TOP 1 CAST(tmpc.value AS INT)
                FROM dbo.SystemConfigs AS sc WITH (NOLOCK)
                CROSS APPLY STRING_SPLIT(sc.[Value], ',') AS tmpc
                WHERE sc.[Key] = 'Currency' AND sc.CompanyId = ce.CompanyId
            )
        ) AS currency;

	-- get allowances
	SELECT
		e.EmpId,
		p.Type,
		p.Taxable,
		item.ItemName,
		item.Amount AS EncryptAmount,
		ISNULL(currency.CurrencyCode, 'VND') 'CurrencyCode' -- todo
	FROM #tmpEmp AS e
	    INNER JOIN dbo.EmployeePayrollAllowance AS epa WITH (NOLOCK) ON epa.EmpId = e.EmpId
	    INNER JOIN dbo.AllowanceItemSetting AS item WITH (NOLOCK) ON item.AllowanceItemSettingId = epa.AllowanceItemSettingId
	    INNER JOIN dbo.PayrollItemSetting AS p WITH (NOLOCK) ON p.PayrollItemSettingId = item.PayrollItemSettingId  AND p.Category = 2 -- Allowance
		LEFT JOIN dbo.Currency AS currency WITH (NOLOCK) ON currency.Id = item.CurrencyId
	    WHERE p.IsActive = 1 AND p.IsDeleted = 0

	DROP TABLE #tmpEmp
END