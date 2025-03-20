/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_Delete] @RequestId BIGINT
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-09-17
Task: delete change shift
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @CurrentStatus INT
		-- request status
		,@PendingStatusId TINYINT = 1
		,@EmpId INT
		,@TypeId TINYINT
		,@FromDate DATE
		,@ToDate DATE

	SELECT @CurrentStatus = CurrentStatus
	FROM dbo.WorkingTimeRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId

	IF @CurrentStatus <> @PendingStatusId
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'Status is not pending, you can not delete this request.'

		RETURN
	END

	SELECT @EmpId = EmpId
		,@TypeId = TypeId
	FROM dbo.ChangeShiftRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId

	IF @TypeId = 1
	BEGIN
		SELECT @FromDate = MIN(OnDate)
			,@ToDate = MAX(OnDate)
		FROM dbo.ChangeShiftRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId
	END
	ELSE
	BEGIN
		SELECT @FromDate = MIN(OnDate)
			,@ToDate = MAX(ToDate)
		FROM dbo.ChangeShiftRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId
	END

	EXEC dbo.ChangeShiftRequest_ResetCalendar @RequestId = @RequestId
		,@ActorId = @ActorId
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrCode OUTPUT

	DELETE dbo.WorkingTimeRequest WITH (ROWLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.ChangeShiftRequest WITH (ROWLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.ChangeShiftRequestHistory WITH (ROWLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.ChangeShiftRequestDetail WITH (ROWLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.ChangeShiftRequestDetailHistory WITH (ROWLOCK)
	WHERE RequestId = @RequestId

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @FromDate
		,@toDate = @ToDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1

	EXEC dbo.ScheduleArrangement_UpdateOffDayReplacement @ActorId = @ActorId
		,@FromDate = @FromDate
		,@ToDate = @ToDate
		,@EmployeeIds = @EmpId
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END