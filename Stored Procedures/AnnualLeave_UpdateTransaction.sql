/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_UpdateTransaction] @LeaveTransId INT
	,@Description NVARCHAR(4000) = ''
	,@FromDate DATETIME
	,@DeductDays NUMERIC(18, 1)
	,@CreditDays NUMERIC(18, 1)
	,@ModifiedDate DATETIME
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013.10.22
Task: update leave transaction and calculate annual leave balance for employee
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @OldDeductDays NUMERIC(18, 1)
		,@OldCreditDays NUMERIC(18, 1)
		,@EmpId INT

	SELECT @EmpId = EmpId
		,@OldDeductDays = ISNULL(DeductDays, 0)
		,@OldCreditDays = ISNULL(CreditDays, 0)
	FROM dbo.LeaveTrans WITH (NOLOCK)
	WHERE LeaveTransId = @LeaveTransId

	UPDATE dbo.LeaveTrans WITH (ROWLOCK, UPDLOCK)
	SET [Description] = @Description
		,FromDate = @FromDate
		,DeductDays = @DeductDays
		,CreditDays = @CreditDays
		,ModifiedDate = @ModifiedDate
		,ModifiedBy = @ModifiedBy
	WHERE LeaveTransId = @LeaveTransId

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK, UPDLOCK)
	SET AnnualLeaveBalance = ISNULL(AnnualLeaveBalance, 0) + @OldDeductDays - @OldCreditDays + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EmpId = @EmpId
END
