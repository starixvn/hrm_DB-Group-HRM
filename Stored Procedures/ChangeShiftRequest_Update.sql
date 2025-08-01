/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_Update]
(
    @RequestId BIGINT
    ,@CompanyId SMALLINT
    ,@EmpId INT
    ,@TypeId TINYINT
    ,@Remark NVARCHAR(2000)
    ,@FromDate DATE
    ,@ToDate DATE
    ,@ActorId INT
    ,@VerifierId INT = NULL
    ,@ApproverId INT = NULL
    ,@DetailXml NVARCHAR(MAX)
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tim.Trinh@2019-09-20
    Task: update request
    DB: bodb_HRM

    Revisions:
        20250722@Tim: auto approve request [Redmine: #233324]
    Param's Explanation:
	    @DetailXml: '<ROOT><Row OnDate={0} FromShiftId={1} ToShiftId={2} Remark={3} ToDate={4} /></ROOT>'
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ModifiedDate DATETIME = GETDATE()
		,@RequestType TINYINT = 5
		,@OldFromDate DATE
		,@OldToDate DATE
		-- action type
		,@VerifyRequest TINYINT = 2
		,@ApproveRequest TINYINT = 3
		,@OnBehalfRequest TINYINT = 5
		,@AutoApproveRequest BIT
		-- change shift type
		,@ChangeShift TINYINT = 1
		,@MoveOffDay TINYINT = 2
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7

	CREATE TABLE #tblChangeShiftDetail (
		OnDate DATE
		,FromShiftId INT
		,ToShiftId INT
		,Remark NVARCHAR(2000)
		,ToDate DATE NULL
		)

	IF EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest r WITH (NOLOCK)
			WHERE r.RequestId = @RequestId
				AND r.CurrentStatus <> @PendingStatusId
			)
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'Status is not pending, you can not edit this request.'

		RETURN
	END

	BEGIN TRY
		DECLARE @DocHandler INT

		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@DetailXml

		INSERT INTO #tblChangeShiftDetail (
			OnDate
			,FromShiftId
			,ToShiftId
			,Remark
			,ToDate
			)
		SELECT OnDate
			,FromShiftId
			,ToShiftId
			,REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Remark, '&amp;', '&'), '&#39;', ''''), '&lt;', '<'), '&gt;', '>'), '&quot;', '"')
			,CASE 
				WHEN ISDATE(ToDate) = 1 THEN ToDate
				ELSE NULL
				END
		FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (OnDate DATE, FromShiftId INT, ToShiftId INT, Remark NVARCHAR(2000), ToDate VARCHAR(15)) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 101
			,@ErrMsg = N'Change shift detail is invalid.'

		RETURN
	END CATCH

	IF @TypeId = @ChangeShift
		AND DATEDIFF(dd, @FromDate, @ToDate) > 14
	BEGIN
		SET @ErrCode = 102
		SET @ErrMsg = 'Change shift is limited to 2 weeks.'

		RETURN
	END

	SELECT @AutoApproveRequest = AutoApproveRequest
	FROM dbo.CompanyEmployee WITH (NOLOCK)
	WHERE EmpId = @EmpId
        AND CompanyId = @CompanyId

    SET @AutoApproveRequest = ISNULL(@AutoApproveRequest, 0)

	IF (@ApproverId IS NULL OR @VerifierId IS NULL)
		AND @AutoApproveRequest = 0
	BEGIN
		SET @ErrCode = 103
		SET @ErrMsg = 'Verifier, Approver is required.'

		RETURN
	END

	IF @EmpId <> @ActorId
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor WITH (NOLOCK)
				WHERE OwnerId = @EmpId
					AND EmpId = @ActorId
					AND RequestType = @RequestType
					AND ActionType = @OnBehalfRequest
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @ActorId
					AND gs.RequestType = @RequestType
					AND gs.ActionType = @OnBehalfRequest
					AND ISNULL(gs.IsDeleted, 0) = 0
				)
		BEGIN
			SET @ErrCode = 104
			SET @ErrMsg = 'You do not have permision.'

			RETURN
		END
	END

	IF @AutoApproveRequest = 0
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor WITH (NOLOCK)
				WHERE OwnerId = @VerifierId
					AND EmpId = @EmpId
					AND RequestType = @RequestType
					AND ActionType = @VerifyRequest
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @VerifierId
					AND gs.RequestType = @RequestType
					AND gs.ActionType = @VerifyRequest
					AND ISNULL(gs.IsDeleted, 0) = 0
				)
		BEGIN
			SET @ErrCode = 105
			SET @ErrMsg = 'Verifier is invalid.'

			RETURN
		END

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor WITH (NOLOCK)
				WHERE OwnerId = @ApproverId
					AND EmpId = @EmpId
					AND RequestType = @RequestType
					AND ActionType = @ApproveRequest
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @ApproverId
					AND gs.RequestType = @RequestType
					AND gs.ActionType = @ApproveRequest
					AND ISNULL(gs.IsDeleted, 0) = 0
				)
		BEGIN
			SET @ErrCode = 106
			SET @ErrMsg = 'Approver is invalid.'

			RETURN
		END
	END

	-- check if there is another request in the same date
	IF @TypeId = @ChangeShift
		AND (
			EXISTS (
				SELECT 1
				FROM dbo.WorkingTimeRequest AS wk WITH (NOLOCK)
					INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wk.RequestId = cs.RequestId
					AND cs.TypeId = @ChangeShift
					AND cs.EmpId = @EmpId
					AND cs.RequestId <> @RequestId
				WHERE wk.RequestType = @RequestType
					AND wk.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
					AND (
						@FromDate BETWEEN cs.FromDate AND cs.ToDate
						OR @ToDate BETWEEN cs.FromDate AND cs.ToDate
						OR cs.FromDate BETWEEN @FromDate AND @ToDate
						OR cs.ToDate BETWEEN @FromDate AND @ToDate
						)
				)
			OR (
				EXISTS (
					SELECT 1
					FROM dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK)
						INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON cs.TypeId = @MoveOffDay
						AND csdt.RequestId = cs.RequestId
						AND cs.EmpId = @EmpId
						AND cs.RequestId <> @RequestId
						INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON cs.RequestId = wk.RequestId
						AND wk.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
					WHERE csdt.OnDate BETWEEN @FromDate AND @ToDate
						OR csdt.ToDate BETWEEN @FromDate AND @ToDate
					)
				)
			)
	BEGIN
		SET @ErrCode = 107
		SET @ErrMsg = 'There is another request in the same date.'

		RETURN
	END

	IF @TypeId = @MoveOffDay
		AND (
			EXISTS (
				SELECT 1
				FROM #tblChangeShiftDetail AS csd
					INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON cs.TypeId = @ChangeShift
					AND cs.EmpId = @EmpId
					AND cs.RequestId <> @RequestId
					AND csd.OnDate BETWEEN cs.FromDate AND cs.ToDate
					INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON cs.RequestId = wk.RequestId
					AND wk.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
				)
			OR (
				EXISTS (
					SELECT 1
					FROM #tblChangeShiftDetail AS csd
						INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON csdt.EmpId = @EmpId
						AND (
							csd.OnDate = csdt.OnDate
							OR csd.OnDate = csdt.ToDate
							OR csd.ToDate = csdt.OnDate
							OR csd.ToDate = csdt.ToDate
							)
						INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON cs.TypeId = @MoveOffDay
						AND csdt.RequestId = cs.RequestId
						AND cs.RequestId <> @RequestId
						INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON cs.RequestId = wk.RequestId
						AND wk.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
					)
				)
			)
	BEGIN
		SET @ErrCode = 107
		SET @ErrMsg = 'There is another request in the same date.'

		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.ChangeShiftRequest WITH (NOLOCK)
			WHERE TypeId = @ChangeShift
			)
	BEGIN
		SELECT @OldFromDate = MIN(OnDate)
			,@OldToDate = MAX(OnDate)
		FROM dbo.ChangeShiftRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId
	END
	ELSE
	BEGIN
		SELECT @OldFromDate = MIN(OnDate)
			,@OldToDate = MAX(ToDate)
		FROM dbo.ChangeShiftRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId
	END

	UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
	SET Remark = @Remark
		,CurrentStatus = @PendingStatusId
		,VerifierId = @VerifierId
		,VerifiedStatus = @PendingStatusId
		,ApproverId = CASE WHEN @AutoApproveRequest = 1 AND @ApproverId IS NULL THEN -1 ELSE @ApproverId END
		,[ApprovedStatus] = @PendingStatusId
		,ModifiedBy = @ActorId
		,ModifiedDate = @ModifiedDate
	WHERE RequestId = @RequestId

	UPDATE dbo.ChangeShiftRequest WITH (ROWLOCK, UPDLOCK)
	SET TypeId = @TypeId
		,FromDate = @FromDate
		,ToDate = @ToDate
	WHERE RequestId = @RequestId

	DELETE dbo.ChangeShiftRequestDetail
	WHERE RequestId = @RequestId

	INSERT INTO dbo.ChangeShiftRequestDetail (EmpId, OnDate, RequestId, FromShift, ToShift, Remark, ToDate)
	SELECT @EmpId, OnDate, @RequestId, FromShiftId, ToShiftId, Remark, ToDate
	FROM #tblChangeShiftDetail

	EXEC dbo.ChangeShiftRequest_WriteLog @RequestId = @RequestId

	IF @ApproverId IS NULL
		AND @VerifierId IS NULL
		AND @AutoApproveRequest = 1
	BEGIN
		EXEC dbo.ChangeShiftRequest_Approve @RequestId = @RequestId
			,@RoleId = 3 -- approver
			,@ActorId = -1
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
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

	IF @OldFromDate <> @FromDate
		OR @OldToDate <> @ToDate
	BEGIN
		EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
			,@fromDate = @OldFromDate
			,@toDate = @OldToDate
			,@empIds = @EmpId
			,@isUpdateRequestData = 1
	END

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @FromDate
		,@toDate = @ToDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1

	DROP TABLE #tblChangeShiftDetail
END