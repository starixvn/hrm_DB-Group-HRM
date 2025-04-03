/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_InsertMultipleTransactions] @EmployeeIds VARCHAR(MAX)
	,@Description NVARCHAR(4000) = ''
	,@FromDate DATE
	,@DeductDays NUMERIC(18, 1)
	,@CreditDays NUMERIC(18, 1)
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013.10.29
Task: record multiple annual leave transaction and calculate annual leave balance for employee
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @maximumBalanceForLocal SMALLINT
		,@maximumBalanceForExpat SMALLINT

	SELECT @maximumBalanceForLocal = Value
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE RefName = 'AnnualLeaveBalanceForLocal'

	SELECT @maximumBalanceForExpat = Value
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE RefName = 'AnnualLeaveBalanceForExpat'

	SET @maximumBalanceForLocal = ISNULL(@maximumBalanceForLocal, 0)
	SET @maximumBalanceForExpat = ISNULL(@maximumBalanceForExpat, 0)

	CREATE TABLE #tblEmployeeIds (EmployeeId INT)

	INSERT INTO #tblEmployeeIds (EmployeeId)
	SELECT value
	FROM STRING_SPLIT(@EmployeeIds, ',')

	IF @maximumBalanceForLocal > 0
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary AS empsum WITH (NOLOCK)
				INNER JOIN #tblEmployeeIds AS empid ON empsum.EmpId = empid.EmployeeId
			WHERE empsum.IsLocal = 1
				AND @CreditDays > @maximumBalanceForLocal
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Employees - Local: ' + CAST(@maximumBalanceForLocal AS VARCHAR(2))

		RETURN
	END
	
	IF @maximumBalanceForExpat > 0
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary AS empsum WITH (NOLOCK)
				INNER JOIN #tblEmployeeIds AS empid ON empsum.EmpId = empid.EmployeeId
			WHERE empsum.IsLocal = 0
				AND @CreditDays > @maximumBalanceForExpat
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Employees - Expat: no rules (only ' + + CAST(@maximumBalanceForExpat AS VARCHAR(2)) + ' ALs a day).'

		RETURN
	END
	
	IF EXISTS (
			SELECT 1
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmployeeId
			WHERE ISNULL(emp.ConfirmedDate, GETDATE() - 365) > @FromDate
				AND @CreditDays > 0
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Probation: no annual days.'

		RETURN
	END

	INSERT INTO dbo.LeaveTrans (
		EmpId
		,[Description]
		,FromDate
		,DeductDays
		,CreditDays
		,CreatedDate
		,CreatedBy
		)
	SELECT emp.EmpId
		,@Description
		,@FromDate
		,@DeductDays
		,@CreditDays
		,GETDATE()
		,@ActorId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmployeeId
	WHERE ISNULL(emp.isDeleted, 0) = 0

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK, UPDLOCK)
	SET AnnualLeaveBalance = ISNULL(AnnualLeaveBalance, 0) + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EXISTS (
			SELECT 1
			FROM #tblEmployeeIds
			WHERE EmpId = EmployeeId
			)
	
	DROP TABLE #tblEmployeeIds
END