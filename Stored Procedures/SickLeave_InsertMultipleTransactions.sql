/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


ALTER PROCEDURE [dbo].[SickLeave_InsertMultipleTransactions] @EmployeeIds VARCHAR(MAX)
	,@Description NVARCHAR(4000) = ''
	,@FromDate DATE
	,@DeductDays NUMERIC(18, 1)
	,@CreditDays NUMERIC(18, 1)
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tim.Trinh@2021-08-23
Task: insert multiple
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	CREATE TABLE #tblEmployeeIds (EmployeeId INT)

	INSERT INTO #tblEmployeeIds (EmployeeId)
	SELECT val
	FROM dbo.[fnc_strSplit](@EmployeeIds, ',')

	INSERT INTO dbo.SickLeaveTrans (
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
	SET SickLeaveBalance = ISNULL(SickLeaveBalance, 0) + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EXISTS (
			SELECT 1
			FROM #tblEmployeeIds WITH (NOLOCK)
			WHERE EmpId = EmployeeId
			)
	
	DROP TABLE #tblEmployeeIds
END





