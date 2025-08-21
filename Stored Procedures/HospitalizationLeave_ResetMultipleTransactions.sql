/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[HospitalizationLeave_ResetMultipleTransactions] @ActorId INT
	,@Year INT
	,@Description NVARCHAR(4000) = NULL
	,@ResetDays NUMERIC(18, 1) = 0
	,@CompanyId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tim.Trinh@2021-08-19
Task: reset hospitalization leave balance
DB: HRM_SMS
Original:

Revisions:
	20250821@Jay: restructure for transfer [Redmine: #235678]
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

	SELECT ce.EmpId
		,ISNULL(credit.CreditDays, 0) AS CreditDays
		,SUM(ISNULL(deduct.DeductDays, 0)) AS DeductDays
	INTO #tblCurrenBalace
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.Employee e (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN #tblEmployeeId AS tblemp WITH (NOLOCK) ON ce.EmpId = tblemp.EmpId
		LEFT JOIN dbo.HospitalizationLeaveTrans AS deduct WITH (NOLOCK) ON ce.EmpId = deduct.EmpId
		AND YEAR(deduct.FromDate) = @Year
		AND deduct.IsDeleted = 0
		LEFT JOIN (
		SELECT EmpId
			,SUM(CreditDays) CreditDays
		FROM dbo.HospitalizationLeaveTrans WITH (NOLOCK)
		WHERE FromDate >= @fromdate
			AND FromDate < @todate
			AND IsDeleted = 0
			AND CreditDays > 0
		GROUP BY EmpId
		) credit ON ce.EmpId = credit.EmpId
	WHERE ISNULL(ce.isDeleted, 0) = 0
		OR YEAR(e.ResignedDate) >= year(@todate)
	GROUP BY ce.EmpId
		,ISNULL(credit.CreditDays, 0)

	SELECT ce.EmpId
		,ISNULL(cb.CreditDays, 0) - ISNULL(cb.DeductDays, 0) AS Balance
	INTO #tblRemainingBalance
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.Employee e WITH (NOLOCK) ON e.UserId = ce.UserId
		LEFT JOIN #tblCurrenBalace AS cb WITH (NOLOCK) ON ce.EmpId = cb.EmpId
	WHERE ISNULL(ce.[Enabled], 0) = 1
		AND ce.CompanyId = @CompanyId

	INSERT INTO dbo.HospitalizationLeaveTrans (
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
	SET es.HospitalizationLeaveBalance = ISNULL(es.HospitalizationLeaveBalance, 0) - (tbl.Balance - @ResetDays)
	FROM dbo.EmployeeSummary AS es WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblRemainingBalance AS tbl WITH (NOLOCK) ON es.EmpId = tbl.EmpId
	WHERE tbl.Balance > @ResetDays

	DROP TABLE #tblEmployeeId

	DROP TABLE #tblCurrenBalace

	DROP TABLE #tblRemainingBalance
END

