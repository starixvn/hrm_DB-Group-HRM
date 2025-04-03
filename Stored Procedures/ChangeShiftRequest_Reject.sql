/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_Reject] @RequestId BIGINT
	,@CompanyId SMALLINT
	,@ActorId INT
	,@RoleId TINYINT
	,@Comment NVARCHAR(500) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tim.Trinh@2019-09-17
Task: reject change shift
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
		-- change shift type
		,@ChangeShift TINYINT = 1
		,@MoveOffDay TINYINT = 2
		-- system role
		,@VerifierRoleId TINYINT = 2
		,@ApproverRoleId TINYINT = 3
		,@HRRoleId TINYINT = 6
		-- request status
		,@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7
	DECLARE @tblChangeShiftDetail TABLE (
		OnDate DATE
		,ToDate DATE
		)

	SELECT @EmpId = EmpId
		,@FromDate = FromDate
		,@ToDate = ToDate
		,@TypeId = TypeId
	FROM dbo.ChangeShiftRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId

	EXEC dbo.ChangeShiftRequest_UpdateDiscipline @RequestId = @RequestId
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

		EXEC dbo.ChangeShiftRequest_ResetCalendar @RequestId = @RequestId
			,@ActorId = @ActorId
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrCode OUTPUT
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

		EXEC dbo.ChangeShiftRequest_ResetCalendar @RequestId = @RequestId
			,@ActorId = @ActorId
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrCode OUTPUT
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

		IF @TypeId = @ChangeShift
		BEGIN
			UPDATE empca
			SET empca.ChangeShiftId = NULL
				,empca.ShiftId = NULL
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
				AND csdt.RequestId = @RequestId
				AND csdt.FromShift = - 1
			WHERE empca.EmpId = @EmpId
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
		,@Comment = @Comment
END