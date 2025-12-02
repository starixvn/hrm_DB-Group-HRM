/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Payroll_Calculate]
(
	@CompanyId INT,
	@Date DATETIME,
	@ModifiedBy INT,
	@PayrollListJson NVARCHAR(MAX)
)
AS
/*
    Created: Jay.Do@20250730
    Task: insert or update payroll per month
    DB: bodb_HRM

    Revisions:
        20250730@Jay.Do: init function [Redmine: #217977]
		20251128@Mira: calculate allowance [Redmine: #245214]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @CurrentDateTime DATETIME = GETDATE();

	DECLARE @TempPayroll TABLE (
		EmpId INT,
		WorkingDays INT,
		PaidDays DECIMAL(18, 2),
		UnpaidLeave DECIMAL(18, 2),
		BasicSalary VARCHAR(100),
		GrossSalary VARCHAR(100),
		JobLevelAddOn VARCHAR(100),
		SpecialSubsidy VARCHAR(100),
		ManagementAllowance VARCHAR(100),
		TransportationAllowance VARCHAR(100),
		MobilephoneAllowance VARCHAR(100),
		TotalIncome VARCHAR(100),
		JoinDate DATETIME,
		ConfirmedDate DATETIME,
		EmploymentStatus INT
	)

	DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Date), MONTH(@Date), 1);
	DECLARE @MonthEnd DATE = EOMONTH(@Date);
	DECLARE @PayrollObjectTypeId INT = 7;
	DECLARE @PayrollLogActionId INT = 17;
	DECLARE @LogObjectId VARCHAR(50) = CONCAT(@CompanyId, FORMAT(@Date, 'MM'), YEAR(@Date));

	-- Query old data before deletion for logging
	DECLARE @OldData NVARCHAR(MAX);
	SELECT @OldData = (
		SELECT 
			mp.PayrollId,
			mp.EmpId,
			mp.[Month],
			mp.EmploymentStatus,
			ms.StandardWorkingDay,
			ms.PaidDay,
			ms.UnpaidLeave,
			ms.BasicSalary,
			ms.GrossSalary,
			ms.JobLevelAddOn,
			ms.SpecialSubsidy,
			ms.ManagementAllowance,
			ms.TransportationAllowance,
			ms.MobilephoneAllowance,
			ms.TotalIncome
		FROM dbo.MonthlyPayroll mp
		INNER JOIN dbo.CompanyEmployee ce ON mp.EmpId = ce.EmpId
		LEFT JOIN dbo.MonthlySalary ms ON ms.PayrollId = mp.PayrollId
		WHERE ce.CompanyId = @CompanyId
			AND mp.[Month] >= @MonthStart
			AND mp.[Month] <= @MonthEnd
		FOR JSON PATH
	);

	INSERT INTO @TempPayroll(
		EmpId,
		WorkingDays,
		PaidDays,
		UnpaidLeave,
		BasicSalary,
		GrossSalary,
		JobLevelAddOn,
		SpecialSubsidy,
		ManagementAllowance,
		TransportationAllowance,
		MobilephoneAllowance,
		TotalIncome,
		JoinDate,
		ConfirmedDate,
		EmploymentStatus
	)
	SELECT DISTINCT
		EmpId,
		WorkingDays,
		PaidDays,
		UnpaidLeave,
		BasicSalary,
		GrossSalary,
		JobLevelAddOn,
		SpecialSubsidy,
		ManagementAllowance,
		TransportationAllowance,
		MobilephoneAllowance,
		TotalIncome,
		JoinDate,
		ConfirmedDate,
		EmploymentStatus
	FROM OPENJSON(@PayrollListJson)
	WITH (
		EmpId INT,
		WorkingDays INT,
		PaidDays DECIMAL(18, 2),
		UnpaidLeave DECIMAL(18, 2),
		BasicSalary VARCHAR(100),
		GrossSalary VARCHAR(100),
		JobLevelAddOn VARCHAR(100),
		SpecialSubsidy VARCHAR(100),
		ManagementAllowance VARCHAR(100),
		TransportationAllowance VARCHAR(100),
		MobilephoneAllowance VARCHAR(100),
		TotalIncome VARCHAR(100),
		JoinDate DATETIME,
		ConfirmedDate DATETIME,
		EmploymentStatus INT
	) AS j

	-- Delete all existing data for the month (delete MonthlySalary first due to foreign key)
	DELETE ms
	FROM dbo.MonthlySalary ms
	INNER JOIN dbo.MonthlyPayroll mp ON ms.PayrollId = mp.PayrollId
	INNER JOIN dbo.CompanyEmployee ce ON mp.EmpId = ce.EmpId
	WHERE ce.CompanyId = @CompanyId
		AND mp.[Month] >= @MonthStart
		AND mp.[Month] <= @MonthEnd;

	DELETE mp
	FROM dbo.MonthlyPayroll mp
	INNER JOIN dbo.CompanyEmployee ce ON mp.EmpId = ce.EmpId
	WHERE ce.CompanyId = @CompanyId
		AND mp.[Month] >= @MonthStart
		AND mp.[Month] <= @MonthEnd;

	-- Insert new data
	INSERT INTO dbo.MonthlyPayroll (EmpId, [Month], EmploymentStatus, CompanyDate, ConfirmedDate, ModifiedBy, ModifiedDate)
	SELECT 
		tp.EmpId,
		@MonthStart,
		tp.EmploymentStatus,
		CAST(tp.JoinDate AS DATE),
		CAST(tp.ConfirmedDate AS DATE),
		@ModifiedBy,
		@CurrentDateTime
	FROM @TempPayroll tp;

	-- Insert MonthlySalary with PayrollId
	INSERT INTO dbo.MonthlySalary (PayrollId, StandardWorkingDay, PaidDay, UnpaidLeave, BasicSalary, GrossSalary, JobLevelAddOn, SpecialSubsidy, ManagementAllowance, TransportationAllowance, MobilephoneAllowance, TotalIncome)
	SELECT 
		mp.PayrollId,
		tp.WorkingDays,
		tp.PaidDays,
		CAST(tp.UnpaidLeave AS REAL),
		tp.BasicSalary,
		tp.GrossSalary,
		tp.JobLevelAddOn,
		tp.SpecialSubsidy,
		tp.ManagementAllowance,
		tp.TransportationAllowance,
		tp.MobilephoneAllowance,
		tp.TotalIncome
	FROM @TempPayroll tp
	INNER JOIN dbo.MonthlyPayroll mp ON tp.EmpId = mp.EmpId
		AND mp.[Month] = @MonthStart;

	-- Insert activity log
	INSERT INTO dbo.ActivityLog (
			LogDate,
			UserId,
			ActionId,
			ObjectTypeId,
			ObjectId,
			OldData,
			Data,
			Old_Id)
		VALUES( 
			@CurrentDateTime,
			@ModifiedBy,
			@PayrollLogActionId,
			@PayrollObjectTypeId,
			@LogObjectId,
			@OldData,
			@PayrollListJson,
			NULL)
END