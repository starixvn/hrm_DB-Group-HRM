/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_VoidBySA] @RequestId BIGINT
	,@ActorId INT
	,@Comment NVARCHAR(500) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: 20151026@Quinn.Vo
Task: Void request by SA
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @StatusId INT
		,@ProcessedDate DATETIME = GETDATE()
		,@FromDate DATE
		,@ToDate DATE
		,@EmpId INT
		,@LeaveTypeId INT
		-- request status
		,@PaternityTypeId TINYINT = 14
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7
		,@TotalDaysPaternity INT

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

	SELECT @StatusId = r.CurrentStatus
		,@FromDate = lr.FromDate
		,@ToDate = lr.ToDate
		,@EmpId = r.EmpId
		,@LeaveTypeId = lr.LeaveType
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		AND lr.RequestId = @RequestId

	EXEC dbo.LeaveRequest_UpdateDiscipline @RequestId = @RequestId
		,@ActorId = @ActorId
		,@RequestStatusId = @VoidStatusId
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
	SET CurrentStatus = @VoidStatusId
		,HRId = @ActorId
		,HRDate = @ProcessedDate
		,ModifiedBy = @ActorId
		,ModifiedDate = @ProcessedDate
	WHERE RequestId = @RequestId

	IF @StatusId IN (@ApprovedStatusId, @ProcessedStatusId)
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
	END

	EXEC dbo.LeaveRequest_UpdateTmpAnnualLeaveTrans @RequestId = @RequestId
		,@EmpId = @EmpId
		,@Status = 2

	EXEC dbo.LeaveRequest_UpdateTmpHospitalizationLeaveTrans @RequestId = @RequestId
		,@Status = 2

	EXEC dbo.LeaveRequest_UpdateTmpSickLeaveTrans @RequestId = @RequestId
		,@Status = 2

	EXEC dbo.LeaveRequest_DeleteKIVLeaveTrans @RequestId = @RequestId

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






