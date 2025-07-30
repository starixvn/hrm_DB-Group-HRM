/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


ALTER PROCEDURE [dbo].[SickLeave_UpdateTransaction] @TransId BIGINT
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
Created: Tim.Trinh@2021-08-23
Task: update transaction
DB: HRM
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
	FROM dbo.SickLeaveTrans WITH (NOLOCK)
	WHERE TransId = @TransId

	UPDATE dbo.SickLeaveTrans WITH (ROWLOCK, UPDLOCK)
	SET [Description] = @Description
		,FromDate = @FromDate
		,ToDate = @FromDate
		,DeductDays = @DeductDays
		,CreditDays = @CreditDays
		,ModifiedDate = @ModifiedDate
		,ModifiedBy = @ModifiedBy
	WHERE TransId = @TransId

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK, UPDLOCK)
	SET SickLeaveBalance = ISNULL(SickLeaveBalance, 0) + @OldDeductDays - @OldCreditDays + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EmpId = @EmpId
END


