/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_Reset] @RequestId BIGINT
	,@ActorId INT
	,@RoleId TINYINT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20150925
Task: Reset leave request.
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
		,@VerifierId INT
		,@ApproverId INT
		,@StatusId TINYINT
		,@ProcessedDate DATETIME = GETDATE()
		-- system role
		,@VerifierRoleId TINYINT = 2
		,@ApproverRoleId TINYINT = 3
		,@HRRoleId TINYINT = 6
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7
		,@PaternityTypeId TINYINT = 14
		,@TotalDaysPaternity INT
		,@tmpFromDate DATE
		,@tmpToDate DATE

	SELECT @EmpId = lr.EmpId
		,@FromDate = lr.FromDate
		,@ToDate = lr.ToDate
		,@VerifierId = r.VerifierId
		,@ApproverId = r.ApproverId
		,@StatusId = r.CurrentStatus
	FROM dbo.LeaveRequest AS lr WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lr.RequestId = r.RequestId
		AND r.RequestId = @RequestId

	SELECT @TotalDaysPaternity = TotalDays
		,@tmpFromDate = FromDate
		,@tmpToDate = ToDate
	FROM dbo.LeaveRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId
		AND LeaveType = @PaternityTypeId

	IF ISNULL(@TotalDaysPaternity, 0) = 0
	BEGIN
		SELECT @TotalDaysPaternity = COUNT(1)
			,@tmpFromDate = MIN(OnDate)
			,@tmpToDate = MAX(OnDate)
		FROM dbo.LeaveRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId
			AND LeaveType = @PaternityTypeId
	END

	IF @TotalDaysPaternity > 0
		AND @StatusId IN (@NotVerifiedStatusId, @RejectedStatusId)
	BEGIN
		UPDATE dbo.EmployeePaternity WITH (ROWLOCK, UPDLOCK)
		SET BalanceDay = BalanceDay - @TotalDaysPaternity
		WHERE EmpId = @EmpId
			AND @tmpFromDate >= ChildBornDate
			AND @tmpToDate <= DATEADD(M, 1, ChildBornDate)
	END

	IF @StatusId <> @ProcessedStatusId
	BEGIN
		EXEC dbo.LeaveRequest_UpdateDiscipline @RequestId = @RequestId
			,@ActorId = @ActorId
			,@RequestStatusId = @PendingStatusId
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END

	IF @RoleId = @VerifierRoleId
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @PendingStatusId
			,VerifiedStatus = @PendingStatusId
			--,VerifierId = @ActorId
			,VerifiedDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId

		IF @StatusId = @NotVerifiedStatusId
		BEGIN
			EXEC dbo.LeaveRequest_UpdateTmpAnnualLeaveTrans @RequestId = @RequestId
				,@EmpId = @EmpId
				,@Status = 0

			EXEC dbo.LeaveRequest_UpdateTmpHospitalizationLeaveTrans @RequestId = @RequestId
				,@Status = 0

			EXEC dbo.LeaveRequest_UpdateTmpSickLeaveTrans @RequestId = @RequestId
				,@Status = 0

			EXEC dbo.LeaveRequest_InsertKIVLeaveTrans @RequestId = @RequestId

			EXEC dbo.LeaveRequest_InsertWeekendLeaveTrans @RequestId = @RequestId
		END
	END
	ELSE IF (@RoleId = @ApproverRoleId OR(@RoleId = @HRRoleId AND @ApprovedStatusId = @StatusId))
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @PendingStatusId
			,VerifiedStatus = @PendingStatusId
			,ApprovedStatus = @PendingStatusId
			--,ApproverId = @ActorId
			,ApprovedDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId

		IF @StatusId = @ApprovedStatusId
		BEGIN
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

			EXEC dbo.LeaveRequest_UpdateTmpAnnualLeaveTrans @Requestid = @RequestId
				,@EmpId = @EmpId
				,@Status = 0

			EXEC dbo.LeaveRequest_UpdateTmpHospitalizationLeaveTrans @RequestId = @RequestId
				,@Status = 0

			EXEC dbo.LeaveRequest_UpdateTmpSickLeaveTrans @RequestId = @RequestId
				,@Status = 0
		END

		IF @StatusId = @RejectedStatusId
		BEGIN
			EXEC dbo.LeaveRequest_UpdateTmpAnnualLeaveTrans @RequestId = @RequestId
				,@EmpId = @EmpId
				,@Status = 0

			EXEC dbo.LeaveRequest_UpdateTmpHospitalizationLeaveTrans @RequestId = @RequestId
				,@Status = 0

			EXEC dbo.LeaveRequest_UpdateTmpSickLeaveTrans @RequestId = @RequestId
				,@Status = 0

			EXEC dbo.LeaveRequest_InsertKIVLeaveTrans @RequestId = @RequestId

			EXEC dbo.LeaveRequest_InsertWeekendLeaveTrans @RequestId = @RequestId
		END
	END
	ELSE IF @RoleId = @HRRoleId AND @ProcessedStatusId = @StatusId
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @ApprovedStatusId
			,HRStatus = @PendingStatusId
			,HRId = @ActorId
			,HRDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId

		IF @StatusId = @VoidStatusId
		BEGIN
			EXEC dbo.LeaveRequest_InsertKIVLeaveTrans @RequestId = @RequestId

			EXEC dbo.LeaveRequest_InsertWeekendLeaveTrans @RequestId = @RequestId

			EXEC dbo.LeaveRequest_UpdateTmpAnnualLeaveTrans @Requestid = @RequestId
				,@EmpId = @EmpId
				,@Status = 1

			EXEC dbo.LeaveRequest_UpdateTmpHospitalizationLeaveTrans @RequestId = @RequestId
				,@Status = 1

			EXEC dbo.LeaveRequest_UpdateTmpSickLeaveTrans @RequestId = @RequestId
				,@Status = 1

			EXEC dbo.LeaveRequest_Approve_UpdateCalendar @RequestId
				,@EmpId
				,@ActorId

			EXEC dbo.AnnualLeave_InsertTransactionByRequestId @RequestId
				,@EmpId
				,@FromDate
				,@ToDate
				,@ActorId

			EXEC dbo.HospitalizationLeave_InsertTransactionByRequestId @RequestId
				,@EmpId
				,@FromDate
				,@ToDate
				,@ActorId

			EXEC dbo.SickLeave_InsertTransactionByRequestId @RequestId
				,@EmpId
				,@FromDate
				,@ToDate
				,@ActorId

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
				,@FromDate
				,@ToDate
				,1
		END
	END

	EXEC dbo.LeaveRequest_EmployeeCalendar_UpdateOffDay @RequestId

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @FromDate
		,@toDate = @ToDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1

	EXEC dbo.LeaveRequest_WriteLog @RequestId = @RequestId
		,@Comment = ''
END






