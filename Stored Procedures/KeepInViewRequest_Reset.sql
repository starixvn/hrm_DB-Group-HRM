/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_Reset] @RequestId BIGINT
	,@RoleId TINYINT
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: 20190522@Quinn.Vo
Task: reset keep in view request
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @OnDate DATE
		,@EmpId INT
		,@StatusId TINYINT
		,@VerifierId INT
		,@ApproverId INT
		,@TotalMinutes INT
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
		,@VoidStatusId TINYINT = 7
		,@ProcessedStatusId TINYINT = 6

	SELECT @OnDate = kiv.OnDate
		,@EmpId = r.EmpId
		,@VerifierId = r.VerifierId
		,@ApproverId = r.ApproverId
		,@StatusId = r.CurrentStatus
		,@TotalMinutes = DATEDIFF(MI, kiv.FromTime, kiv.ToTime)
	FROM dbo.KeepInViewRequest AS kiv WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON kiv.RequestId = r.RequestId
		AND r.RequestId = @RequestId

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
			UPDATE empca
			SET empca.IsKeepInView = 0
				,empca.ShiftId = CASE WHEN kiv.ShiftId IS NOT NULL THEN NULL ELSE empca.ShiftId END
				,empca.ModifiedBy = @ActorId
				,empca.ModifiedDate = @ProcessedDate
			FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
				INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON empca.WorkDate = kiv.OnDate
				AND empca.EmpId = kiv.EmpId
				AND kiv.RequestId = @RequestId

			EXEC dbo.KeepInViewRequest_DeleteTrans @RequestId = @RequestId

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
			UPDATE empca
			SET empca.IsKeepInView = 1
				,empca.ShiftId = ISNULL(kiv.ShiftId, empca.ShiftId)
				,empca.ModifiedBy = @ActorId
				,empca.ModifiedDate = @ProcessedDate
			FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
				INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON empca.WorkDate = kiv.OnDate
				AND empca.EmpId = kiv.EmpId
				AND kiv.RequestId = @RequestId

			EXEC dbo.KeepInViewRequest_InsertTrans @RequestId = @RequestId

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
				,@OnDate
				,@OnDate
				,1
		END
	END

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId 
		,@fromDate = @OnDate
		,@toDate = @OnDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1

	EXEC dbo.KeepInViewRequest_WriteLog @RequestId = @RequestId
		,@Comment = ''
END

