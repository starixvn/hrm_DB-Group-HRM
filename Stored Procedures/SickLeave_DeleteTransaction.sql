/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SickLeave_DeleteTransaction] @TransId INT
	,@ModifiedDate DATETIME
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tim.Trinh@2021-08-23
Task: delete transaction
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
		,@isDeleted BIT

	SELECT @EmpId = EmpId
		,@OldDeductDays = ISNULL(DeductDays, 0)
		,@OldCreditDays = ISNULL(CreditDays, 0)
		,@isDeleted = IsDeleted
	FROM dbo.SickLeaveTrans WITH (NOLOCK)
	WHERE TransId = @TransId

	IF ISNULL(@isDeleted, 0) <> 1
	BEGIN
		UPDATE dbo.SickLeaveTrans WITH (ROWLOCK, UPDLOCK)
		SET IsDeleted = 1
			,ModifiedDate = @ModifiedDate
			,ModifiedBy = @ModifiedBy
		WHERE TransId = @TransId

		UPDATE dbo.EmployeeSummary WITH (ROWLOCK, UPDLOCK)
		SET SickLeaveBalance = ISNULL(SickLeaveBalance, 0) + @OldDeductDays - @OldCreditDays
		WHERE EmpId = @EmpId
	END
END


