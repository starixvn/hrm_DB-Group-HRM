/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SickLeave_ResetMultipleTransactions] @ActorId INT
	,@Year INT
	,@Description NVARCHAR(4000) = NULL
	,@ResetDays NUMERIC(18, 1) = 0
	,@CompanyId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tim.Trinh@2021-08-23
Task: reset sick leave balance
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tblEmployeeId (EmpId INT)

	INSERT INTO #tblEmployeeId (EmpId)
	SELECT EmpId
	FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 1, 0, @CompanyId)

	DECLARE @fromdate DATETIME
		,@todate DATETIME
		,@lastDateOfYear DATE

	SET @fromdate = CAST(@Year AS VARCHAR(10)) + '/01/01'
	SET @todate = DATEADD(YEAR, 1, @fromdate)
	SET @lastDateOfYear = DATEADD(DAY, - 1, @todate)

	SELECT emp.EmpId
		,ISNULL(credit.CreditDays, 0) AS CreditDays
		,SUM(ISNULL(deduct.DeductDays, 0)) AS DeductDays
	INTO #tblCurrenBalace
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeId AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
		LEFT JOIN dbo.SickLeaveTrans AS deduct WITH (NOLOCK) ON emp.EmpId = deduct.EmpId
		AND YEAR(deduct.FromDate) = @Year
		AND deduct.IsDeleted = 0
		LEFT JOIN (
		SELECT EmpId
			,SUM(CreditDays) CreditDays
		FROM dbo.SickLeaveTrans WITH (NOLOCK)
		WHERE FromDate >= @fromdate
			AND FromDate < @todate
			AND IsDeleted = 0
			AND CreditDays > 0
		GROUP BY EmpId
		) credit ON emp.EmpId = credit.EmpId
	WHERE ISNULL(emp.isDeleted, 0) = 0
		OR YEAR(emp.ResignedDate) >= year(@todate)
	GROUP BY emp.EmpId
		,ISNULL(credit.CreditDays, 0)

	SELECT emp.EmpId
		,ISNULL(cb.CreditDays, 0) - ISNULL(cb.DeductDays, 0) AS Balance
	INTO #tblRemainingBalance
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId AND ce.CompanyId = @CompanyId
		LEFT JOIN #tblCurrenBalace AS cb WITH (NOLOCK) ON emp.EmpId = cb.EmpId
	WHERE ISNULL(emp.[Enabled], 0) = 1

	INSERT INTO dbo.SickLeaveTrans (
		EmpId
		,[Description]
		,FromDate
		,DeductDays
		,CreditDays
		,CreatedBy
		,CreatedDate
		)
	SELECT EmpID
		,@Description
		,@lastDateOfYear
		,Balance - @ResetDays
		,0
		,@ActorId
		,GETDATE()
	FROM #tblRemainingBalance WITH (NOLOCK)
	WHERE Balance > @ResetDays

	UPDATE es
	SET es.SickLeaveBalance = ISNULL(es.SickLeaveBalance, 0) - (tbl.Balance - @ResetDays)
	FROM dbo.EmployeeSummary AS es WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblRemainingBalance AS tbl WITH (NOLOCK) ON es.EmpId = tbl.EmpId
	WHERE tbl.Balance > @ResetDays

	DROP TABLE #tblEmployeeId

	DROP TABLE #tblCurrenBalace

	DROP TABLE #tblRemainingBalance
END





