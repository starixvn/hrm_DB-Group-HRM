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

	DECLARE @MergedPayroll TABLE (
		PayrollId INT,
		EmpId INT,
		WorkingDays INT,
		PaidDays DECIMAL(18, 2),
		UnpaidLeave REAL,
		BasicSalary VARCHAR(100),
		GrossSalary VARCHAR(100),
		JobLevelAddOn VARCHAR(100),
		SpecialSubsidy VARCHAR(100),
		ManagementAllowance VARCHAR(100),
		TransportationAllowance VARCHAR(100),
		MobilephoneAllowance VARCHAR(100),
		TotalIncome VARCHAR(100)
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

	MERGE INTO dbo.MonthlyPayroll AS target
	USING @TempPayroll AS source
	ON target.EmpId = source.EmpId
		AND MONTH(target.[Month]) = MONTH(@Date)
		AND YEAR(target.[Month]) = YEAR(@Date)
	WHEN MATCHED THEN UPDATE SET
		target.EmploymentStatus = source.EmploymentStatus,
		target.ModifiedBy = @ModifiedBy,
		target.ModifiedDate = @CurrentDateTime
	WHEN NOT MATCHED BY TARGET THEN
		INSERT(EmpId, [Month], EmploymentStatus, ModifiedBy, ModifiedDate)
		VALUES(source.EmpId, @Date, source.EmploymentStatus, @ModifiedBy, @CurrentDateTime)
	OUTPUT 
		inserted.PayrollId,
		source.EmpId,
		source.WorkingDays,
		source.PaidDays,
		source.UnpaidLeave,
		source.BasicSalary,
		source.GrossSalary,
		source.JobLevelAddOn,
		source.SpecialSubsidy,
		source.ManagementAllowance,
		source.TransportationAllowance,
		source.MobilephoneAllowance,
		source.TotalIncome
	INTO @MergedPayroll;

	MERGE INTO dbo.MonthlySalary AS target
	USING @MergedPayroll AS source
	ON target.PayrollId = source.PayrollId
	WHEN MATCHED THEN
		UPDATE SET
			target.StandardWorkingDay = source.WorkingDays,
			target.PaidDay = source.PaidDays,
			target.UnpaidLeave = source.UnpaidLeave,
			target.BasicSalary = source.BasicSalary,
			target.GrossSalary = source.GrossSalary,
			target.JobLevelAddOn = source.JobLevelAddOn,
			target.SpecialSubsidy = source.SpecialSubsidy,
			target.ManagementAllowance = source.ManagementAllowance,
			target.TransportationAllowance = source.TransportationAllowance,
			target.MobilephoneAllowance = source.MobilephoneAllowance,
			target.TotalIncome = source.TotalIncome
	WHEN NOT MATCHED BY TARGET THEN
		INSERT(PayrollId, StandardWorkingDay, PaidDay, UnpaidLeave, BasicSalary, GrossSalary, JobLevelAddOn, SpecialSubsidy, ManagementAllowance, TransportationAllowance, MobilephoneAllowance, TotalIncome)
		VALUES(source.PayrollId, source.WorkingDays, source.PaidDays, source.UnpaidLeave, source.BasicSalary, source.GrossSalary, source.JobLevelAddOn, source.SpecialSubsidy, source.ManagementAllowance, source.TransportationAllowance, source.MobilephoneAllowance, source.TotalIncome);

	DECLARE @PayrollObjectTypeId INT = 7;
	DECLARE @LogObjectId VARCHAR(MAX) = 
		CAST(@CompanyId AS VARCHAR) + 
		CAST(MONTH(@Date) AS VARCHAR) + 
		CAST(YEAR(@Date) AS VARCHAR);

	DECLARE @OldData NVARCHAR(MAX) = 
		(SELECT TOP 1 [Data] 
			FROM ActivityLog 
			WHERE ObjectTypeId = @PayrollObjectTypeId 
				AND ObjectId = @LogObjectId); 
	DECLARE @PayrollLogActionId INT = 17;
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