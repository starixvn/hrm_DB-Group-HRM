/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_Insert] @EmpId INT
	,@Remark NVARCHAR(2000) = NULL
	,@OnDate DATE
	,@KeepInViewType TINYINT = NULL
	,@IsHalfDay BIT = NULL
	,@FromTime DATETIME = NULL
	,@ToTime DATETIME = NULL
	,@CreatedBy INT
	,@VerifierId INT = NULL
	,@ApproverId INT = NULL
	,@ShiftId INT = NULL
	,@RequestId BIGINT = 0 OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190522
Task: insert keep inview request
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @CreatedDate DATETIME = GETDATE()
		,@KeepInViewRequestTypeId TINYINT = 7
		,@RefNo NVARCHAR(200) = ''
		,@IsTopManager BIT
		-- action type
		,@VerifyRequest TINYINT = 2
		,@ApproveRequest TINYINT = 3
		,@OnBehalfRequest TINYINT = 5
		-- keep in view type
		,@KeepInViewByDay TINYINT = 1
		,@KeepInViewByHour TINYINT = 2
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6

	IF @KeepInViewType = @KeepInViewByDay
		AND @IsHalfDay = 0
	BEGIN
		SELECT @FromTime = NULL
			,@ToTime = NULL
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
				INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON r.RequestId = kiv.RequestId
				AND kiv.OnDate = @OnDate
			WHERE r.empid = @empid
				AND r.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
			)
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'There is another request in the same date.'

		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.OTDailyRequest WITH (NOLOCK)
			WHERE OvertimeDate = @OnDate
				AND EmpId = @EmpId
				AND (
					NormalHours > 0
					OR OffHours > 0
					OR PublicHours > 0
					OR SpecialHours > 0
					)
			)
	BEGIN
		SET @ErrCode = 102
		SET @ErrMsg = 'You have requested overtime on ' + CONVERT(NVARCHAR(100), @OnDate, 106) + '.'

		RETURN
	END

	IF @KeepInViewType = @KeepInViewByDay
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE WorkDate = @OnDate
				AND EmpId = @EmpId
				AND (
					IsHoliday = 1
					OR IsOffDay = 1
					)
			)
	BEGIN
		SET @ErrCode = 101
		SET @ErrMsg = 'Not off day or holiday ' + CONVERT(NVARCHAR(100), @OnDate, 106)

		RETURN
	END

	IF @EmpId <> @CreatedBy
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor WITH (NOLOCK)
				WHERE OwnerId = @EmpId
					AND EmpId = @CreatedBy
					AND ActionType = @OnBehalfRequest
					AND RequestType = @KeepInViewRequestTypeId
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @CreatedBy
					AND gs.ActionType = @OnBehalfRequest
					AND gs.RequestType = @KeepInViewRequestTypeId
					AND ISNULL(gs.IsDeleted, 0) = 0
				)
		BEGIN
			SET @ErrCode = 103
			SET @ErrMsg = 'You do not have permision.'

			RETURN;
		END
	END

	SELECT @IsTopManager = IsTopManager
	FROM dbo.EmployeeSummary WITH (NOLOCK)
	WHERE EmpId = @EmpId

	IF (
			@ApproverId IS NULL
			OR @VerifierId IS NULL
			)
		AND @IsTopManager = 0
	BEGIN
		SET @ErrCode = 104
		SET @ErrMsg = 'Verifier, Approver is required.'

		RETURN;
	END

	IF @IsTopManager = 0
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor WITH (NOLOCK)
				WHERE OwnerId = @VerifierId
					AND EmpId = @EmpId
					AND ActionType = @VerifyRequest
					AND RequestType = @KeepInViewRequestTypeId
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @VerifierId
					AND ISNULL(gs.IsDeleted, 0) = 0
					AND gs.RequestType = @KeepInViewRequestTypeId
					AND gs.ActionType = @VerifyRequest
				)
		BEGIN
			SET @ErrCode = 105
			SET @ErrMsg = 'Verifier is invalid.'

			RETURN;
		END

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor WITH (NOLOCK)
				WHERE OwnerId = @ApproverId
					AND EmpId = @EmpId
					AND ActionType = @ApproveRequest
					AND RequestType = @KeepInViewRequestTypeId
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @ApproverId
					AND ISNULL(gs.IsDeleted, 0) = 0
					AND gs.RequestType = @KeepInViewRequestTypeId
					AND gs.ActionType = @ApproveRequest
				)
		BEGIN
			SET @ErrCode = 106
			SET @ErrMsg = 'Approver is invalid.'

			RETURN;
		END
	END

	IF DATEDIFF(MI, @FromTime, @ToTime) < 60
	BEGIN
		SET @ErrCode = 107
		SET @ErrMsg = 'Minimum Compensation Leave is 60 minutes.'

		RETURN;
	END

	EXEC dbo.WorkingTimeRequest_GetNewRefNoByRequestType @RefNo = @RefNo OUTPUT
		,@RequestType = @KeepInViewRequestTypeId

	BEGIN TRY
		INSERT INTO dbo.WorkingTimeRequest (
			EmpId
			,RequestType
			,Remark
			,CurrentStatus
			,VerifierId
			,ApproverId
			,VerifiedStatus
			,ApprovedStatus
			,HRStatus
			,CreatedDate
			,CreatedBy
			)
		VALUES (
			@EmpId
			,@KeepInViewRequestTypeId
			,@Remark
			,CASE 
				WHEN @IsTopManager = 1
					AND @VerifierId IS NOT NULL THEN @PendingStatusId
				WHEN @IsTopManager = 1
					AND @ApproverId IS NOT NULL THEN @VerifiedStatusId
				WHEN @IsTopManager = 1
					AND @ApproverId IS NULL THEN @ApprovedStatusId
				ELSE @PendingStatusId
				END
			,@VerifierId
			,@ApproverId
			,CASE 
				WHEN @IsTopManager = 1
					AND @VerifierId IS NULL THEN @VerifiedStatusId
				ELSE @PendingStatusId
				END
			,CASE 
				WHEN @IsTopManager = 1
					AND @ApproverId IS NULL THEN @VerifiedStatusId
				ELSE @PendingStatusId
				END
			,@PendingStatusId
			,@CreatedDate
			,@CreatedBy
			)

		SELECT @RequestId = cast(SCOPE_IDENTITY() AS BIGINT)

		INSERT INTO dbo.KeepInViewRequest (
			RequestId
			,EmpId
			,OnDate
			,KeepInViewType
			,IsHalfDay
			,FromTime
			,ToTime
			,RefNo
			,ShiftId
			)
		VALUES (
			@RequestId
			,@EmpId
			,@OnDate
			,@KeepInViewType
			,@IsHalfDay
			,@FromTime
			,@ToTime
			,@RefNo
			,@ShiftId
			)

		IF @ApproverId IS NULL
			AND @VerifierId IS NULL
			AND @IsTopManager = 1
		BEGIN
			EXEC dbo.KeepInViewRequest_Approve @RequestId = @RequestId
				,@ActorId = @EmpId
				,@RoleId = 3
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END

		EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
			,@fromDate = @OnDate
			,@toDate = @OnDate
			,@empIds = @EmpId
			,@isUpdateRequestData = 1

		EXEC dbo.KeepInViewRequest_WriteLog @RequestId = @RequestId
	END TRY

	BEGIN CATCH
		DELETE dbo.WorkingTimeRequest WITH (ROWLOCK)
		WHERE RequestId = @RequestId

		DELETE dbo.KeepInViewRequest WITH (ROWLOCK)
		WHERE RequestId = @RequestId

		DELETE dbo.KeepInViewRequestHistory WITH (ROWLOCK)
		WHERE RequestId = @RequestId

		SELECT @ErrCode = 108
			,@ErrMsg = N'Create unsuccessfully.'
	END CATCH
END
