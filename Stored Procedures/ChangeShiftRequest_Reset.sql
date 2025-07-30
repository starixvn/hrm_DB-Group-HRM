/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_Reset] @RequestId BIGINT
	,@RoleId TINYINT
	,@ActorId INT
	,@CompanyId SMALLINT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: Tim.Trinh@2019-09-17
Task: reset status
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @EmpId INT
		,@TypeId TINYINT
		,@FromDate DATE
		,@ToDate DATE
		,@ProcessedDate DATETIME = GETDATE()
		,@StatusId TINYINT
		,@VerifierId INT
		,@ApproverId INT
		-- change shift type
		,@ChangeShift TINYINT = 1
		,@MoveOffDay TINYINT = 2
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
	DECLARE @tblChangeShiftDetail TABLE (
		OnDate DATE
		,ToDate DATE
		)

	SELECT @EmpId = cs.EmpId
		,@FromDate = cs.FromDate
		,@ToDate = cs.ToDate
		,@TypeId = cs.TypeId
		,@StatusId = r.CurrentStatus
		,@VerifierId = r.VerifierId
		,@ApproverId = r.ApproverId
	FROM dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON cs.RequestId = r.RequestId
		AND cs.RequestId = @RequestId

	IF @StatusId <> @ProcessedStatusId
	BEGIN
		EXEC dbo.ChangeShiftRequest_UpdateDiscipline @RequestId = @RequestId
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
	ELSE IF (
			@RoleId = @ApproverRoleId
			OR (
				@RoleId = @HRRoleId
				AND @ApprovedStatusId = @StatusId
				)
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
			IF @TypeId = @ChangeShift
			BEGIN
				UPDATE empca
				SET empca.ShiftId = NULL
					,empca.IsOffDay = 1
					,empca.ModifiedBy = @ActorId
					,empca.ModifiedDate = @ProcessedDate
				FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.OnDate
					AND empca.EmpId = csdt.EmpId
					AND csdt.RequestId = @RequestId
					AND csdt.ToShift <> - 1
				WHERE empca.EmpId = @EmpId
					AND empca.ChangeShiftId IS NULL

				UPDATE empca
				SET empca.IsOffDay = 0
					,empca.ChangeShiftId = NULL
					,empca.ShiftId = csdt.FromShift
					,empca.ModifiedBy = @ActorId
					,empca.ModifiedDate = @ProcessedDate
				FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.OnDate
					AND empca.EmpId = csdt.EmpId
					AND csdt.FromShift <> - 1
					AND csdt.RequestId = @RequestId
				WHERE empca.EmpId = @EmpId
					AND empca.ChangeShiftId IS NOT NULL

				UPDATE empca
				SET empca.ChangeShiftId = NULL
					,empca.ShiftId = empca.ChangeShiftId
					,empca.IsOffDay = 1
					,empca.ModifiedBy = @ActorId
					,empca.ModifiedDate = @ProcessedDate
				FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.OnDate
					AND empca.EmpId = csdt.EmpId
				WHERE empca.EmpId = @EmpId
					AND csdt.RequestId = @RequestId
					AND csdt.FromShift = - 1
					AND empca.ChangeShiftId IS NOT NULL
			END
			ELSE
			BEGIN
				UPDATE empca
				SET empca.IsOffDay = 1
					,empca.ShiftId = NULL
					,empca.ModifiedBy = @ActorId
					,empca.ModifiedDate = @ProcessedDate
				FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.OnDate
					AND empca.EmpId = csdt.EmpId
					AND csdt.RequestId = @RequestId
				WHERE empca.EmpId = @EmpId
					AND empca.IsOffDay = 0

				UPDATE empca
				SET empca.IsOffDay = 0
					,empca.ModifiedBy = @ActorId
					,empca.ModifiedDate = @ProcessedDate
				FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.ToDate
					AND empca.EmpId = csdt.EmpId
					AND csdt.RequestId = @RequestId
				WHERE empca.EmpId = @EmpId
					AND empca.IsOffDay = 1
			END
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
			IF @TypeId = @ChangeShift
			BEGIN
				UPDATE empca
				SET empca.IsOffDay = 1
					,empca.ChangeShiftId = csdt.FromShift
					,empca.ShiftId = NULL
					,empca.ModifiedBy = @ActorId
					,empca.ModifiedDate = @ProcessedDate
				FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.OnDate
					AND empca.EmpId = csdt.EmpId
					AND csdt.ToShift = - 1
					AND csdt.RequestId = @RequestId
				WHERE empca.EmpId = @EmpId

				UPDATE empca
				SET empca.ChangeShiftId = NULL
					,empca.ShiftId = csdt.ToShift
					,empca.IsOffDay = 0
					,empca.ModifiedBy = @ActorId
					,empca.ModifiedDate = @ProcessedDate
				FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.OnDate
					AND empca.EmpId = csdt.EmpId
					AND csdt.RequestId = @RequestId
					AND csdt.ToShift <> - 1
				WHERE empca.EmpId = @EmpId
					AND empca.IsOffDay = 1

				UPDATE empca
				SET empca.ChangeShiftId = csdt.FromShift
					,empca.ShiftId = csdt.ToShift
					,empca.ModifiedBy = @ActorId
					,empca.ModifiedDate = @ProcessedDate
				FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.OnDate
					AND empca.EmpId = csdt.EmpId
					AND csdt.RequestId = @RequestId
					AND csdt.ToShift <> - 1
				WHERE empca.EmpId = @EmpId
					AND empca.IsOffDay = 0
			END
			ELSE
			BEGIN
				UPDATE empca
				SET empca.IsOffDay = 0
					,empca.ShiftId = CASE WHEN csdt.ToShift > 0 THEN csdt.ToShift ELSE empca.ShiftId END
					,empca.ModifiedBy = @ActorId
					,empca.ModifiedDate = @ProcessedDate
				FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.OnDate
					AND empca.EmpId = csdt.EmpId
					AND csdt.RequestId = @RequestId
				WHERE empca.EmpId = @EmpId
					AND empca.IsOffDay = 1

				UPDATE empca
				SET empca.IsOffDay = 1
					,empca.ShiftId = NULL
					,empca.ModifiedBy = @ActorId
					,empca.ModifiedDate = @ProcessedDate
				FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.ToDate
					AND empca.EmpId = csdt.EmpId
					AND csdt.RequestId = @RequestId
				WHERE empca.EmpId = @EmpId
					AND empca.IsOffDay = 0
			END
		END
	END

	IF (
			@RoleId = @ApproverRoleId
			AND @StatusId = @ApprovedStatusId
			)
		OR (
			@RoleId = @HRRoleId
			AND @StatusId = @VoidStatusId
			)
	BEGIN
		INSERT INTO @tblChangeShiftDetail (
			OnDate
			,ToDate
			)
		SELECT OnDate
			,ToDate
		FROM dbo.ChangeShiftRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId

		WHILE EXISTS (
				SELECT 1
				FROM @tblChangeShiftDetail
				)
		BEGIN
			SELECT TOP 1 @FromDate = OnDate
			FROM @tblChangeShiftDetail

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
				,@FromDate
				,@FromDate
				,1

			IF @TypeId = @MoveOffDay
			BEGIN
				SELECT TOP 1 @ToDate = ToDate
				FROM @tblChangeShiftDetail
				WHERE OnDate = @FromDate

				EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
					,@ToDate
					,@ToDate
					,1
			END

			DELETE
			FROM @tblChangeShiftDetail
			WHERE OnDate = @FromDate
		END
	END

	IF @TypeId = @ChangeShift
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

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @FromDate
		,@toDate = @ToDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1

	EXEC dbo.ScheduleArrangement_UpdateOffDayReplacement @CompanyId = @CompanyId
        ,@ActorId = @ActorId
		,@FromDate = @FromDate
		,@ToDate = @ToDate
		,@EmployeeIds = @EmpId
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	EXEC dbo.ChangeShiftRequest_WriteLog @RequestId = @RequestId
		,@Comment = ''
END