/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_Update]
(
    @RequestId BIGINT
    ,@EmpId INT
    ,@CompanyId SMALLINT
    ,@Remark NVARCHAR(2000) = NULL
    ,@FromDate DATETIME = NULL
    ,@ToDate DATETIME = NULL
    ,@LeaveTypeId INT = NULL
    ,@TotalDays NUMERIC(5, 1) = NULL
    ,@ModifiedBy INT = NULL
    ,@VerifierId INT = NULL
    ,@ApproverId INT = NULL
    ,@HRId INT = NULL
    ,@RefNo NVARCHAR(200) = ''
    ,@IsHospitalApplication BIT	= NULL
    ,@ListDetail VARCHAR(MAX) = ''
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013-11-11
    Task: update leave request
    DB: bodb_HRM

    Revisions:
        20250423@Tim: fix bug validate request in the same range
        20250722@Tim: auto approve request [Redmine: #233324]
        20250813@Jay: change db structure [Redmine: #235678]
		20251111@Lilac: remove on behalf request [Redmine: #243412]
    Param's Explanation:
	    - @ListDetail: '<ROOT><Row OnDate='' ShiftID='' LeaveType='' IsHalfDay='' WorkType='' FromTime='' ToTime='' /></ROOT>'
	    - @WorkType : 1. off, 2. leave, 3. work
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @RequestType TINYINT = 6
        ,@AnnualLeaveType TINYINT = 2
        ,@KIVLeaveType TINYINT = 10
        ,@KIVByHourLeaveType TINYINT = 48
        ,@PublicHolidayLeaveType TINYINT = 13
        ,@PaternityLeaveType TINYINT = 14
        ,@MaternityLeaveType INT = 12
        ,@UnpaidLeaveType TINYINT = 25
        ,@UnpaidLeaveInsuranceType TINYINT = 41
        ,@BusinessTripLeaveType TINYINT = 9
        ,@BusinessDuringWorkingLeaveType TINYINT = 26
        ,@SickLeaveTypeId TINYINT = 29
        ,@HospitalizationLeaveTypeId TINYINT = 39
        ,@VerifyActionType TINYINT = 2
        ,@ApproveActionType TINYINT = 3
        ,@LeaveWorkType TINYINT = 2
        ,@TotalDays_tmp NUMERIC(5, 1)
        ,@AnnualLeaveDay DECIMAL(18, 2)
        ,@SickLeaveDay DECIMAL(18, 2)
        ,@HospitalizationLeaveDay DECIMAL(18, 2)
        ,@KIVLeaveDay DECIMAL(18, 2)
        ,@KIVLeaveMinutes INT
        ,@isHalfDay BIT
        ,@ModifiedDate DATETIME
        ,@AutoApproveRequest BIT
        ,@TmpFromDate DATE
        ,@TmpToDate DATE
        ,@DocHandler INT
        ,@OldTotalDays INT
        ,@TotalDaysPaternity INT
        ,@BalanceDaysPaternity INT
        ,@OldFromDate DATE
        ,@OldToDate DATE
        ,@JoinedDate DATE
        ,@AnnualLeaveResetTimelineType TINYINT
        ,@AnnualLeaveResetTimelineByYear TINYINT = 1
		-- request status
		,@PendingStatusId TINYINT = 1

	CREATE TABLE #tblLeaveRequestDetail (
		OnDate DATETIME
		,ShiftId INT
		,LeaveType INT
		,WorkType TINYINT
		,IsHalfDay BIT
		,FromTime DATETIME
		,ToTime DATETIME
		)

    SELECT @JoinedDate = JoinedDate
    FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
        INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
    WHERE ce.EmpId = @EmpId
        AND ce.CompanyId = @CompanyId

    SELECT @AnnualLeaveResetTimelineType = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'AnnualLeaveResetTimeline'

	SELECT @IsHalfDay = CASE 
			WHEN @TotalDays = 0.5 THEN 1
			ELSE 0
			END
		,@TotalDays_tmp = @TotalDays
		,@ModifiedDate = GETDATE()
		,@TmpFromDate = CAST(@FromDate AS DATE)
		,@TmpToDate = CAST(@ToDate AS DATE)

	IF CAST(@FromDate AS DATE) < @JoinedDate
	BEGIN
		SET @ErrCode = 120
		SET @ErrMsg = 'You can not request leave earlier than your joined date.'

		RETURN
	END

	IF NOT EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest WITH (NOLOCK)
			WHERE RequestId = @RequestId
				AND CurrentStatus = 1
			)
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'You can not change this request beacause current status is not pending.'

		RETURN;
	END

	IF @FromDate IS NULL
		OR @ToDate IS NULL
		OR @LeaveTypeId IS NULL
		OR ISNULL(@TotalDays, 0) < 0
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'Invalid parameter'

		RETURN;
	END

	IF ISNULL(@RefNo, '') NOT LIKE 'REF-%'
	BEGIN
		SET @ErrCode = 101
		SET @ErrMsg = 'Ref No incorrect format'

		RETURN;
	END

	IF @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear
        AND YEAR(@FromDate) != YEAR(@ToDate)
	BEGIN
		SET @ErrCode = 102
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
					FROM [dbo].[EmployeeSupervisor] sp WITH (NOLOCK)
					WHERE sp.OwnerId = @VerifierId
						AND sp.EmpId = @EmpId
						AND sp.ActionType = @VerifyActionType
						AND sp.RequestType = @RequestType
						AND ISNULL(sp.IsDeleted, 0) = 0
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
						INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON g.GroupId = ce.GroupId
					WHERE ce.EmpId = @EmpId
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
					FROM [dbo].[EmployeeSupervisor] sp WITH (NOLOCK)
					WHERE sp.OwnerId = @ApproverId
						AND sp.EmpId = @EmpId
						AND sp.ActionType = @ApproveActionType
						AND sp.RequestType = @RequestType
						AND ISNULL(sp.IsDeleted, 0) = 0
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
						INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON g.GroupId = ce.GroupId
					WHERE ce.EmpId = @EmpId
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

	IF @LeaveTypeID <> @PublicHolidayLeaveType
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

		IF DATEDIFF(DD, @TmpFromDate, @TmpToDate) + 1 <> (
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
		SELECT d.OnDate, ISNULL(d.ShiftId, ec.ShiftId), d.LeaveType, d.WorkType, d.IsHalfDay, d.FromTime, d.ToTime
		FROM OPENXML(@DocHandler, '/ROOT/Row', 1) WITH (OnDate DATETIME, ShiftId INT, LeaveType INT, IsHalfDay BIT, WorkType TINYINT, FromTime DATETIME, ToTime DATETIME) AS d
			LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = d.OnDate
			AND ec.EmpId = @EmpId

		IF @@ROWCOUNT <> 0
		BEGIN
			SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay WHEN 1 THEN 0.5 ELSE 1 END)
			FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
				INNER JOIN #tblLeaveRequestDetail AS lrd WITH (NOLOCK) ON cl.WorkDate = lrd.OnDate
			WHERE cl.EmpId = @EmpId
				AND cl.WorkDate BETWEEN CAST(@TmpFromDate AS DATETIME) AND CAST(@TmpToDate AS DATETIME)
				AND cl.IsHoliday = 0
				AND cl.IsOffDay = 0 --AND IsLeaveDay = 0
				AND lrd.WorkType = @LeaveWorkType
		END

		IF @TotalDays_tmp IS NULL
			SELECT @TotalDays = SUM(CASE lrd.IsHalfDay WHEN 1 THEN 0.5 ELSE 1 END)
			FROM #tblLeaveRequestDetail lrd WITH (NOLOCK)
			WHERE lrd.WorkType = @LeaveWorkType

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 103
			,@ErrMsg = N'Edit leave request for an employee failed.'

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
					WHEN LeaveType = @KIVLeaveType THEN CASE IsHalfDay WHEN 1 THEN 0.5 ELSE 1 END
					ELSE 0 END)
			,@KIVLeaveMinutes = SUM(CASE 
					WHEN LeaveType = @KIVByHourLeaveType THEN DATEDIFF(MI, FromTime, ToTime)
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
		ELSE IF @LeaveTypeId = @KIVLeaveType
		BEGIN
			SELECT @KIVLeaveDay = @TotalDays
		END
	END

	IF ISNULL(@TotalDays_tmp, 0) <= 0
		AND @LeaveTypeId <> @PublicHolidayLeaveType
	BEGIN
		SET @ErrCode = 105
		SET @ErrMsg = 'Your leave days invalid.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
				INNER JOIN dbo.LeaveRequest AS l WITH (NOLOCK) ON r.RequestId = l.RequestId
			WHERE r.RequestId != @RequestId
				AND r.empid = @empid
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
							CAST(l.FromDate AS DATE) BETWEEN @TmpFromDate
								AND @TmpToDate
							OR CAST(l.ToDate AS DATE) BETWEEN @TmpFromDate
								AND @TmpToDate
							OR @TmpFromDate BETWEEN CAST(l.FromDate AS DATE)
								AND CAST(l.ToDate AS DATE)
							OR @TmpToDate BETWEEN CAST(l.FromDate AS DATE)
								AND CAST(l.ToDate AS DATE)
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
										AND ldt.FromTime != ldtt.ToTime
										AND ldt.ToTime != ldtt.FromTime
										)
									)
							)
						)
					)
			)
	BEGIN
		SET @ErrCode = 104
		SET @ErrMsg = 'There is another request in the same range'

		RETURN;
	END

	IF @TotalDays_tmp IS NOT NULL
		OR @TotalDays_tmp > 0
		SET @TotalDays = @TotalDays_tmp

	SELECT @AnnualLeaveDay = ISNULL(@AnnualLeaveDay, 0)

	IF @AnnualLeaveDay > 0
	BEGIN
		IF @AnnualLeaveDay > dbo.fnc_GetAnnualLeaveBalanceByDate(@EmpId, @ToDate, @RequestId)
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
		IF @KIVLeaveDay > dbo.fnc_GetKIVByDayBalance(@EmpId, @ToDate, @RequestId)
		BEGIN
			SET @ErrCode = 111
			SET @ErrMsg = 'Not enough Compensation Leave days to request.'

			RETURN;
		END
	END

	SELECT @KIVLeaveMinutes = ISNULL(@KIVLeaveMinutes, 0)

	IF @KIVLeaveMinutes > 0
	BEGIN
		IF @KIVLeaveMinutes > dbo.fnc_GetKIVByHourBalance(@EmpId, @FromDate, @RequestId)
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
		SET @ErrMsg = 'Leave type does not support half day.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
				AND LeaveType IN (@AnnualLeaveType, @UnpaidLeaveType, @KIVLeaveType)
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
				WHERE ldt.RequestId <> @RequestId
					AND ldt.IsHalfDay = 1
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
	SELECT @TotalDaysPaternity = TotalDays
		,@TmpFromDate = FromDate
		,@TmpToDate = ToDate
	FROM dbo.LeaveRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId
		AND LeaveType = @PaternityLeaveType

	IF ISNULL(@TotalDaysPaternity, 0) = 0
	BEGIN
		SELECT @TotalDaysPaternity = COUNT(1)
			,@TmpFromDate = MIN(OnDate)
			,@TmpFromDate = MAX(OnDate)
		FROM dbo.LeaveRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId
			AND LeaveType = @PaternityLeaveType
	END

	IF @TotalDaysPaternity > 0
	BEGIN
		UPDATE dbo.EmployeePaternity WITH (ROWLOCK, UPDLOCK)
		SET BalanceDay = BalanceDay + @TotalDaysPaternity
		WHERE EmpId = @EmpId
			AND @TmpFromDate >= ChildBornDate
			AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
	END

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

	SELECT @OldFromDate = FromDate
		,@OldToDate = ToDate
	FROM dbo.LeaveRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId

	BEGIN TRY
		BEGIN TRANSACTION Update_LeaveMultiRequest

		UPDATE WorkingTimeRequest WITH (ROWLOCK)
		SET Remark = @Remark
			,[CurrentStatus] = @PendingStatusId
			,VerifierId = @VerifierId
			,[VerifiedStatus] = @PendingStatusId
			,ApproverId = CASE WHEN @AutoApproveRequest = 1 AND @ApproverId IS NULL THEN -1 ELSE @ApproverId END
			,[ApprovedStatus] = @PendingStatusId
			,HRId = @HRId
			,ModifiedBy = @ModifiedBy
			,ModifiedDate = @ModifiedDate
		WHERE RequestId = @RequestId

		UPDATE dbo.LeaveRequest WITH (ROWLOCK)
		SET FromDate = @FromDate
			,ToDate = @ToDate
			,LeaveType = @LeaveTypeId
			,TotalDays = @TotalDays
		WHERE RequestId = @RequestId

		DELETE
		FROM dbo.LeaveRequestDetail
		WHERE RequestId = @RequestId

		INSERT INTO dbo.LeaveRequestDetail (RequestId, EmpId, OnDate, ShiftId, LeaveType, IsHalfDay, FromTime, ToTime, WorkType)
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
				,@RoleID = 3
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
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

		COMMIT TRANSACTION Update_LeaveMultiRequest;
	END TRY

	BEGIN CATCH
		SELECT ERROR_MESSAGE()

		SELECT @ErrCode = 999
			,@ErrMsg = N'Update request failed.'

		ROLLBACK TRANSACTION Update_LeaveMultiRequest;

		RETURN
	END CATCH;

	DROP TABLE #tblLeaveRequestDetail
END
GO
