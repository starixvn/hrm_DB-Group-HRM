/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[PayrollManagement_GetByMonth]
(
    @Month DATE = NULL,
    @CompanyId INT,
	@IsLocal BIT = 0,
	@UnitIds VARCHAR(MAX) = NULL,
	@DepartmentIds VARCHAR(MAX) = NULL,
	@TeamIds VARCHAR(MAX) = NULL
)
AS
/*
    Created: Mira@20250731
    Task: Payroll Management
    DB: bodb_HRM

    Revisions:
        20250731@Mira: get payroll by month
		20250812@Mira: tranfer employee [Redmine: #235678]
		20251201@Jay: enhance payroll [Redmine: #245211]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @UnitIdsList TABLE (UnitId INT)

    IF ISNULL(@UnitIds, '') = ''
    BEGIN
        INSERT INTO @UnitIdsList(UnitId)
        SELECT UnitId
        FROM dbo.Unit WITH (NOLOCK)
    END
    ELSE
    BEGIN
        INSERT INTO @UnitIdsList(UnitId)
	    SELECT DISTINCT u.value
	    FROM STRING_SPLIT(@UnitIds, ',') AS u
    END

	DECLARE @DepartmentIdsList TABLE (DepartmentId INT)

    IF ISNULL(@DepartmentIds, '') = ''
    BEGIN
        INSERT INTO @DepartmentIdsList(DepartmentId)
        SELECT DepartmentId
        FROM dbo.Department WITH (NOLOCK)
    END
    ELSE
    BEGIN
        INSERT INTO @DepartmentIdsList(DepartmentId)
	    SELECT DISTINCT d.value
	    FROM STRING_SPLIT(@DepartmentIds, ',') AS d
    END

	DECLARE @TeamIdsList TABLE (TeamId INT)

    IF ISNULL(@TeamIds, '') = ''
    BEGIN
        INSERT INTO @TeamIdsList(TeamId)
        SELECT GroupId
        FROM dbo.[Group] WITH (NOLOCK)
    END
    ELSE
    BEGIN
        INSERT INTO @TeamIdsList(TeamId)
	    SELECT DISTINCT t.value
	    FROM STRING_SPLIT(@TeamIds, ',') AS t
    END

	SELECT 
		p.EmpId,
		ce.Code,
		u.[Code] BUCode,
		d.[Code] DepartmentCode,
		g.[Code] TeamCode,
		e.FullName,
		ce.NickName,
		e.JoinedDate,
		e.ConfirmedDate,
		s.BasicSalary 'BasicSalaryEncrypt',
		s.StandardWorkingDay,
		s.UnpaidLeave,
		s.PaidDay,
		s.GrossSalary 'GrossSalaryEncrypt',
		s.JobLevelAddOn JobLevelAddOnEncrypt,
		s.TotalIncome TotalIncomeEncrypt,
		s.SpecialSubsidy SpecialSubsidyEncrypt,
		s.TransportationAllowance TransportationAllowanceEncrypt,
		s.ManagementAllowance ManagementAllowanceEncrypt,
		s.MobilephoneAllowance MobilephoneAllowanceEncrypt,
		p.EmploymentStatus
	FROM dbo.MonthlyPayroll p WITH(NOLOCK)
	    INNER JOIN dbo.MonthlySalary s WITH(NOLOCK) ON s.PayrollId = p.PayrollId
	    INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON p.EmpId = ce.EmpId
		INNER JOIN dbo.[Group] g (NOLOCK) ON g.GroupId = ce.GroupId
		INNER JOIN dbo.Department d (NOLOCK) ON d.DepartmentId = g.DepartmentId
		INNER JOIN dbo.Unit u (NOLOCK) ON u.UnitId = d.UnitId
		INNER JOIN dbo.Employee e WITH (NOLOCK) ON e.UserId = ce.UserId
	    INNER JOIN dbo.EmployeeSummary es WITH (NOLOCK) ON es.EmpId = ce.EmpId
	    INNER JOIN dbo.CompanyEmployee empCom WITH (NOLOCK) ON p.EmpId = empCom.EmpId 
			AND empCom.CompanyId = @CompanyId
	WHERE (@Month IS NULL OR p.[Month] = @Month) 
		AND es.IsLocal = @IsLocal
		AND (ISNULL( @TeamIds, '') = ''  OR g.GroupId IN (SELECT TeamId FROM @TeamIdsList))
		AND (ISNULL( @UnitIds, '') = ''  OR u.UnitId IN (SELECT UnitId FROM @UnitIdsList))
		AND (ISNULL( @DepartmentIds, '') = ''  OR d.DepartmentId IN (SELECT DepartmentId FROM @DepartmentIdsList))
END;