/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_Insert] @EmpId INT
	,@OnDate DATE
	,@RequestType SMALLINT
	,@ReasonId TINYINT
	,@LateInMins INT = NULL
	,@EarlyOutMins INT = NULL
	,@Remark NVARCHAR(2000) = NULL
	,@CreatedBy INT = NULL
	,@VerifierId INT = NULL
	,@ApproverId INT = NULL
	,@RequestId BIGINT = 0 OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190625
Task: Create a late in/early out request
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @CreatedDate DATETIME = GETDATE()
		,@IsTopManager BIT
		-- leave type
		,@AnnualLeaveTypeId TINYINT = 2
		,@UnpaidLeaveTypeId TINYINT = 25
		-- action type
		,@VerifyRequest TINYINT = 2
		,@ApproveRequest TINYINT = 3
		,@OnBehalfRequest TINYINT = 5
		-- request type
		,@LateInRequestTypeId TINYINT = 3
		,@EarlyOutRequestTypeId TINYINT = 4
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6

	IF EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest AS wk WITH (NOLOCK)
				INNER JOIN dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK) ON wk.RequestId = lieo.RequestId
				AND lieo.OnDate = @OnDate
			WHERE wk.EmpId = @EmpId
				AND wk.RequestType = @RequestType
				AND wk.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
			)
	BEGIN
		SET @ErrCode = 101
		SET @ErrMsg = 'There is another request in the same date.'

		RETURN;
	END

	IF @EmpId <> @CreatedBy
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS sp WITH (NOLOCK)
				WHERE sp.OwnerId = @EmpId
					AND sp.EmpId = @CreatedBy
					AND sp.ActionType = @OnBehalfRequest
					AND sp.RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
					AND ISNULL(sp.IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @CreatedBy
					AND gs.ActionType = @OnBehalfRequest
					AND gs.RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
					AND ISNULL(gs.IsDeleted, 0) = 0
				)
		BEGIN
			SET @ErrCode = 102
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
		SET @ErrCode = 103
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
					AND RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @VerifierId
					AND gs.RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
					AND gs.ActionType = @VerifyRequest
					AND ISNULL(gs.IsDeleted, 0) = 0
				)
		BEGIN
			SET @ErrCode = 104
			SET @ErrMsg = 'Verifier is invalid.'

			RETURN;
		END

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor WITH (NOLOCK)
				WHERE OwnerId = @ApproverId
					AND EmpId = @EmpId
					AND ActionType = @ApproveRequest
					AND RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @ApproverId
					AND gs.RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
					AND gs.ActionType = @ApproveRequest
					AND ISNULL(gs.IsDeleted, 0) = 0
				)
		BEGIN
			SET @ErrCode = 105
			SET @ErrMsg = 'Approver is invalid.'

			RETURN;
		END
	END

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @OnDate
		,@toDate = @OnDate
		,@empIds = @EmpId

	IF EXISTS (
			SELECT 1
			FROM dbo.tmpEmployeeCalendar WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND WorkDate = @OnDate
				AND LeaveTypeId IN (@AnnualLeaveTypeId, @UnpaidLeaveTypeId)
				AND IsLeaveDay = 1
				AND LeaveDay = 0.5
			)
		AND (
			@LateInMins > 30
			OR @EarlyOutMins > 30
			)
	BEGIN
		SET @ErrCode = 106
		SET @ErrMsg = 'You can not request over 30 minutes on half day leave.'

		RETURN
	END

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
		,@RequestType
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

	INSERT INTO dbo.LateInEarlyOutRequest (
		RequestId
		,EmpId
		,OnDate
		,LateInMins
		,EarlyOutMins
		,ReasonId
		)
	VALUES (
		@RequestId
		,@EmpId
		,@OnDate
		,@LateInMins
		,@EarlyOutMins
		,@ReasonId
		)

	IF @ApproverId IS NULL
		AND @VerifierId IS NULL
		AND @IsTopManager = 1
	BEGIN
		EXEC dbo.LateInEarlyOutRequest_Approve @RequestId = @RequestId
			,@ActorId = @EmpId
			,@RoleId = 3
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END

	EXEC dbo.LateInEarlyOutRequest_WriteLog @RequestId = @RequestId
END



