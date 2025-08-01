/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_Insert]
(
    @EmpId INT
    ,@CompanyId SMALLINT
    ,@FromDate DATETIME
    ,@ToDate DATETIME
    ,@LeaveTypeId INT
    ,@TotalDays NUMERIC(5, 1) = NULL
    ,@Remark NVARCHAR(2000) = NULL
    ,@CreatedBy INT
    ,@VerifierId INT = NULL
    ,@ApproverId INT = NULL
    ,@RefNo NVARCHAR(200) = ''
    ,@IsHospitalApplication BIT	= NULL
    ,@ListDetail VARCHAR(MAX)
    ,@RequestId BIGINT = 0 OUTPUT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013-11-11
    Task: insert a Leave mutilple request form
    DB: bodb_HRM

    Revisions:
        20250423@Tim: fix bug validate request in the same range
        20250722@Tim: auto approve request [Redmine: #233324]
    Param's Explanation:
	    - @ListDetail: '<Root><Row OnDate='' ShiftId='' LeaveType='' IsHalfDay='' WorkType='' FromTime='' ToTime='' /></Root>'
	    - @WorkType: 1. off, 2. leave, 3. work
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @RequestType TINYINT = 6
        ,@AnnualLeaveType TINYINT = 2
        ,@KIVByDayLeaveType TINYINT = 10
        ,@KIVByHourLeaveType TINYINT = 48
        ,@PublicHolidayLeaveType TINYINT = 13
        ,@PaternityLeaveType TINYINT = 14
        ,@UnpaidLeaveType TINYINT = 25
        ,@UnpaidLeaveInsuranceType TINYINT = 41
        ,@MaternityLeaveType INT = 12
        ,@BusinessTripLeaveType TINYINT = 9
        ,@BusinessDuringWorkingLeaveType TINYINT = 26
        ,@SickLeaveTypeId TINYINT = 29
        ,@HospitalizationLeaveTypeId TINYINT = 39
        ,@OnbehalfActionType TINYINT = 5
        ,@VerifyActionType TINYINT = 2
        ,@ApproveActionType TINYINT = 3
        ,@LeaveWorkType TINYINT = 2
        ,@AutoApproveRequest BIT
        ,@IsLocal BIT
        ,@AnnualLeaveDay DECIMAL(18, 2)
        ,@SickLeaveDay DECIMAL(18, 2)
        ,@HospitalizationLeaveDay DECIMAL(18, 2)
        ,@KIVLeaveDay DECIMAL(18, 2)
        ,@KIVLeaveMinutes INT
        ,@TotalDays_tmp NUMERIC(5, 1)
        ,@IsHalfDay BIT
        ,@CreatedDate DATETIME = GETDATE()
        ,@TmpFromDate DATE
        ,@TmpToDate DATE
        ,@DocHandler INT
        ,@TotalDaysPaternity INT
        ,@BalanceDaysPaternity INT
        ,@JoinedDate DATE
        ,@AnnualLeaveResetTimelineType TINYINT
        ,@AnnualLeaveResetTimelineByYear TINYINT = 1
		-- request status
		,@PendingStatusId TINYINT = 1

	CREATE TABLE #tblLeaveRequestDetail (
		OnDate DATE
		,ShiftId INT
		,LeaveType INT
		,WorkType TINYINT
		,IsHalfDay BIT
		,FromTime DATETIME
		,ToTime DATETIME
		)

    SELECT @JoinedDate = JoinedDate
	FROM dbo.Employee AS e WITH (NOLOCK)
	    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
	WHERE e.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId

    SELECT @AnnualLeaveResetTimelineType = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'AnnualLeaveResetTimeline'

	SELECT @isHalfDay = CASE 
			WHEN @TotalDays = 0.5 THEN 1
			ELSE 0
			END
		,@TotalDays_tmp = @TotalDays
		,@TmpFromDate = CAST(@FromDate AS DATE)
		,@TmpToDate = CAST(@ToDate AS DATE)

	IF @FromDate IS NULL
		OR @ToDate IS NULL
		OR @LeaveTypeID IS NULL
		OR ISNULL(@TotalDays, 0) < 0
	BEGIN
		SET @ErrCode = 104
		SET @ErrMsg = 'Invalid parameter'

		RETURN;
	END

	IF CAST(@FromDate AS DATE) < @JoinedDate
	BEGIN
		SET @ErrCode = 120
		SET @ErrMsg = 'You can not request leave earlier than your joined date.'

		RETURN
	END

	IF @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear
        AND YEAR(@FromDate) != YEAR(@ToDate)
	BEGIN
		SET @ErrCode = 103
		SET @ErrMsg = 'You cannot submit a cross-year leave request. Please split it into 2 separate requests.'

		RETURN;
	END

    IF @AnnualLeaveResetTimelineType != @AnnualLeaveResetTimelineByYear
        AND DATEFROMPARTS(YEAR(@FromDate), MONTH(@JoinedDate), DAY(@JoinedDate)) >= @FromDate
        AND DATEFROMPARTS(YEAR(@ToDate), MONTH(@JoinedDate), DAY(@JoinedDate)) < @ToDate
	BEGIN
		SET @ErrCode = 103
		SET @ErrMsg = 'You cannot submit a cross-leave request based on your Group Date. Please split it into 2 separate requests.'

		RETURN;
	END

	IF @EmpId <> @CreatedBy
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeSupervisor WITH (NOLOCK)
			WHERE OwnerId = @EmpId
				AND EmpId = @CreatedBy
				AND ActionType = @OnbehalfActionType
				AND RequestType = @RequestType
				AND ISNULL(IsDeleted, 0) = 0
			)
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
				INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON g.GroupId = e.GroupId
			WHERE e.EmpId = @EmpId
				AND g.OwnerId = @CreatedBy
				AND g.RequestType = @RequestType
				AND g.ActionType = @OnbehalfActionType
				AND ISNULL(g.IsDeleted, 0) = 0
			)
	BEGIN
		SET @ErrCode = 106
		SET @ErrMsg = 'You have not on behalf permision on this employee.'

		RETURN;
	END

	SELECT @AutoApproveRequest = AutoApproveRequest
	FROM dbo.CompanyEmployee WITH (NOLOCK)
	WHERE EmpId = @EmpId
        AND CompanyId = @CompanyId

    SET @AutoApproveRequest = ISNULL(@AutoApproveRequest, 0)

    IF @AutoApproveRequest = 0
	BEGIN
		IF @VerifierId IS NULL
			OR (
				NOT EXISTS (
					SELECT 1
					FROM dbo.EmployeeSupervisor WITH (NOLOCK)
					WHERE OwnerId = @VerifierId
						AND EmpId = @EmpId
						AND ActionType = @VerifyActionType
						AND RequestType = @RequestType
						AND ISNULL(IsDeleted, 0) = 0
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
						INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON g.GroupId = e.GroupId
					WHERE e.EmpId = @EmpId
						AND g.OwnerId = @VerifierId
						AND g.RequestType = @RequestType
						AND g.ActionType = @VerifyActionType
						AND ISNULL(g.IsDeleted, 0) = 0
					)
				)
		BEGIN
			SET @ErrCode = 108
			SET @ErrMsg = 'Invalid Verifier.'

			RETURN;
		END

		IF @ApproverId IS NULL
			OR (
				NOT EXISTS (
					SELECT 1
					FROM dbo.EmployeeSupervisor WITH (NOLOCK)
					WHERE OwnerId = @ApproverId
						AND EmpId = @EmpId
						AND ActionType = @ApproveActionType
						AND RequestType = @RequestType
						AND ISNULL(IsDeleted, 0) = 0
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
						INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON g.GroupId = e.GroupId
					WHERE e.EmpId = @EmpId
						AND g.OwnerId = @ApproverId
						AND g.RequestType = @RequestType
						AND g.ActionType = @ApproveActionType
						AND ISNULL(g.IsDeleted, 0) = 0
					)
				)
		BEGIN
			SET @ErrCode = 109
			SET @ErrMsg = 'Invalid Approver.'

			RETURN;
		END
	END

	IF @LeaveTypeId <> @PublicHolidayLeaveType
		AND @TotalDays = 0.5
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND WorkDate = @FromDate
				AND (
					IsHoliday = 1
					OR IsOffDay = 1
					)
			)
	BEGIN
		SET @ErrCode = 105
		SET @ErrMsg = 'Your can not request on off day or holiday.'

		RETURN;
	END

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@ListDetail

		IF DATEDIFF(DD, @FromDate, @ToDate) + 1 <> (
				SELECT COUNT(1)
				FROM dbo.EmployeeCalendar WITH (NOLOCK)
				WHERE EmpId = @EmpId
					AND WorkDate BETWEEN CAST(@TmpFromDate AS DATETIME) AND CAST(@TmpToDate AS DATETIME)
				)
		BEGIN
			EXEC dbo.EmployeeCalendar_Insert @EmpId = @EmpId
				,@fromdate = @TmpFromDate
				,@todate = @TmpToDate
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END

		INSERT INTO #tblLeaveRequestDetail (OnDate, ShiftId, LeaveType, WorkType, IsHalfDay, FromTime, ToTime)
		SELECT d.OnDate,ISNULL(d.ShiftId, ec.ShiftId) AS ShiftId, d.LeaveType, d.WorkType, d.IsHalfDay, d.FromTime, d.ToTime
		FROM OPENXML(@DocHandler, '/ROOT/Row', 1) WITH (OnDate DATETIME, ShiftId INT, LeaveType INT, IsHalfDay BIT, WorkType TINYINT, FromTime DATETIME, ToTime DATETIME) AS d
			LEFT JOIN dbo.EmployeeCalendar ec WITH (NOLOCK) ON ec.WorkDate = d.OnDate
			AND ec.EmpId = @EmpId

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = ERROR_MESSAGE()

		RETURN
	END CATCH;

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
			GROUP BY OnDate
			HAVING COUNT(DISTINCT LeaveType) = 1
				AND COUNT(OnDate) > 1
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Please check Leave Type on this request.'

		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			)
	BEGIN
		SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay WHEN 1 THEN 0.5 ELSE 1 END)
		FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
			INNER JOIN #tblLeaveRequestDetail AS lrd WITH (NOLOCK) ON cl.WorkDate = lrd.OnDate
		WHERE cl.EmpId = @EmpId
			AND cl.WorkDate BETWEEN CAST(@TmpFromDate AS DATETIME) AND CAST(@TmpToDate AS DATETIME)
			AND cl.IsHoliday = 0
			AND cl.IsOffDay = 0
			AND cl.IsLeaveDay = 0
			AND lrd.WorkType = @LeaveWorkType

		IF @TotalDays_tmp IS NULL
		BEGIN
			SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay WHEN 1 THEN 0.5 ELSE 1 END)
			FROM #tblLeaveRequestDetail lrd WITH (NOLOCK)
			WHERE lrd.WorkType = @LeaveWorkType
		END

		SELECT @AnnualLeaveDay = SUM(CASE 
					WHEN LeaveType = @AnnualLeaveType THEN CASE WHEN IsHalfDay = 1 THEN 0.5 ELSE 1 END
					ELSE 0 END)
			,@SickLeaveDay = SUM(CASE 
					WHEN LeaveType = @SickLeaveTypeId THEN CASE WHEN IsHalfDay = 1 THEN 0.5 ELSE 1 END
					ELSE 0 END)
			,@HospitalizationLeaveDay = SUM(CASE 
					WHEN LeaveType = @HospitalizationLeaveTypeId THEN CASE WHEN IsHalfDay = 1 THEN 0.5 ELSE 1 END
					ELSE 0 END)
			,@KIVLeaveDay = SUM(CASE 
					WHEN LeaveType = @KIVByDayLeaveType THEN CASE IsHalfDay WHEN 1 THEN 0.5 ELSE 1 END
                    ELSE 0 END)
			,@KIVLeaveMinutes = SUM(CASE WHEN LeaveType = @KIVByHourLeaveType THEN DATEDIFF(MI, FromTime, ToTime)
                    ELSE 0 END)
		FROM #tblLeaveRequestDetail WITH (NOLOCK)
	END
	ELSE
	BEGIN
		IF @isHalfDay = 1
			AND ISNULL(@TotalDays_tmp, 1) = 1
		BEGIN
			SET @TotalDays_tmp = 0.5
		END

		IF @LeaveTypeId = @AnnualLeaveType
		BEGIN
			SELECT @AnnualLeaveDay = @TotalDays
		END
		ELSE IF @LeaveTypeId = @SickLeaveTypeId
		BEGIN
			SELECT @SickLeaveDay = @TotalDays
		END
		ELSE IF @LeaveTypeId = @HospitalizationLeaveTypeId
		BEGIN
			SELECT @HospitalizationLeaveDay = @TotalDays
		END
		ELSE IF @LeaveTypeId = @KIVByDayLeaveType
		BEGIN
			SELECT @KIVLeaveDay = @TotalDays
		END
	END

	IF ISNULL(@TotalDays_tmp, 0) <= 0
		AND @LeaveTypeID <> @PublicHolidayLeaveType
	BEGIN
		SET @ErrCode = 105
		SET @ErrMsg = 'Invalid leave days.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
				INNER JOIN dbo.LeaveRequest AS l WITH (NOLOCK) ON r.RequestId = l.RequestId
			WHERE r.empid = @empid
				AND r.RequestType = @RequestType
				AND r.CurrentStatus IN (1, 2, 4, 6)
				AND (
					(
						NOT EXISTS (
							SELECT 1
							FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							WHERE r.RequestId = ldt.RequestId
							)
						AND NOT EXISTS (
							SELECT 1
							FROM #tblLeaveRequestDetail WITH (NOLOCK)
							)
						AND (
							CAST(l.FromDate AS DATE) BETWEEN @TmpFromDate AND @TmpToDate
							OR CAST(l.ToDate AS DATE) BETWEEN @TmpFromDate AND @TmpToDate
							OR @TmpFromDate BETWEEN CAST(l.FromDate AS DATE) AND CAST(l.ToDate AS DATE)
							OR @TmpToDate BETWEEN CAST(l.FromDate AS DATE) AND CAST(l.ToDate AS DATE)
							)
						)
                    OR (
					    NOT EXISTS (
						    SELECT 1
						    FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
                            WHERE r.RequestId = ldt.RequestId
						    )
					    AND EXISTS (
						    SELECT 1
						    FROM #tblLeaveRequestDetail AS ldt WITH (NOLOCK)
						    WHERE ldt.OnDate BETWEEN l.FromDate AND l.ToDate
						    )
					    )
					OR (
						NOT EXISTS (
							SELECT 1
							FROM #tblLeaveRequestDetail WITH (NOLOCK)
							)
						AND EXISTS (
							SELECT 1
							FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							WHERE r.RequestId = ldt.RequestId
								AND ldt.OnDate BETWEEN @TmpFromDate AND @TmpToDate
							)
						)
					OR (
						EXISTS (
							SELECT 1
							FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
								INNER JOIN #tblLeaveRequestDetail AS ldtt WITH (NOLOCK) ON ldtt.OnDate = ldt.OnDate
							WHERE r.RequestId = ldt.RequestId
								AND (
									(
										ldt.IsHalfDay = 0
										AND ldtt.IsHalfDay = 0
										)
									OR (
										ldt.IsHalfDay = 0
										AND ldtt.IsHalfDay = 1
										AND (
											ldtt.FromTime BETWEEN ldt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldt.ToTime) + 1)
											OR ldtt.ToTime BETWEEN ldt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldt.ToTime) + 1)
											)
										)
									OR (
										ldt.IsHalfDay = 1
										AND ldtt.IsHalfDay = 0
										AND (
											ldt.FromTime BETWEEN ldtt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldtt.ToTime) + 1)
											OR ldt.ToTime BETWEEN ldtt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldtt.ToTime) + 1)
											)
										)
									OR (
										ldt.IsHalfDay = 1
										AND ldtt.IsHalfDay = 1
										AND (
											ldt.FromTime BETWEEN ldtt.FromTime AND ldtt.ToTime
											OR ldt.ToTime BETWEEN ldtt.FromTime AND ldtt.ToTime
											OR ldtt.FromTime BETWEEN ldt.FromTime AND ldt.ToTime
											OR ldtt.ToTime BETWEEN ldt.FromTime AND ldt.ToTime
											)
										)
										AND ldt.FromTime != ldtt.ToTime
										AND ldt.ToTime != ldtt.FromTime
									)
							)
						)
					)
			)
	BEGIN
		SET @ErrCode = 107
		SET @ErrMsg = 'There is another request in the same range.'

		RETURN;
	END

	SELECT @AnnualLeaveDay = ISNULL(@AnnualLeaveDay, 0)

	IF @AnnualLeaveDay > 0
	BEGIN
		IF @AnnualLeaveDay > dbo.fnc_GetAnnualLeaveBalanceByDate(@EmpId, @ToDate, NULL)
		BEGIN
			SET @ErrCode = 108
			SET @ErrMsg = 'Not enough annual leave days to request.'

			RETURN;
		END
	END

	DECLARE @Year INT = YEAR(@ToDate)

	EXEC dbo.LeaveRequest_CheckSickLeaveBalance @EmpId = @EmpId
		,@LeaveDays = @SickLeaveDay
		,@Year = @Year
		,@ErrCode = @ErrCode OUT
		,@ErrMsg = @ErrMsg OUT

	IF @ErrCode > 0 RETURN;

	EXEC dbo.LeaveRequest_CheckHospitalizationLeaveBalance @EmpId = @EmpId
		,@LeaveDays = @HospitalizationLeaveDay
		,@Year = @Year
		,@ErrCode = @ErrCode OUT
		,@ErrMsg = @ErrMsg OUT

	IF @ErrCode > 0 RETURN;

	SELECT @KIVLeaveDay = ISNULL(@KIVLeaveDay, 0)

	IF @KIVLeaveDay > 0
	BEGIN
		IF @KIVLeaveDay > dbo.fnc_GetKIVByDayBalance(@EmpId, @ToDate, NULL)
		BEGIN
			SET @ErrCode = 111
			SET @ErrMsg = 'Not enough Compensation Leave days to request.'

			RETURN;
		END
	END

	IF @KIVLeaveMinutes > 0
	BEGIN
		IF @KIVLeaveMinutes > dbo.fnc_GetKIVByHourBalance(@EmpId, @FromDate, NULL)
		BEGIN
			SET @ErrCode = 111
			SET @ErrMsg = 'Not enough Compensation Leave hours to request.'

			RETURN;
		END
	END

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
				AND LeaveType IN (@UnpaidLeaveInsuranceType)
			)
	BEGIN
		SET @ErrCode = 112
		SET @ErrMsg = 'This leave type does not support half day.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
				AND LeaveType IN (@AnnualLeaveType, @UnpaidLeaveType, @KIVByDayLeaveType)
				AND DATEDIFF(MINUTE, FromTime, ToTime) > 300
			)
	BEGIN
		SET @ErrCode = 113
		SET @ErrMsg = 'You can not request leave half day over 5 hours.'

		RETURN;
	END

	-- check rule for leave during working hours
	IF @LeaveTypeId = @BusinessDuringWorkingLeaveType
		AND EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
			)
	BEGIN
		IF EXISTS (
				SELECT 1
				FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
					INNER JOIN dbo.LeaveRequest AS lv WITH (NOLOCK) ON lv.RequestId = ldt.RequestId
					AND lv.EmpId = @EmpId
					AND lv.LeaveType = @BusinessDuringWorkingLeaveType
					AND DATEDIFF(MONTH, lv.FromDate, @FromDate) = 0
					INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON wk.RequestId = ldt.RequestId
					AND wk.CurrentStatus IN (1, 2, 4, 6)
				WHERE ldt.IsHalfDay = 1
				)
		BEGIN
			SET @ErrCode = 114
			SET @ErrMsg = 'You had been reached maximum leave during working hours in month.'

			RETURN
		END

		IF EXISTS (
				SELECT 1
				FROM #tblLeaveRequestDetail WITH (NOLOCK)
				WHERE IsHalfDay = 1
					AND LeaveType = @BusinessDuringWorkingLeaveType
					AND DATEDIFF(MI, FromTime, ToTime) > 120
				)
		BEGIN
			SET @ErrCode = 115
			SET @ErrMsg = 'You can not request leave during working hours > 120 minutes.'

			RETURN
		END

		EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId 
			,@fromDate = @FromDate
			,@toDate = @FromDate
			,@empIds = @EmpId

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.tmpEmployeeCalendar WITH (NOLOCK)
				WHERE EmpId = @EmpId
					AND WorkDate = CAST(@FromDate AS DATE)
					AND ISNULL(ShiftId, 0) > 0
				)
		BEGIN
			SET @ErrCode = 116
			SET @ErrMsg = 'You can not request because this date has not arranged shift yet.'

			RETURN
		END

		IF EXISTS (
				SELECT 1
				FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
					INNER JOIN dbo.[Shift] AS shift WITH (NOLOCK) ON empca.ShiftId = shift.ShiftId
					INNER JOIN #tblLeaveRequestDetail AS detail WITH (NOLOCK) ON empca.WorkDate = CAST(detail.OnDate AS DATE)
					AND CONVERT(VARCHAR(5), detail.FromTime, 108) = shift.BeginCheckInTime
				WHERE empca.EmpId = @EmpId
					AND empca.WorkDate = CAST(@FromDate AS DATE)
				)
		BEGIN
			SET @ErrCode = 117
			SET @ErrMsg = 'You can not request at the beginning of the shift.'

			RETURN
		END
	END

	-- check paternity leave
	IF @LeaveTypeId = @PaternityLeaveType
		OR EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE LeaveType = @PaternityLeaveType
			)
	BEGIN
		IF @LeaveTypeId = @PaternityLeaveType
		BEGIN
			SELECT @TotalDaysPaternity = @TotalDays
				,@TmpFromDate = @FromDate
				,@TmpToDate = @ToDate
		END
		ELSE
		BEGIN
			SELECT @TotalDaysPaternity = COUNT(1)
				,@TmpFromDate = MIN(OnDate)
				,@TmpToDate = MAX(OnDate)
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE LeaveType = @PaternityLeaveType
		END

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeePaternity WITH (NOLOCK)
				WHERE EmpId = @EmpId
					AND @TmpFromDate >= ChildBornDate
					AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
				)
		BEGIN
			SET @ErrCode = 118
			SET @ErrMsg = 'You can not request because request within 1 month from child born date.'

			RETURN
		END

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeePaternity WITH (NOLOCK)
				WHERE EmpId = @EmpId
					AND @TmpFromDate >= ChildBornDate
					AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
					AND BalanceDay >= @TotalDaysPaternity
				)
		BEGIN
			SET @ErrCode = 119
			SET @ErrMsg = 'You have not enough paternity leave days to request.'

			RETURN
		END

		UPDATE dbo.EmployeePaternity WITH (ROWLOCK, UPDLOCK)
		SET BalanceDay = BalanceDay - @TotalDaysPaternity
		WHERE EmpId = @EmpId
			AND @TmpFromDate >= ChildBornDate
			AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
	END

	EXEC [dbo].WorkingTimeRequest_GetNewRefNoByRequestType @RefNo = @RefNo OUTPUT
		,@RequestType = @RequestType

	BEGIN TRY
		INSERT INTO dbo.WorkingTimeRequest (EmpId, RequestType, [Remark], CurrentStatus, VerifierId, ApproverId, VerifiedStatus, ApprovedStatus, HRStatus, CreatedDate, CreatedBy)
		VALUES (@EmpId, @RequestType, @Remark, @PendingStatusId, @VerifierId,
			CASE WHEN @AutoApproveRequest = 1 AND @ApproverId IS NULL THEN -1 ELSE @ApproverId END,
            @PendingStatusId, @PendingStatusId, @PendingStatusId, @CreatedDate, @CreatedBy)

		SELECT @RequestId = CAST(SCOPE_IDENTITY() AS BIGINT)

		INSERT INTO [dbo].[LeaveRequest] (RequestId, EmpId, FromDate, ToDate, LeaveType, TotalDays, RefNo)
		VALUES (@RequestId, @EmpId, @FromDate, @ToDate, @LeaveTypeId, @TotalDays, @RefNo)

		INSERT INTO [dbo].[LeaveRequestDetail] (RequestId, EmpId, OnDate, ShiftId, LeaveType, IsHalfDay, FromTime, ToTime, WorkType)
		SELECT @RequestId, @EmpId, OnDate, ShiftId, LeaveType, IsHalfDay, FromTime, ToTime, WorkType
		FROM #tblLeaveRequestDetail WITH (NOLOCK)

		EXEC dbo.LeaveRequest_EmployeeCalendar_UpdateOffDay @RequestId

		EXEC dbo.LeaveRequest_InsertTmpAnnualLeaveTrans @RequestId = @RequestId
			,@EmpId = @EmpId

		EXEC dbo.LeaveRequest_InsertTmpHospitalizationLeaveTrans @RequestId = @RequestId

		EXEC dbo.HospitalLeave_Insert @RequestId = @RequestId, @IsHospitalApplication = @IsHospitalApplication

		EXEC dbo.LeaveRequest_InsertTmpSickLeaveTrans @RequestId = @RequestId

		EXEC dbo.LeaveRequest_InsertKIVLeaveTrans @RequestId = @RequestId

		EXEC dbo.LeaveRequest_InsertWeekendLeaveTrans @RequestId = @RequestId

		EXEC dbo.LeaveRequest_WriteLog @RequestId

		IF @ApproverId IS NULL
			AND @VerifierId IS NULL
			AND @AutoApproveRequest = 1
		BEGIN
			EXEC dbo.LeaveRequest_Approve @RequestId = @RequestId
				,@ActorId = -1
				,@RoleId = 3
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END

		EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId 
			,@fromDate = @FromDate
			,@toDate = @ToDate
			,@empIds = @EmpId
			,@isUpdateRequestData = 1
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = ERROR_MESSAGE()

		RETURN
	END CATCH

	DROP TABLE #tblLeaveRequestDetail
END