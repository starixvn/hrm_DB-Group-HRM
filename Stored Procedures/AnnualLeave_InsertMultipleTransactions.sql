/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_InsertMultipleTransactions]
(
    @CompanyId SMALLINT
    ,@EmployeeIds VARCHAR(MAX)
	,@Description NVARCHAR(4000) = ''
	,@FromDate DATE
	,@DeductDays NUMERIC(18, 1)
	,@CreditDays NUMERIC(18, 1)
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013.10.29
    Task: record multiple annual leave transaction and calculate annual leave balance for employee
    DB: bodb_HRM

    Revisions:
        20250429@Tim: add param @CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @maximumBalanceForLocal SMALLINT
		,@maximumBalanceForExpat SMALLINT

	SELECT @maximumBalanceForLocal = Value
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'AnnualLeaveBalanceForLocal'

	SELECT @maximumBalanceForExpat = Value
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'AnnualLeaveBalanceForExpat'

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


	CREATE TABLE #tmpLeaveRange (
		EmpId INT PRIMARY KEY,
		RangeStartDate DATETIME,
		RangeEndDate DATETIME
	)

	INSERT INTO #tmpLeaveRange (EmpId, RangeStartDate, RangeEndDate)
	SELECT 
		EmpId,
		ISNULL(FromDate, @FromDate) AS RangeStartDate,
		ToDate AS RangeEndDate
	FROM (
		SELECT 
			emp.EmpId,
			lt.FromDate,
			lt.ToDate,
			ROW_NUMBER() OVER (PARTITION BY emp.EmpId ORDER BY lt.FromDate ASC) AS rn
		FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmployeeId
		LEFT JOIN dbo.LeaveTrans AS lt WITH (NOLOCK) ON emp.EmpId = lt.EmpId
			AND lt.FromDate <= @FromDate
			AND lt.ToDate > @FromDate
			AND lt.CreditDays > 0
			AND lt.RequestId IS NULL
			AND ISNULL(lt.Deleted, 0) = 0
	) AS t
	WHERE rn = 1


	UPDATE #tmpLeaveRange
	SET RangeEndDate = DATEADD(DAY, -1, DATEADD(YEAR, 1, RangeStartDate))
	WHERE RangeEndDate IS NULL;


	INSERT INTO dbo.LeaveTrans (
		EmpId
		,[Description]
		,FromDate
		,ToDate
		,DeductDays
		,CreditDays
		,CreatedDate
		,CreatedBy
		)
	SELECT emp.EmpId
		,@Description
		,@FromDate
		,lr.RangeEndDate
		,@DeductDays
		,@CreditDays
		,GETDATE()
		,@ActorId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmployeeId
		INNER JOIN #tmpLeaveRange AS lr ON emp.EmpId = lr.EmpId
	WHERE ISNULL(emp.isDeleted, 0) = 0


	UPDATE dbo.EmployeeSummary WITH (ROWLOCK)
	SET AnnualLeaveBalance = ISNULL(AnnualLeaveBalance, 0) + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EXISTS (
			SELECT 1
			FROM #tblEmployeeIds
			WHERE EmpId = EmployeeId
			)
	
	DROP TABLE #tblEmployeeIds
	DROP TABLE #tmpLeaveRange
END