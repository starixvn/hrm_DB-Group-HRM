/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_Insert]
(
    @EmpId INT
    ,@CompanyId SMALLINT
    ,@Remark NVARCHAR(2000) = NULL
    ,@OnDate DATE
    ,@KeepInViewType TINYINT = NULL
    ,@IsHalfDay BIT = NULL
    ,@FromTime DATETIME = NULL
    ,@ToTime DATETIME = NULL
    ,@CreatedBy INT
    ,@VerifierId INT = NULL
    ,@ApproverId INT = NULL
    ,@RequestId BIGINT = 0 OUTPUT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Quinn.Vo@20190522
    Task: insert keep inview request
    DB: bodb_HRM

    Revisions:
        20250722@Tim: auto approve request [Redmine: #233324]
        20250813@Jay: change db structure [Redmine: #235678]
		20251111@Lilac: remove on behalf request [Redmine: #243412]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @CreatedDate DATETIME = GETDATE()
		,@KeepInViewRequestTypeId TINYINT = 7
		,@RefNo NVARCHAR(200) = ''
		,@AutoApproveRequest BIT
		-- action type
		,@VerifyRequest TINYINT = 2
		,@ApproveRequest TINYINT = 3
		-- keep in view type
		,@KeepInViewByDay TINYINT = 1
		,@KeepInViewByHour TINYINT = 2
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6
		-- day off
		,@SumDayOff INT;
	SET DATEFIRST 1;
	DECLARE @WeekStartDate DATE = DATEADD(DAY, 1 - DATEPART(WEEKDAY, @OnDate), @OnDate);
	DECLARE @WeekEndDate DATE = DATEADD(DAY, 6, @WeekStartDate);

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

	IF  EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE WorkDate = CAST(@OnDate AS DATETIME)
				AND EmpId = @EmpId
				AND ShiftId IS NULL
				AND (
					IsHoliday = 1
					OR IsOffDay = 1
					)
			)
	BEGIN
		SET @ErrCode = 101
		SET @ErrMsg = 'Can not select off day or holiday ' + CONVERT(NVARCHAR(100), @OnDate, 106)

		RETURN
	END

	IF  EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE WorkDate = CAST(@OnDate AS DATETIME)
				AND EmpId = @EmpId
				AND ShiftId IS NULL
			)
	BEGIN
		SET @ErrCode = 108
		SET @ErrMsg = 'Can not select non-shift working day ' + CONVERT(NVARCHAR(100), @OnDate, 106)

		RETURN
	END

	IF @KeepInViewType = @KeepInViewByDay
        AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE WorkDate = CAST(@OnDate AS DATETIME)
				AND EmpId = @EmpId
				AND IsHoliday = 1
			)
	BEGIN
		SELECT @SumDayOff = COUNT(*)
		FROM (
			SELECT DISTINCT WorkDate -- Count the number of off days (IsOffDay = 1) in the same week as @OnDate
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE WorkDate BETWEEN CAST(@WeekStartDate AS DATETIME) AND CAST(@WeekEndDate AS DATETIME)
				AND EmpId = @EmpId
				AND IsOffDay = 1
				AND WorkDate <> CAST(@OnDate AS DATETIME)
				AND IsHoliday = 0 -- not count PH

			UNION
			SELECT DISTINCT OnDate -- Count the number of pending working time requests in the same week
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
			    INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON r.RequestId = kiv.RequestId
			    LEFT JOIN dbo.EmployeeCalendar c WITH (NOLOCK) ON c.WorkDate = kiv.OnDate AND c.EmpId = r.EmpId
			    LEFT JOIN dbo.tmpEmployeeCalendar ctmp WITH (NOLOCK) ON ctmp.WorkDate = kiv.OnDate AND ctmp.EmpId = r.EmpId
			WHERE r.EmpId = @EmpId 
				AND r.CurrentStatus = @PendingStatusId
				AND kiv.OnDate BETWEEN @WeekStartDate AND @WeekEndDate
				AND kiv.OnDate <> @OnDate
				AND (c.IsHoliday = 0 OR ctmp.IsHoliday = 0) -- not count PH
		) AS CombinedDates;

		DECLARE @MaxOffdaySetting INT = (
            SELECT TOP(1) s.OffDaysbyWeek
            FROM dbo.EmployeeSummary AS s WITH (NOLOCK)
            WHERE s.EmpId = @EmpId
            )
		
		IF @SumDayOff >= @MaxOffdaySetting
			BEGIN		
				SET @ErrCode = 109
				SET @ErrMsg = 'The number of days off taken by the employee this week exceeds the setting limit'

				RETURN
			END
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
		SET @ErrCode = 104
		SET @ErrMsg = 'Verifier, Approver is required.'

		RETURN;
	END

	IF @AutoApproveRequest = 0
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
					INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON gs.GroupId = ce.GroupId
						AND ce.EmpId = @EmpId
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
					INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON gs.GroupId = ce.GroupId
						AND ce.EmpId = @EmpId
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

	INSERT INTO dbo.WorkingTimeRequest (EmpId, RequestType, Remark, CurrentStatus, VerifierId, ApproverId, VerifiedStatus, ApprovedStatus, HRStatus, CreatedDate, CreatedBy)
	VALUES (@EmpId, @KeepInViewRequestTypeId, @Remark, @PendingStatusId, @VerifierId,
		CASE WHEN @AutoApproveRequest = 1 AND @ApproverId IS NULL THEN -1 ELSE @ApproverId END,
		@PendingStatusId, @PendingStatusId, @PendingStatusId, @CreatedDate, @CreatedBy)

	SELECT @RequestId = CAST(SCOPE_IDENTITY() AS BIGINT)

	INSERT INTO dbo.KeepInViewRequest (RequestId, EmpId, OnDate, KeepInViewType, IsHalfDay, FromTime, ToTime, RefNo)
	VALUES (@RequestId, @EmpId, @OnDate, @KeepInViewType, @IsHalfDay, @FromTime, @ToTime, @RefNo)

	EXEC dbo.KeepInViewRequest_WriteLog @RequestId = @RequestId

	IF @ApproverId IS NULL
		AND @VerifierId IS NULL
		AND @AutoApproveRequest = 1
	BEGIN
		EXEC dbo.KeepInViewRequest_Approve @RequestId = @RequestId
			,@ActorId = -1
			,@RoleId = 3
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @OnDate
		,@toDate = @OnDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1
END