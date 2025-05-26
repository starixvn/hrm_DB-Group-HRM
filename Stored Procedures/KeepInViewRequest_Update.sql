/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_Update] @RequestId BIGINT
	,@EmpId INT
	,@Remark NVARCHAR(2000) = NULL
	,@OnDate DATE
	,@KeepInViewType TINYINT
	,@IsHalfDay BIT = NULL
	,@FromTime DATETIME = NULL
	,@ToTime DATETIME = NULL
	,@ModifiedBy INT = NULL
	,@VerifierId INT = NULL
	,@ApproverId INT = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: 20190522@Quinn.Vo
Task: update keep in view request.
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ModifiedDate DATETIME = GETDATE()
		,@OldOnDate DATE
		,@KeepInViewRequestTypeId TINYINT = 7
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
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
				INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON r.RequestId = kiv.RequestId
				AND kiv.OnDate = @OnDate
			WHERE r.empid = @empid
				AND r.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
				AND r.RequestId <> @RequestId
			)
	BEGIN
		SET @ErrCode = 101
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
		SET @ErrCode = 103
		SET @ErrMsg = 'You have requested overtime on ' + CONVERT(NVARCHAR(100), @OnDate, 106) + '.'

		RETURN
	END

	IF  EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE WorkDate = @OnDate
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
			WHERE WorkDate = @OnDate
				AND EmpId = @EmpId
				AND ShiftId IS NULL
			)
	BEGIN
		SET @ErrCode = 108
		SET @ErrMsg = 'Can not select non-shift working day ' + CONVERT(NVARCHAR(100), @OnDate, 106)

		RETURN
	END

	IF @KeepInViewType = @KeepInViewByDay AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE WorkDate = @OnDate
				AND EmpId = @EmpId
				AND IsHoliday = 1
			)
	BEGIN
		SELECT @SumDayOff = COUNT(*)
		FROM (
			SELECT DISTINCT WorkDate -- Count the number of off days (IsOffDay = 1) in the same week as @OnDate
				FROM dbo.EmployeeCalendar WITH (NOLOCK)
				WHERE WorkDate BETWEEN @WeekStartDate AND @WeekEndDate
					AND EmpId = @EmpId
					AND IsOffDay = 1
					AND WorkDate <> @OnDate
					AND IsHoliday = 0 -- not count PH
			UNION
			SELECT DISTINCT OnDate -- Count the number of pending working time requests in the same week
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
			INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON r.RequestId = kiv.RequestId
			LEFT JOIN dbo.EmployeeCalendar c WITH (NOLOCK) ON c.WorkDate = kiv.OnDate AND c.EmpId = r.EmpId
			LEFT JOIN dbo.tmpEmployeeCalendar ctmp WITH (NOLOCK) ON ctmp.WorkDate = kiv.OnDate AND ctmp.EmpId = r.EmpId
			WHERE r.EmpId = @EmpId 
				AND r.RequestId <> @RequestId
				AND r.CurrentStatus IN (@PendingStatusId)
				AND kiv.OnDate BETWEEN @WeekStartDate AND @WeekEndDate
				AND kiv.OnDate <> @OnDate
				AND (c.IsHoliday = 0 OR ctmp.IsHoliday = 0) -- not count PH
		) AS CombinedDates;		
		DECLARE @MaxOffdaySetting INT = (SELECT TOP(1) s.OffDaysbyWeek FROM EmployeeSummary s WHERE s.EmpId = @EmpId)
		
		IF @SumDayOff >= @MaxOffdaySetting
			BEGIN		
				SET @ErrCode = 109
				SET @ErrMsg = 'The number of days off taken by the employee this week exceeds the setting limit'

				RETURN
			END
	END

	IF @EmpId <> @ModifiedBy
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor WITH (NOLOCK)
				WHERE OwnerId = @EmpId
					AND EmpId = @ModifiedBy
					AND ActionType = @OnBehalfRequest
					AND RequestType = @KeepInViewRequestTypeId
					AND ISNULL(IsDeleted, 0) = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
					INNER JOIN Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
					AND emp.EmpId = @EmpId
				WHERE gs.OwnerId = @ModifiedBy
					AND gs.ActionType = @OnBehalfRequest
					AND gs.RequestType = @KeepInViewRequestTypeId
					AND ISNULL(gs.IsDeleted, 0) = 0
				)
		BEGIN
			SET @ErrCode = 104
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
		SET @ErrCode = 105
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
			SET @ErrCode = 106
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
			SET @ErrCode = 107
			SET @ErrMsg = 'Approver is invalid.'

			RETURN;
		END
	END

	IF DATEDIFF(MI, @FromTime, @ToTime) < 60
	BEGIN
		SET @ErrCode = 108
		SET @ErrMsg = 'Minimum Compensation Leave is 60 minutes.'

		RETURN;
	END

	SELECT @OldOnDate = OnDate
	FROM dbo.KeepInViewRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId

	UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
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

	UPDATE dbo.KeepInViewRequest WITH (ROWLOCK, UPDLOCK)
	SET OnDate = @OnDate
		,KeepInViewType = @KeepInViewType
		,IsHalfDay = @IsHalfDay
		,FromTime = @FromTime
		,ToTime = @ToTime
	WHERE RequestId = @RequestId

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

	IF @OldOnDate <> @OnDate
	BEGIN
		EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
			,@fromDate = @OldOnDate
			,@toDate = @OldOnDate
			,@empIds = @EmpId
			,@isUpdateRequestData = 1
	END

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @OnDate
		,@toDate = @OnDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1

	EXEC dbo.KeepInViewRequest_WriteLog @RequestId
END
