/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[PayrollManagement_GetByMonth]
(
    @Month DATE = NULL,
    @CompanyId INT,
	@IsLocal BIT = 0
)
AS
/*
    Created: Mira@20250731
    Task: Payroll Management
    DB: bodb_HRM

    Revisions:
        20250731@Mira: get payroll by month
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT 
		p.EmpId,
		e.Code,
		e.FullName,
		e.NickName,
		e.JoinedDate,
		e.ConfirmedDate,
		s.BasicSalary 'BasicSalaryEncrypt',
		s.StandardWorkingDay,
		s.UnpaidLeave,
		s.PaidDay,
		s.GrossSalary 'GrossSalaryEncrypt',
		p.EmploymentStatus
	FROM dbo.MonthlyPayroll p WITH(NOLOCK)
	INNER JOIN dbo.MonthlySalary s WITH(NOLOCK) ON s.PayrollId = p.PayrollId
	INNER JOIN dbo.Employee e WITH (NOLOCK) ON p.EmpId = e.EmpId
	INNER JOIN dbo.EmployeeSummary es WITH (NOLOCK) ON es.EmpId = e.EmpId
	INNER JOIN dbo.CompanyEmployee empCom WITH (NOLOCK) ON p.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
	WHERE (@Month IS NULL OR p.[Month] = @Month) 
		AND es.IsLocal = @IsLocal
END;