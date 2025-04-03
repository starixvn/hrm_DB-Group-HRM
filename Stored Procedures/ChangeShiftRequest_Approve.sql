/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_Approve] @RequestId BIGINT
	,@RoleId TINYINT
	,@ActorId INT
	,@Comment NVARCHAR(500) = ''
	,@DisciplineXml NVARCHAR(MAX) = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: Quinn.Vo@20190628
Task: approve change shift request 
DB: HRM

Revisions:
Param's Explanation:
    @DisciplineXml:
        <Root>
            <Row WorkDate='' EmployeeId='' DisciplineTypeId='' IsIgnored='' IsConfirmed='' />
        </Root>
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @TypeId TINYINT
		,@FromDate DATE
		,@ToDate DATE
		,@EmpId INT
        ,@CompanyId SMALLINT
		,@ProcessedDate DATETIME = GETDATE()
		-- change shift type
		,@ChangeShift TINYINT = 1
		,@MoveOffDay TINYINT = 2
		-- system role
		,@VerifierRoleId TINYINT = 2
		,@ApproverRoleId TINYINT = 3
		,@HRRoleId TINYINT = 6
		-- request status
		,@VerifiedStatusId TINYINT = 2
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6

	SELECT @EmpId = EmpId
		,@FromDate = FromDate
		,@ToDate = ToDate
		,@TypeId = TypeId
	FROM dbo.ChangeShiftRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.Employee AS emp WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
    WHERE emp.EmpId = @EmpId

	IF EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
				INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON r.RequestId = cs.RequestId
				INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
				AND csdt.OnDate BETWEEN @FromDate
					AND @ToDate
			WHERE r.RequestId <> @RequestId
				AND cs.TypeId = @TypeId
				AND r.EmpId = @EmpId
				AND r.CurrentStatus IN (@ApprovedStatusId, @ProcessedStatusId)
			)
	BEGIN
		SET @ErrCode = 103
		SET @ErrMsg = 'Another approved request in the same date has existed.'

		RETURN
	END

	CREATE TABLE #tblChangeShiftDetail (
		RowIndex INT IDENTITY(1, 1)
		,OnDate DATE
		,ToDate DATE
		)

	INSERT INTO #tblChangeShiftDetail (
		OnDate
		,ToDate
		)
	SELECT OnDate
		,ToDate
	FROM dbo.ChangeShiftRequestDetail WITH (NOLOCK)
	WHERE RequestId = @RequestId

	DECLARE @TotalRows INT
		,@RowIndex INT = 1
		,@tmpOnDate DATE
		,@tmpToDate DATE

	SELECT @TotalRows = COUNT(1)
	FROM #tblChangeShiftDetail WITH (NOLOCK)

	IF @TypeId = @ChangeShift
	BEGIN
		EXEC dbo.EmployeeCalendar_Insert @empid = @empid
			,@fromdate = @FromDate
			,@todate = @ToDate
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END
	ELSE
	BEGIN
		WHILE @RowIndex <= @TotalRows
		BEGIN
			SELECT @tmpOnDate = OnDate
				,@tmpToDate = ToDate
			FROM #tblChangeShiftDetail WITH (NOLOCK)
			WHERE RowIndex = @RowIndex

			EXEC dbo.EmployeeCalendar_Insert @empid = @empid
				,@fromdate = @tmpOnDate
				,@todate = @tmpOnDate
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT

			EXEC dbo.EmployeeCalendar_Insert @empid = @empid
				,@fromdate = @tmpToDate
				,@todate = @tmpToDate
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT

			SET @RowIndex = @RowIndex + 1
		END
	END

	IF @RoleId = @VerifierRoleId
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @VerifiedStatusId
			,VerifiedStatus = @VerifiedStatusId
			--,VerifierId = @ActorId
			,VerifiedDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId
	END
	ELSE IF @RoleId = @ApproverRoleId
	BEGIN
		IF ISNULL(@DisciplineXml, '') <> ''
		BEGIN
			EXEC dbo.ChangeShiftRequest_UpdateDiscipline @RequestId = @RequestId
				,@ActorId = @ActorId
				,@RequestStatusId = @ApprovedStatusId
				,@DisciplineXml = @DisciplineXml
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT

			EXEC dbo.DisciplineIgnoreDetail_Update @ActorId = @ActorId
				,@DisciplineIgnoreXml = @DisciplineXml
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END

		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @ApprovedStatusId
			,ApprovedStatus = @VerifiedStatusId
			,ApproverComment = @Comment
			--,ApproverId = @ActorId
			,ApprovedDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId

		IF @TypeId = @ChangeShift
		BEGIN
			UPDATE empca
			SET empca.IsOffDay = 1
				,empca.ChangeShiftId = csdt.FromShift
				,empca.ShiftId = NULL
				,empca.ModifiedBy = @ActorId
				,empca.ModifiedDate = @ProcessedDate
				,empca.IsPublic = 1
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
				,empca.IsPublic = 1
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
				,empca.IsPublic = 1
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
				,empca.ModifiedBy = @ActorId
				,empca.ModifiedDate = @ProcessedDate
				,empca.IsPublic = 1
				,empca.ShiftId = CASE WHEN csdt.ToShift > 0 THEN csdt.ToShift ELSE empca.ShiftId END
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
				,empca.IsPublic = 1
			FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
				INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON empca.WorkDate = csdt.ToDate
				AND empca.EmpId = csdt.EmpId
				AND csdt.RequestId = @RequestId
			WHERE empca.EmpId = @EmpId
				AND empca.IsOffDay = 0
		END

		SET @RowIndex = 1

		WHILE @RowIndex <= @TotalRows
		BEGIN
			SELECT @tmpOnDate = OnDate
				,@tmpToDate = ToDate
			FROM #tblChangeShiftDetail WITH (NOLOCK)
			WHERE RowIndex = @RowIndex

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
				,@tmpOnDate
				,@tmpOnDate
				,1

			IF @TypeId = @MoveOffDay
			BEGIN
				EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
					,@tmpToDate
					,@tmpToDate
					,1
			END

			SET @RowIndex = @RowIndex + 1
		END
	END
	ELSE IF @RoleId = @HRRoleId
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @ProcessedStatusId
			,HRStatus = @VerifiedStatusId
			,HRId = @ActorId
			,HRDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId
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

	EXEC dbo.ScheduleArrangement_UpdateOffDayReplacement @CompanyId = @CompanyId
        ,@ActorId = @ActorId
		,@FromDate = @FromDate
		,@ToDate = @ToDate
		,@EmployeeIds = @EmpId
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	EXEC dbo.ChangeShiftRequest_WriteLog @RequestId = @RequestId
		,@Comment = @Comment

	DROP TABLE #tblChangeShiftDetail
END