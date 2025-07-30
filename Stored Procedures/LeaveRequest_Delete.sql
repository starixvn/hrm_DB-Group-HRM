/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_Delete] @RequestId BIGINT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190416
Task: delete a leave request
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @PendingStatusId TINYINT = 1
		,@EmpId INT
		,@FromDate DATE
		,@ToDate DATE
		,@TotalDaysPaternity INT
		,@LeaveTypeId TINYINT
		-- leave type 
		,@PaternityLeaveType TINYINT = 14

	IF NOT EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest WITH (NOLOCK)
			WHERE RequestId = @RequestId
				AND CurrentStatus = @PendingStatusId
			)
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'Status is not pending, you can not delete this request.'

		RETURN;
	END

	SELECT @TotalDaysPaternity = TotalDays
		,@FromDate = FromDate
		,@ToDate = ToDate
		,@EmpId = EmpId
	FROM dbo.LeaveRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId
		AND LeaveType = @PaternityLeaveType

	IF ISNULL(@TotalDaysPaternity, 0) = 0
	BEGIN
		SELECT @TotalDaysPaternity = COUNT(1)
			,@FromDate = MIN(OnDate)
			,@ToDate = MAX(OnDate)
			,@EmpId = MIN(EmpId)
		FROM dbo.LeaveRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId
			AND LeaveType = @PaternityLeaveType
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

	DELETE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.LeaveRequest WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.LeaveRequestDetail WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.tmpLeaveBalance WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.KeepInViewByDayTrans WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	--DELETE dbo.KeepInViewByHourTrans
	--WHERE RequestId = @RequestId

	EXEC dbo.LeaveRequest_InsertKIVLeaveTrans  @RequestId = @RequestId

	DELETE dbo.WeekendLeaveTrans WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.DisciplineRequestTrans WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.tmpHospitalizationLeaveBalance WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.HospitalLeave WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.tmpSickLeaveBalance WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	EXEC dbo.LeaveRequest_EmployeeCalendar_ResetOffDay @empId = @EmpId
		,@LeaveTypeId = @LeaveTypeId
		,@fromDate = @FromDate
		,@toDate = @ToDate

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @FromDate
		,@toDate = @ToDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1
END