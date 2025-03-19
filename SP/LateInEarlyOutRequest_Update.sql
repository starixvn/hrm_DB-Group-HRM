USE [bodb_HRM]
GO
/****** Object:  StoredProcedure [dbo].[LateInEarlyOutRequest_Update]    Script Date: 3/19/2025 8:43:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_Update] @RequestId BIGINT
	,@EmpId INT
	,@OnDate DATE
	,@RequestType SMALLINT
	,@ReasonId TINYINT
	,@LateInMins INT = NULL
	,@EarlyOutMins INT = NULL
	,@Remark NVARCHAR(2000) = NULL
	,@ModifiedBy INT = NULL
	,@VerifierId INT = NULL
	,@ApproverId INT = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190625
Task: Edit a late in/early out request
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ModifiedDate DATETIME = GETDATE()
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
			FROM dbo.WorkingTimeRequest WITH (NOLOCK)
			WHERE RequestId = @RequestId
				AND CurrentStatus <> @PendingStatusId
			)
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'Status is not pending, you can not edit this request.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest AS wk WITH (NOLOCK)
				INNER JOIN dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK) ON wk.RequestId = lieo.RequestId
				AND lieo.RequestId <> @RequestId
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

	SELECT @IsTopManager = IsTopManager
	FROM dbo.EmployeeSummary WITH (NOLOCK)
	WHERE EmpId = @EmpId

	IF (
			@ApproverId IS NULL
			OR @VerifierId IS NULL
			)
		AND @IsTopManager = 0
	BEGIN
		SET @ErrCode = 102
		SET @ErrMsg = 'Verifier, Approver is required.'

		RETURN;
	END

	IF @EmpId <> @ModifiedBy
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS sp WITH (NOLOCK)
				WHERE sp.OwnerId = @EmpId
					AND sp.EmpId = @ModifiedBy
					AND sp.ActionType = @OnBehalfRequest
					AND sp.RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
					AND ISNULL(sp.IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @ModifiedBy
					AND gs.ActionType = @OnBehalfRequest
					AND gs.RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
					AND ISNULL(gs.IsDeleted, 0) = 0
				)
		BEGIN
			SET @ErrCode = 103
			SET @ErrMsg = 'You do not have permision.'

			RETURN;
		END
	END

	IF @IsTopManager = 0
	BEGIN
		IF NOT EXISTS (
				SELECT TOP 1 1
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

	UPDATE WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
	SET Remark = @Remark
		,CurrentStatus = CASE 
			WHEN @IsTopManager = 1
				AND @VerifierId IS NOT NULL THEN @PendingStatusId
			WHEN @IsTopManager = 1
				AND @ApproverId IS NOT NULL THEN @VerifiedStatusId
			WHEN @IsTopManager = 1
				AND @ApproverId IS NULL THEN @ApprovedStatusId
			ELSE @PendingStatusId
			END
		,VerifierId = @VerifierId
		,VerifiedStatus = CASE 
			WHEN @IsTopManager = 1
				AND @VerifierId IS NULL THEN @VerifiedStatusId
			ELSE @PendingStatusId
			END
		,ApproverId = @ApproverId
		,ApprovedStatus = CASE 
			WHEN @IsTopManager = 1
				AND @ApproverId IS NULL THEN @VerifiedStatusId
			ELSE @PendingStatusId
			END
		,ModifiedBy = @ModifiedBy
		,ModifiedDate = @ModifiedDate
	WHERE RequestId = @RequestId

	UPDATE dbo.LateInEarlyOutRequest WITH (ROWLOCK, UPDLOCK)
	SET EmpId = @EmpId
		,LateInMins = @LateInMins
		,EarlyOutMins = @EarlyOutMins
		,OnDate = @OnDate
		,ReasonId = @ReasonId
	WHERE RequestId = @RequestId

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



