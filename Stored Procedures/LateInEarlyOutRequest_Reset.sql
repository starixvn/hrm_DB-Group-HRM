/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_Reset] @RequestId BIGINT
	,@RoleId TINYINT
	,@ActorId INT
    ,@CompanyId SMALLINT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: Quinn.Vo@20190625
Task: reset late in/early out request 
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @EmpId INT
		,@OnDate DATE
		,@LateIn INT
		,@EarlyOut INT
		,@RequestTypeId TINYINT
		,@ProcessedDate DATETIME = GETDATE()
		,@VerifierId INT
		,@ApproverId INT
		,@StatusId TINYINT
		-- request type
		,@LateInRequestTypeId TINYINT = 3
		,@EarlyOutRequestTypeId TINYINT = 4
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

	SELECT @EmpId = lieo.EmpId
		,@OnDate = lieo.OnDate
		,@LateIn = lieo.LateInMins
		,@EarlyOut = lieo.EarlyOutMins
		,@RequestTypeId = r.RequestType
		,@VerifierId = r.VerifierId
		,@ApproverId = r.ApproverId
		,@StatusId = r.CurrentStatus
	FROM dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lieo.RequestId = r.RequestId
		AND r.RequestId = @RequestId

	IF @StatusId <> @ProcessedStatusId
	BEGIN
		EXEC dbo.LateInEarlyOutRequest_UpdateDiscipline @RequestId = @RequestId
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
			WHERE EmpId = @EmpId
				AND WorkDate = @OnDate

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
				,@OnDate
				,@OnDate
				,1
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
			UPDATE dbo.EmployeeCalendar WITH (ROWLOCK, UPDLOCK)
			SET LateIn = CASE 
					WHEN @RequestTypeId = @LateInRequestTypeId THEN @LateIn
					ELSE LateIn
					END
				,EarlyOut = CASE 
					WHEN @RequestTypeId = @EarlyOutRequestTypeId THEN @EarlyOut
					ELSE EarlyOut
					END
				,ModifiedBy = @ActorId
				,ModifiedDate = @ProcessedDate
			WHERE EmpId = @EmpId
				AND WorkDate = @OnDate

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert @CompanyId = @CompanyId
                ,@EmpId = @EmpId
				,@FromTime = @OnDate
				,@ToTime = @OnDate
				,@OnlyUpdate = 1
		END
	END

	EXEC dbo.LateInEarlyOutRequest_WriteLog @RequestId = @RequestId
		,@Comment = ''
END