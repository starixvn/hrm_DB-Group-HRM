/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_Approve] @RequestId BIGINT
	,@RoleId TINYINT
	,@DisciplineXml NVARCHAR(MAX) = NULL
	,@Comment NVARCHAR(500) = ''
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: Quinn.Vo@20150925
Task: approve leave request.
DB: HRM
Original:

Revisions:
	20250812@Mira: tranfer employee [Redmine: #235678]

Param's Explanation:
    @DisciplineXml:
        <Root>
            <Row WorkDate='' EmployeeId='' DisciplineTypeId='' IsIgnored='' IsConfirmed='' />
        </Root>
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @EmpId INT
        ,@TotalDay INT
		,@FromDate DATETIME
		,@ToDate DATETIME
		,@maxDate DATETIME
		,@minDate DATETIME
		,@ProcessedDate DATETIME = GETDATE()
		-- system role
		,@VerifierRoleId TINYINT = 2
		,@ApproverRoleId TINYINT = 3
		,@HRRoleId TINYINT = 6
		-- request status
		,@VerifiedStatusId TINYINT = 2
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6
		,@CompanyId SMALLINT

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.WorkingTimeRequest AS wk WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON wk.EmpId = ce.EmpId
	WHERE wk.RequestId = @RequestId


	SELECT @EmpId = l.EmpId
		,@FromDate = FromDate
		,@ToDate = ToDate
	FROM dbo.LeaveRequest AS l WITH (NOLOCK)
	WHERE RequestId = @RequestId

	SELECT @maxDate = MAX(WorkDate)
		,@minDate = MIN(WorkDate)
	FROM dbo.EmployeeCalendar WITH (NOLOCK)
	WHERE EmpId = @empid
		AND WorkDate BETWEEN @fromdate
			AND @todate

	IF @minDate IS NULL
		OR @maxDate IS NULL
		OR @fromdate <> @minDate
		OR @todate <> @maxDate
	BEGIN
		EXEC dbo.EmployeeCalendar_Insert @empid = @empid
			,@fromdate = @FromDate
			,@todate = @todate
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END

	DECLARE @TotalDays_tmp NUMERIC(5, 1)
		,@TotalDays_tmpbal NUMERIC(5, 1)
		,@isRquestDetail BIT = 1

	IF EXISTS (
			SELECT 1
			FROM dbo.LeaveRequestDetail WITH (NOLOCK)
			WHERE RequestId = @RequestId
			)
	BEGIN
		SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay
					WHEN 1 THEN 0.5
					ELSE 1
					END)
		FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
			INNER JOIN dbo.LeaveRequestDetail AS lrd WITH (NOLOCK) ON lrd.OnDate = empca.WorkDate
			AND lrd.EmpId = empca.EmpId
			AND lrd.RequestId = @RequestId
			AND lrd.WorkType = 2
			INNER JOIN dbo.LeaveType AS ltype WITH (NOLOCK) ON lrd.LeaveType = ltype.LeaveTypeId
            AND ltype.CompanyId = @CompanyId
			AND ltype.IsALDeduction = 1
		WHERE empca.IsHoliday = 0
			AND empca.IsOffDay = 0
	END
	ELSE
	BEGIN
		SET @isRquestDetail = 0

		SELECT @TotalDays_tmp = SUM(1)
		FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
			INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON lr.RequestId = @RequestId
			AND lr.EmpId = empca.EmpId
			AND empca.WorkDate BETWEEN CONVERT(SMALLDATETIME, CONVERT(NVARCHAR(20), lr.FromDate, 111))
				AND CONVERT(SMALLDATETIME, CONVERT(NVARCHAR(20), lr.ToDate, 111))
			INNER JOIN dbo.LeaveType AS ltype WITH (NOLOCK) ON lr.LeaveType = ltype.LeaveTypeId
            AND ltype.CompanyId = @CompanyId
			AND ltype.IsALDeduction = 1
		WHERE empca.IsHoliday = 0
			AND empca.IsOffDay = 0
	END

	SET @TotalDays_tmp = ISNULL(@TotalDays_tmp, 0)

	SELECT @TotalDays_tmpbal = SUM(TotalDays)
	FROM dbo.tmpLeaveBalance WITH (NOLOCK)
	WHERE RequestId = @RequestId

	IF (
			@TotalDays_tmp <> @TotalDays_tmpbal
			AND @isRquestDetail = 1
			)
		OR (
			@isRquestDetail = 0
			AND @TotalDays_tmp <> @TotalDays_tmpbal
			AND @TotalDays_tmpbal <> 0.5
			)
	BEGIN
		SET @ErrCode = 103
		SET @ErrMsg = 'Could not approved this request because this employee''s calendar have been changed.'

		RETURN
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
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @ApprovedStatusId
			,ApprovedStatus = @VerifiedStatusId
			,ApproverComment = @Comment
			--,ApproverId = @ActorId
			,ApprovedDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId

		EXEC dbo.LeaveRequest_Approve_UpdateCalendar @RequestId
			,@EmpId
			,@ActorId

		EXEC dbo.LeaveRequest_EmployeeCalendar_UpdateOffDay @RequestId

		IF ISNULL(@DisciplineXml, '') <> ''
		BEGIN
			EXEC dbo.LeaveRequest_UpdateDiscipline @RequestId = @RequestId
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

		EXEC dbo.AnnualLeave_InsertTransactionByRequestId @RequestId
			,@EmpId
			,@FromDate
			,@ToDate
			,@ActorId

		EXEC dbo.LeaveRequest_UpdateTmpAnnualLeaveTrans @Requestid = @Requestid
			,@EmpId = @EmpId
			,@Status = 1

		EXEC dbo.HospitalizationLeave_InsertTransactionByRequestId @RequestId
			,@EmpId
			,@FromDate
			,@ToDate
			,@ActorId

		EXEC dbo.LeaveRequest_UpdateTmpHospitalizationLeaveTrans @RequestId
			,@Status = 1

		EXEC dbo.SickLeave_InsertTransactionByRequestId @RequestId
			,@EmpId
			,@FromDate
			,@ToDate
			,@ActorId

		EXEC dbo.LeaveRequest_UpdateTmpSickLeaveTrans @RequestId
			,@Status = 1

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
			,@FromDate
			,@ToDate
			,1
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

	EXEC dbo.LeaveRequest_WriteLog @RequestId = @RequestId
		,@Comment = @Comment
END
