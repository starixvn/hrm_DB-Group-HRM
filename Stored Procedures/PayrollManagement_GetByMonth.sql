/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[PayrollManagement_GetByMonth]
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
		20250812@Mira: tranfer employee [Redmine: #235678]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT 
		p.EmpId,
		ce.Code,
		e.FullName,
		ce.NickName,
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
	    INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON p.EmpId = ce.EmpId
		INNER JOIN dbo.Employee e WITH (NOLOCK) ON e.UserId = ce.UserId
	    INNER JOIN dbo.EmployeeSummary es WITH (NOLOCK) ON es.EmpId = ce.EmpId
	    INNER JOIN dbo.CompanyEmployee empCom WITH (NOLOCK) ON p.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
	WHERE (@Month IS NULL OR p.[Month] = @Month) 
		AND es.IsLocal = @IsLocal
END;