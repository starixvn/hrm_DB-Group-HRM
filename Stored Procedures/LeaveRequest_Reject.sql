/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_Reject] @RequestId BIGINT
	,@ActorId INT
	,@RoleId TINYINT
	,@Comment NVARCHAR(500) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20150929
Task: reject leave request
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @EmpId INT
		,@FromDate DATETIME
		,@ToDate DATETIME
		,@ProcessedDate DATETIME = GETDATE()
		-- system role
		,@VerifierRoleId TINYINT = 2
		,@ApproverRoleId TINYINT = 3
		,@HRRoleId TINYINT = 6
		-- request status
		,@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7
		,@PaternityTypeId TINYINT = 14
		,@TotalDaysPaternity INT
		-- leave type
		,@LeaveTypeId TINYINT

	SELECT @TotalDaysPaternity = TotalDays
		,@FromDate = FromDate
		,@ToDate = ToDate
		,@EmpId = EmpId
	FROM dbo.LeaveRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId
		AND LeaveType = @PaternityTypeId

	IF ISNULL(@TotalDaysPaternity, 0) = 0
	BEGIN
		SELECT @TotalDaysPaternity = COUNT(1)
			,@FromDate = MIN(OnDate)
			,@ToDate = MAX(OnDate)
			,@EmpId = MIN(EmpId)
		FROM dbo.LeaveRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId
			AND LeaveType = @PaternityTypeId
	END

	IF @TotalDaysPaternity > 0
	BEGIN
		UPDATE dbo.EmployeePaternity WITH (ROWLOCK, UPDLOCK)
		SET BalanceDay = BalanceDay + @TotalDaysPaternity
		WHERE EmpId = @EmpId
			AND @FromDate >= ChildBornDate
			AND @ToDate <= DATEADD(M, 1, ChildBornDate)
	END

	SELECT @EmpId = EmpId
		,@FromDate = FromDate
		,@ToDate = ToDate
		,@LeaveTypeId = LeaveType
	FROM dbo.LeaveRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId

	EXEC dbo.LeaveRequest_UpdateDiscipline @RequestId = @RequestId
		,@ActorId = @ActorId
		,@RequestStatusId = @NotVerifiedStatusId
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	IF @RoleId = @VerifierRoleId
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @NotVerifiedStatusId
			,VerifiedStatus = @NotVerifiedStatusId
			--,VerifierId = @ActorId
			,VerifiedDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId
	END
	ELSE IF @RoleId = @ApproverRoleId
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @RejectedStatusId
			,ApprovedStatus = @NotVerifiedStatusId
			--,ApproverId = @ActorId
			,ApprovedDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId
	END
	ELSE IF @RoleId = @HRRoleId
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @VoidStatusId
			,HRStatus = @NotVerifiedStatusId
			,HRId = @ActorId
			,HRDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId

		EXEC dbo.LeaveRequest_Reject_RollbackCalendar @RequestId
			,@EmpId
			,@ActorId

		EXEC dbo.AnnualLeave_DeleteTransactionByRequestId @RequestId
			,@ProcessedDate
			,@ActorId

		EXEC dbo.HospitalizationLeave_DeleteTransactionByRequestId @RequestId
			,@ProcessedDate
			,@ActorId

		EXEC dbo.SickLeave_DeleteTransactionByRequestId @RequestId
			,@ProcessedDate
			,@ActorId

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
			,@FromDate
			,@ToDate
			,1
	END

	EXEC dbo.LeaveRequest_DeleteWeekendLeaveTrans @RequestId = @RequestId

	EXEC dbo.LeaveRequest_DeleteKIVLeaveTrans @RequestId = @RequestId

	EXEC dbo.LeaveRequest_UpdateTmpAnnualLeaveTrans @RequestId = @RequestId
		,@EmpId = @EmpId
		,@Status = 2

	EXEC dbo.LeaveRequest_UpdateTmpHospitalizationLeaveTrans @RequestId = @RequestId
		,@Status = 2

	EXEC dbo.LeaveRequest_UpdateTmpSickLeaveTrans @RequestId = @RequestId
		,@Status = 2

	EXEC dbo.LeaveRequest_EmployeeCalendar_ResetOffDay @empId = @EmpId
		,@LeaveTypeId = @LeaveTypeId
		,@fromDate = @FromDate
		,@toDate = @ToDate

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @FromDate
		,@toDate = @ToDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1

	EXEC dbo.LeaveRequest_WriteLog @RequestId = @RequestId
		,@Comment = @Comment
END



