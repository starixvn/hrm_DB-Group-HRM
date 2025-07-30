/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_VoidBySA] @RequestId BIGINT
	,@ActorId INT
	,@Comment NVARCHAR(500) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: 20151026@Quinn.Vo
Task: Void request late in/early out by SA
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
		,@OnDate DATE
		,@EmpId INT
		,@RequestTypeId TINYINT
		-- request type
		,@LateInRequestTypeId TINYINT = 3
		,@EarlyOutRequestTypeId TINYINT = 4
		-- request status
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7

	SELECT @EmpId = lieo.EmpId
		,@OnDate = lieo.OnDate
		,@RequestTypeId = r.RequestType
		,@StatusId = r.CurrentStatus
	FROM dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lieo.RequestId = r.RequestId
		AND r.RequestId = @RequestId

	EXEC dbo.LateInEarlyOutRequest_UpdateDiscipline @RequestId = @RequestId
		,@ActorId = @ActorId
		,@RequestStatusId = @VoidStatusId
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
	SET CurrentStatus = @VoidStatusId
		,ModifiedBy = @ActorId
		,ModifiedDate = @ProcessedDate
	WHERE RequestId = @RequestId

	IF @StatusId IN (@ApprovedStatusId, @ProcessedStatusId)
	BEGIN
		UPDATE dbo.EmployeeCalendar WITH (ROWLOCK, UPDLOCK)
		SET LateIn = CASE 
				WHEN @RequestTypeId = @LateInRequestTypeId THEN 0
				ELSE LateIn
				END
			,EarlyOut = CASE 
				WHEN @RequestTypeId = @EarlyOutRequestTypeId THEN 0
				ELSE EarlyOut
				END
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE WorkDate = @OnDate
			AND EmpId = @EmpId

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
			,@OnDate
			,@OnDate
			,1
	END

	EXEC dbo.LateInEarlyOutRequest_WriteLog @RequestId = @RequestId
		,@Comment = @Comment
END



