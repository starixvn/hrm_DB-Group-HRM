/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[HospitalizationLeave_DeleteTransactionByRequestId] @RequestId INT
	,@ModifiedDate DATETIME
	,@ModifiedBy INT
AS
/*
Created: Tim.Trinh@2021-08-24
Task: delete transaction
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @OldDeductDays NUMERIC(18, 1)
		,@OldCreditDays NUMERIC(18, 1)
		,@EmpId INT
		,@IsDeleted BIT

	SELECT @EmpId = EmpId
		,@OldDeductDays = ISNULL(DeductDays, 0)
		,@OldCreditDays = ISNULL(CreditDays, 0)
		,@IsDeleted = IsDeleted
	FROM dbo.HospitalizationLeaveTrans WITH (NOLOCK)
	WHERE RequestId = @RequestId

	IF ISNULL(@isDeleted, 0) = 1 RETURN

	UPDATE dbo.HospitalizationLeaveTrans WITH (ROWLOCK, UPDLOCK)
	SET IsDeleted = 1
		,ModifiedDate = @ModifiedDate
		,ModifiedBy = @ModifiedBy
	WHERE RequestId = @RequestId

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK, UPDLOCK)
	SET HospitalizationLeaveBalance = ISNULL(HospitalizationLeaveBalance, 0) + @OldDeductDays - @OldCreditDays
	WHERE EmpId = @EmpId
END


