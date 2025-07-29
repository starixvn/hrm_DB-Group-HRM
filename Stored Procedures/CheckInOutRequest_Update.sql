/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_Update]
(
    @RequestId BIGINT
    ,@CompanyId SMALLINT = 0
    ,@EmpId INT
    ,@RequestType TINYINT
    ,@Remark NVARCHAR(2000) = NULL
    ,@OnDate DATE
    ,@RequestTime DATETIME
    ,@ReasonId TINYINT
    ,@VerifierId INT = NULL
    ,@ApproverId INT = NULL
    ,@ModifiedBy INT = NULL
    ,@RefNo NVARCHAR(200) = ''
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Quinn.Vo@20190624
    Task: Update a check in/out request
    DB: bodb_HRM

    Revisions:
        20250722@Tim: auto approve request [Redmine: #233324]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ModifiedDate DATETIME = GETDATE()
		,@AutoApproveRequest BIT
		-- action type
		,@VerifyRequest TINYINT = 2
		,@ApproveRequest TINYINT = 3
		,@OnBehalfRequest TINYINT = 5
		-- request type
		,@CheckInRequestTypeId TINYINT = 1
		,@CheckOutRequestTypeId TINYINT = 2
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
				INNER JOIN dbo.CheckInOutRequest AS cio WITH (NOLOCK) ON wk.RequestId = cio.RequestId
				AND cio.OnDate = @OnDate
			WHERE wk.empid = @empid
				AND wk.RequestType = @RequestType
				AND wk.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
				AND wk.RequestId <> @RequestId
			)
	BEGIN
		SET @ErrCode = 101
		SET @ErrMsg = 'There is another request in the same date.'

		RETURN;
	END

	SELECT @AutoApproveRequest = AutoApproveRequest
	FROM dbo.CompanyEmployee WITH (NOLOCK)
	WHERE EmpId = @EmpId
        AND CompanyId = @CompanyId

    SET @AutoApproveRequest = ISNULL(@AutoApproveRequest, 0)

	IF (
			@ApproverId IS NULL
			OR @VerifierId IS NULL
			)
		AND @AutoApproveRequest = 0
	BEGIN
		SET @ErrCode = 102
		SET @ErrMsg = 'Verifier, Approver is required.'

		RETURN;
	END

	IF @EmpId <> @ModifiedBy
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor WITH (NOLOCK)
				WHERE OwnerId = @EmpId
					AND EmpId = @ModifiedBy
					AND ActionType = @OnBehalfRequest
					AND RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId)
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
				WHERE gs.OwnerId = @ModifiedBy
					AND emp.EmpId = @EmpId
					AND gs.ActionType = @OnBehalfRequest
					AND gs.RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId)
					AND ISNULL(gs.IsDeleted, 0) = 0
				)
		BEGIN
			SET @ErrCode = 103
			SET @ErrMsg = 'You do not have permision.'

			RETURN;
		END
	END

	IF @AutoApproveRequest = 0
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor WITH (NOLOCK)
				WHERE OwnerId = @VerifierId
					AND EmpId = @EmpId
					AND ActionType = @VerifyRequest
					AND RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId)
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
				WHERE emp.EmpId = @EmpId
					AND gs.OwnerId = @VerifierId
					AND ISNULL(gs.IsDeleted, 0) = 0
					AND gs.RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId)
					AND gs.ActionType = @VerifyRequest
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
					AND ISNULL(IsDeleted, 0) = 0
					AND RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId)
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
				WHERE emp.EmpId = @EmpId
					AND gs.OwnerId = @ApproverId
					AND ISNULL(gs.IsDeleted, 0) = 0
					AND gs.RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId)
					AND gs.ActionType = @ApproveRequest
				)
		BEGIN
			SET @ErrCode = 105
			SET @ErrMsg = 'Approver is invalid.'

			RETURN;
		END
	END

	UPDATE WorkingTimeRequest WITH (ROWLOCK)
	SET Remark = @Remark
		,CurrentStatus = @PendingStatusId
		,VerifierId = @VerifierId
		,VerifiedStatus = @PendingStatusId
		,ApproverId = CASE WHEN @AutoApproveRequest = 1 AND @ApproverId IS NULL THEN -1 ELSE @ApproverId END
		,ApprovedStatus = @PendingStatusId
		,ModifiedBy = @ModifiedBy
		,ModifiedDate = @ModifiedDate
	WHERE RequestId = @RequestId

	UPDATE dbo.CheckInOutRequest WITH (ROWLOCK)
	SET EmpId = @EmpId
		,OnDate = @OnDate
		,RequestTime = @RequestTime
		,RefNo = @RefNo
		,ReasonId = @ReasonId
	WHERE RequestId = @RequestId

	EXEC dbo.CheckInOutRequest_WriteLog @RequestId = @RequestId

	IF @ApproverId IS NULL
		AND @VerifierId IS NULL
		AND @AutoApproveRequest = 1
	BEGIN
		EXEC dbo.CheckInOutRequest_Approve @RequestId = @RequestId
			,@ActorId = -1
			,@RoleId = 3
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END
END