/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeAttendance_ProcessingAndInsert_ForEmpId] @empId INT
	,@fromTime DATETIME
	,@toTime DATETIME
	,@onlyUpdate BIT = 0
AS
/*
Created:
Task:
DB: HRM

Revisions:

*/
BEGIN
	SET XACT_ABORT ON;
	
	DECLARE @RangeToScanTime SMALLINT = 480 -- 480 munites
        ,@serverTimeZone SMALLINT = -4
        ,@clientTimeZone REAL
		,@DateChangeRuleLateInEarlyOutRequest DATETIME = '2015-10-19'
	DECLARE @TimeRecord TABLE (Id INT, EmpId INT, RecordTime DATETIME, InOutType TINYINT)

    SELECT @clientTimeZone = config.[Value]
    FROM dbo.Employee AS emp WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'
    WHERE emp.EmpId = @EmpId

    SET @clientTimeZone = ISNULL(@clientTimeZone, @serverTimeZone)

	INSERT INTO @TimeRecord (Id, EmpId, RecordTime, InOutType)
	SELECT Id, EmpId, RecordTime, InOutType
	FROM #tmpTimeRecord WITH (NOLOCK)
	WHERE DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), RecordTime)) BETWEEN DATEADD(HH, - 2, CONVERT(VARCHAR(10), @fromTime, 111))
			AND DATEADD(d, 2, CONVERT(VARCHAR(10), @toTime, 111))
		AND EmpId = @empId

	DECLARE @i INT
		,@attendaceDate DATETIME
	DECLARE @WorkDate DATETIME
		,@ShiftId INT
		,@IsHoliday BIT
		,@isOffDay BIT
		,@IsLeaveDay BIT
		,@LeaveTypeId INT
		,@LateIn INT
		,@EarlyOut INT
		,@RequestedCheckinTime DATETIME
		,@RequestedCheckoutTime DATETIME
		,@BeginCheckInTime DATETIME
		,@EndCheckInTime DATETIME
		,@BeginCheckOutTime DATETIME
		,@EndCheckOutTime DATETIME
		,@InOfMachine DATETIME
		,@OutOfMachine DATETIME
		,@ExpectedInTime DATETIME
		,@ExpectedOutTime DATETIME
		,@Absence BIT
		,@IsRightShift BIT
		,@ActualLateIn INT
		,@ActualEarlyOut INT
		,@TotalWorkHours DECIMAL(18, 2)
		,@BreakTimeMins INT
		,@LeaveDay DECIMAL(18, 1)
		,@Notes NVARCHAR(2000)
		,@RequestLeaveTimeBegin DATETIME
		,@RequestLeaveTimeEnd DATETIME
		,@adjustLateIn INT
		,@adjustEarlyOut INT

	SET @i = 0
	SET @attendaceDate = CONVERT(VARCHAR(10), @fromTime, 111)

	WHILE DATEDIFF(d, @attendaceDate, @toTime) >= 0
	BEGIN
        SELECT @Absence = 0
			,@InOfMachine = NULL
			,@OutOfMachine = NULL
			,@ExpectedOutTime = NULL
			,@IsRightShift = NULL
			,@ExpectedInTime = NULL
			,@ExpectedOutTime = NULL
			,@ActualLateIn = 0
			,@ActualEarlyOut = 0
			,@RequestedCheckinTime = NULL
			,@RequestedCheckoutTime = NULL
			,@TotalWorkHours = NULL
			,@BreakTimeMins = 0
			,@ShiftId = NULL
			,@LeaveTypeId = NULL
			,@RequestLeaveTimeBegin = NULL
			,@RequestLeaveTimeEnd = NULL
			,@adjustLateIn = 0
			,@adjustEarlyOut = 0

		SELECT @WorkDate = WorkDate
			,@ShiftId = ShiftId
			,@IsHoliday = IsHoliday
			,@isOffDay = IsOffDay
			,@IsLeaveDay = IsLeaveDay
			,@LeaveTypeId = LeaveTypeId
			,@LateIn = ISNULL(LateIn, 0)
			,@EarlyOut = ISNULL(EarlyOut, 0)
			,@RequestedCheckinTime = RequestedCheckinTime
			,@RequestedCheckoutTime = RequestedCheckoutTime
			,@BeginCheckInTime = BeginCheckInTime
			,@EndCheckInTime = EndCheckInTime
			,@BeginCheckOutTime = BeginCheckOutTime
			,@EndCheckOutTime = EndCheckOutTime
			,@BreakTimeMins = BreakTimeMins
			,@LeaveDay = LeaveDay
		FROM #tmpEmpCalendar WITH (NOLOCK)
		WHERE EmpId = @empId
			AND WorkDate = @attendaceDate

		IF DATEDIFF(D, @DateChangeRuleLateInEarlyOutRequest, @WorkDate) >= 0
		BEGIN
			SELECT @LateIn = 0
				,@EarlyOut = 0
		END

		-- If Has Shift
		IF @ShiftId IS NOT NULL
			AND ISNULL(@LeaveDay, 0) <> 1
		BEGIN
			SET @ExpectedInTime = @BeginCheckInTime
			SET @ExpectedOutTime = @BeginCheckOutTime

			-- get time in
			SELECT @InOfMachine = MIN(RecordTime)
			FROM @TimeRecord
			WHERE InOutType = 0
				AND RecordTime BETWEEN DATEADD(mi, - @RangeToScanTime, @ExpectedInTime)
					AND @ExpectedOutTime

			-- get time out
			SELECT @OutOfMachine = MAX(RecordTime)
			FROM @TimeRecord
			WHERE InOutType = 1
				AND RecordTime BETWEEN @ExpectedInTime
					AND DATEADD(mi, @RangeToScanTime, @ExpectedOutTime)

			IF @InOfMachine > @OutOfMachine
			BEGIN
				SET @OutOfMachine = NULL
			END

			IF @RequestedCheckinTime IS NOT NULL
			BEGIN
				SET @InOfMachine = @RequestedCheckinTime
			END

			IF @RequestedCheckoutTime IS NOT NULL
			BEGIN
				SET @OutOfMachine = @RequestedCheckoutTime
			END

			IF DATEADD(mi, @EarlyOut, @OutOfMachine) < @ExpectedOutTime
			BEGIN
				SET @ActualEarlyOut = DATEDIFF(MINUTE, DATEADD(mi, @EarlyOut, @OutOfMachine), @ExpectedOutTime)
			END

			IF DATEADD(mi, - @LateIn, @InOfMachine) > @ExpectedINTime
			BEGIN
				SET @ActualLateIn = DATEDIFF(MINUTE, @ExpectedINTime, DATEADD(mi, - @LateIn, @InOfMachine))
			END

			IF @InOfMachine IS NOT NULL
			BEGIN
				IF @InOfMachine < @ExpectedInTime
				BEGIN
					SET @TotalWorkHours = (DATEDIFF(mi, @ExpectedInTime, @OutOfMachine) - ISNULL(@BreakTimeMins, 0)) / 60.0
				END
				ELSE
				BEGIN
					SET @TotalWorkHours = (DATEDIFF(mi, @InOfMachine, @OutOfMachine) - ISNULL(@BreakTimeMins, 0)) / 60.0
				END

				-- half leave
				IF @IsLeaveDay = 1
					AND @LeaveDay = 0.5
				BEGIN
					SELECT @RequestLeaveTimeBegin = FromTime
						,@RequestLeaveTimeEnd = ToTime
					FROM #tmpLeaveRequestHalfDay
					WHERE EmpId = @empId
						AND OnDate = @attendaceDate

					IF @RequestLeaveTimeBegin IS NOT NULL
						AND @RequestLeaveTimeEnd IS NOT NULL
					BEGIN
						IF DATEDIFF(mi, @ExpectedInTime, @RequestLeaveTimeBegin) < 30
							AND DATEDIFF(mi, @ExpectedInTime, @RequestLeaveTimeBegin) > - 30
						BEGIN
							SET @adjustLateIn = DATEDIFF(mi, @RequestLeaveTimeBegin, @RequestLeaveTimeEnd)
							SET @ActualLateIn = @ActualLateIn - @adjustLateIn

							IF @ActualLateIn < 0
							BEGIN
								SET @ActualLateIn = 0
							END
						END
						ELSE IF DATEDIFF(mi, @ExpectedOutTime, @RequestLeaveTimeEnd) < 30
							AND DATEDIFF(mi, @ExpectedOutTime, @RequestLeaveTimeEnd) > - 30
						BEGIN
							SET @adjustEarlyOut = DATEDIFF(mi, @RequestLeaveTimeBegin, @RequestLeaveTimeEnd)
							SET @ActualEarlyOut = @ActualEarlyOut - @adjustEarlyOut

							IF @ActualEarlyOut < 0
							BEGIN
								SET @ActualEarlyOut = 0
							END
						END
					END
				END
			END
		END
		ELSE IF ISNULL(@isOffDay, 0) = 0
			AND ISNULL(@IsHoliday, 0) = 0
			AND ISNULL(@LeaveDay, 0) <> 1
		BEGIN
			-- get time in
			SELECT @InOfMachine = MIN(RecordTime)
			FROM @TimeRecord
			WHERE InOutType = 0
				AND DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), RecordTime)) BETWEEN DATEADD(mi, 270, @attendaceDate)
					AND DATEADD(mi, 270, DATEADD(d, 1, @attendaceDate)) -- 4h30 of after day

			-- get time out
			SELECT @OutOfMachine = MAX(RecordTime)
			FROM @TimeRecord
			WHERE InOutType = 1
				AND DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), RecordTime)) BETWEEN DATEADD(mi, 540, @attendaceDate)
					AND DATEADD(mi, 720, DATEADD(d, 1, @attendaceDate)) -- 12h of after day

			IF @InOfMachine > @OutOfMachine
			BEGIN
				SET @OutOfMachine = NULL
			END

			IF @RequestedCheckinTime IS NOT NULL
			BEGIN
				SET @InOfMachine = @RequestedCheckinTime
			END

			IF @RequestedCheckoutTime IS NOT NULL
			BEGIN
				SET @OutOfMachine = @RequestedCheckoutTime
			END

			IF @InOfMachine IS NOT NULL
				AND @OutOfMachine IS NOT NULL
			BEGIN
				SET @TotalWorkHours = (DATEDIFF(mi, @InOfMachine, @OutOfMachine)) / 60.0
			END
		END

		IF @ShiftId IS NULL
			OR (
				@IsLeaveDay = 1
				AND @LeaveDay = 1
				)
		BEGIN
			SET @Absence = 1
		END
		ELSE IF @InOfMachine IS NULL
			AND @OutOfMachine IS NULL
		BEGIN
			SET @Absence = 1
		END

		--SELECT @ShiftId, @InOfMachine, @OutOfMachine, @IsLeaveDay, @isOffDay, @IsHoliday
		IF DATEDIFF(DD, @attendaceDate, DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), GETDATE()))) >= 0
		BEGIN
			IF (
					@ShiftId IS NOT NULL
					OR @InOfMachine IS NOT NULL
					OR @OutOfMachine IS NOT NULL
					OR @IsLeaveDay = 1
					OR @isOffDay = 1
					OR @IsHoliday = 1
					)
			BEGIN
				-- insert or update
				IF EXISTS (
						SELECT 1
						FROM dbo.EmployeeAttendance WITH (NOLOCK)
						WHERE EmpId = @empId
							AND AttendanceDate = CAST(@attendaceDate AS DATETIME)
						)
				BEGIN
					--update
					UPDATE dbo.EmployeeAttendance WITH (ROWLOCK)
					SET ShiftId = @ShiftId
						,InFixed = @InOfMachine
						,OutFixed = @OutOfMachine
						,ExpectedInTime = @ExpectedInTime
						,ExpectedOutTime = @ExpectedOutTime
						,LateIn = @ActualLateIn
						,EarlyOut = @ActualEarlyOut
						,LeaveTypeId = @LeaveTypeId
						,Absence = @Absence
						,TotalWorkHours = @TotalWorkHours
						,IsRightShift = @IsRightShift
						,LeaveDay = @LeaveDay
						,InsertDate = GETDATE()
					WHERE EmpId = @empId
						AND AttendanceDate = CAST(@attendaceDate AS DATETIME)
				END
				ELSE
				BEGIN
					--insert
					INSERT INTO dbo.EmployeeAttendance (
						EmpId
						,AttendanceDate
						,ShiftId
						,InFixed
						,OutFixed
						,ExpectedInTime
						,ExpectedOutTime
						,LateIn
						,EarlyOut
						,LeaveTypeId
						,Absence
						,TotalWorkHours
						,IsRightShift
						,LeaveDay
						,InsertDate
						)
					VALUES (
						@empId
						,@attendaceDate
						,@ShiftId
						,@InOfMachine
						,@OutOfMachine
						,@ExpectedInTime
						,@ExpectedOutTime
						,@ActualLateIn
						,@ActualEarlyOut
						,@LeaveTypeId
						,@Absence
						,@TotalWorkHours
						,@IsRightShift
						,@LeaveDay
						,GETDATE()
						)
				END
			END
			ELSE
			BEGIN
				DELETE
				FROM dbo.EmployeeAttendance WITH (ROWLOCK)
				WHERE EmpId = @empId
					AND AttendanceDate = CAST(@attendaceDate AS DATETIME)
			END
		END

		SET @i = @i + 1
		SET @attendaceDate = DATEADD(d, @i, @fromTime)
	END
END