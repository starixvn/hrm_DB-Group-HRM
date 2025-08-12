/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[Payroll_Calculate]
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
		GrossSalary VARCHAR(100)
	);

	INSERT INTO @TempPayroll
	SELECT DISTINCT
		EmpId,
		WorkingDays,
		PaidDays,
		UnpaidLeave,
		BasicSalary,
		GrossSalary,
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
		JoinDate DATETIME,
		ConfirmedDate DATETIME,
		EmploymentStatus INT
	) AS j

	MERGE INTO dbo.MonthlyPayroll AS target
	USING (
		SELECT *
        FROM @TempPayroll
	) AS source
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
		source.GrossSalary
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
			target.GrossSalary = source.GrossSalary
	WHEN NOT MATCHED BY TARGET THEN
		INSERT(PayrollId, StandardWorkingDay, PaidDay, UnpaidLeave, BasicSalary, GrossSalary)
		VALUES(source.PayrollId, source.WorkingDays, source.PaidDays, source.UnpaidLeave, source.BasicSalary, source.GrossSalary);

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
	INSERT INTO dbo.ActivityLog
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