/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
		20251027@Henry: fix issue with company employee 
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	CREATE TABLE #tblEmployeeIds (EmployeeId INT)

	INSERT INTO #tblEmployeeIds (EmployeeId)
	SELECT value
	FROM STRING_SPLIT(@EmployeeIds, ',')

	INSERT INTO dbo.SickLeaveTrans (
		EmpId
		,[Description]
		,FromDate
		,DeductDays
		,CreditDays
		,CreatedDate
		,CreatedBy
		)
	SELECT ce.EmpId
		,@Description
		,@FromDate
		,@DeductDays
		,@CreditDays
		,GETDATE()
		,@ActorId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid ON ce.EmpId = empid.EmployeeId
	WHERE ISNULL(ce.isDeleted, 0) = 0

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK, UPDLOCK)
	SET SickLeaveBalance = ISNULL(SickLeaveBalance, 0) + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EXISTS (
			SELECT 1
			FROM #tblEmployeeIds WITH (NOLOCK)
			WHERE EmpId = EmployeeId
			)
	
	DROP TABLE #tblEmployeeIds
END






