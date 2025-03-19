/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_Reset] @RequestId BIGINT
	,@ActorId INT
	,@RoleId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: 20190522@Quinn.Vo
Task: reset check in/out request
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @EmpId INT
		,@OnDate DATE
		,@RequestTypeId SMALLINT
		,@RequestTime DATETIME
		,@ProcessedDate DATETIME = GETDATE()
		,@VerifierId INT
		,@ApproverId INT
		,@StatusId TINYINT
		-- request type
		,@CheckInRequestTypeId TINYINT = 1
		,@CheckOutRequestTypeId TINYINT = 2
		-- system role
		,@VerifierRoleId TINYINT = 2
		,@ApproverRoleId TINYINT = 3
		,@HRRoleId TINYINT = 6
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7

	SELECT @EmpId = cio.EmpId
		,@RequestTime = cio.RequestTime
		,@OnDate = cio.OnDate
		,@RequestTypeId = r.RequestType
		,@VerifierId = r.VerifierId
		,@ApproverId = r.ApproverId
		,@StatusId = r.CurrentStatus
	FROM dbo.CheckInOutRequest AS cio WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON cio.RequestId = r.RequestId
		AND r.RequestId = @RequestId

	IF @StatusId != @ProcessedStatusId
	BEGIN
		EXEC dbo.CheckInOutRequest_UpdateDiscipline @RequestId = @RequestId
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
	END
	ELSE IF @RoleId = @ApproverRoleId
		OR (
			@RoleId = @HRRoleId
			AND @ApprovedStatusId = @StatusId
			)
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
			UPDATE dbo.EmployeeCalendar WITH (ROWLOCK, UPDLOCK)
			SET RequestedCheckinTime = CASE 
					WHEN @RequestTypeId = @CheckInRequestTypeId THEN NULL
					ELSE RequestedCheckinTime
					END
				,RequestedCheckoutTime = CASE 
					WHEN @RequestTypeId = @CheckOutRequestTypeId THEN NULL
					ELSE RequestedCheckoutTime
					END
				,ModifiedBy = @ActorId
				,ModifiedDate = @ProcessedDate
			WHERE datediff(d, WorkDate, @OnDate) = 0
				AND EmpId = @EmpId

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
				,@OnDate
				,@OnDate
				,1
		END
	END
	ELSE IF @RoleId = @HRRoleId
		AND @ProcessedStatusId = @StatusId
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
			UPDATE dbo.EmployeeCalendar WITH (ROWLOCK, UPDLOCK)
			SET RequestedCheckinTime = CASE 
					WHEN @RequestTypeId = @CheckInRequestTypeId THEN @RequestTime
					ELSE RequestedCheckinTime
					END
				,RequestedCheckoutTime = CASE 
					WHEN @RequestTypeId = @CheckOutRequestTypeId THEN @RequestTime
					ELSE RequestedCheckoutTime
					END
				,ModifiedBy = @ActorId
				,ModifiedDate = @ProcessedDate
			WHERE EmpId = @EmpId
				AND datediff(d, WorkDate, @OnDate) = 0

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
				,@OnDate
				,@OnDate
				,1
		END
	END

	EXEC dbo.CheckInOutRequest_WriteLog @RequestId = @RequestId
		,@Comment = ''
END

