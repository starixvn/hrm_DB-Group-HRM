/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_EmployeeCalendar_UpdateOffDay] @RequestId BIGINT
AS
/*
    Created: Tim.Trinh@2021-08-03
    Task: update off day
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EmpId INT
		,@LeaveTypeId INT
		,@FromDate DATE
		,@ToDate DATE
		,@tempFromDate DATETIME
		,@tempToDate DATETIME
		,@OffDaysbyWeek TINYINT
		,@DefaultDateFirst TINYINT = @@datefirst
		-- leave type 
		,@UnpaidLeave TINYINT = 25
		,@UnpaidLeaveInsurance TINYINT = 41
		,@PaternityLeave TINYINT = 14
		,@MaternityLeave TINYINT = 12

	SELECT @EmpId = EmpId
		,@FromDate = FromDate
		,@ToDate = ToDate
		,@LeaveTypeId = LeaveType
	FROM dbo.LeaveRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId

	IF @LeaveTypeId NOT IN (@UnpaidLeave, @UnpaidLeaveInsurance, @PaternityLeave, @MaternityLeave)
		OR @ToDate < DATEADD(DAY, - 1, (DATEADD(MONTH, 1, @FromDate)))
	BEGIN
		RETURN
	END

	CREATE TABLE #tblUpdateOffDay (WorkDate DATE)

	SET DATEFIRST 1 -- monday
	SET @FromDate = DATEADD(DAY, - 1 * (6 + DATEPART(dw, @FromDate)) % 7, @FromDate)
	SET @ToDate = DATEADD(DAY, 7 - DATEPART(dw, @ToDate), @ToDate)
	SET DATEFIRST @DefaultDateFirst

	EXEC dbo.EmployeeCalendar_Insert @EmpId = @EmpId
		,@fromdate = @FromDate
		,@todate = @ToDate

	SELECT @OffDaysbyWeek = OffDaysbyWeek
	FROM dbo.EmployeeSummary WITH (NOLOCK)
	WHERE EmpId = @empId

	WHILE @FromDate < @ToDate
	BEGIN
		SET @tempFromDate = @FromDate
		SET @tempToDate = DATEADD(DAY, 6, @tempFromDate)

		DECLARE @TotalOffDaysUsed TINYINT = 0
			,@OffDayLeft TINYINT = 0
		DECLARE @tblOffDay TABLE (WorkDate DATETIME)

		SELECT @TotalOffDaysUsed = COUNT(1)
		FROM dbo.EmployeeCalendar WITH (NOLOCK)
		WHERE EmpId = @empId
			AND WorkDate BETWEEN @tempFromDate
				AND @tempToDate
			AND IsOffDay = 1

		SET @OffDayLeft = @OffDaysbyWeek - @TotalOffDaysUsed

		IF @OffDayLeft > 0
		BEGIN
			INSERT INTO @tblOffDay (WorkDate)
			SELECT DISTINCT empca.WorkDate
			FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
				LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON empca.EmpId = att.EmpId
				AND empca.WorkDate = att.AttendanceDate
			WHERE empca.WorkDate BETWEEN @tempFromDate AND @tempToDate
				AND empca.EmpId = @EmpId
				AND empca.IsOffDay = 0
				AND empca.IsLeaveDay = 0
				AND empca.IsHoliday = 0
				AND empca.IsKeepInView = 0
				AND (
					att.EmpId IS NULL
					OR (
						att.InFixed IS NULL
						AND att.OutFixed IS NULL
						)
					)

			WHILE @OffDayLeft > 0
				AND EXISTS (
					SELECT 1
					FROM @tblOffDay
					)
			BEGIN
				DECLARE @tempWorkDate DATE

				SELECT @tempWorkDate = MAX(WorkDate)
				FROM @tblOffDay

				INSERT INTO #tblUpdateOffDay (WorkDate)
				VALUES (@tempWorkDate)

				DELETE
				FROM @tblOffDay
				WHERE WorkDate = @tempWorkDate

				SET @OffDayLeft = @OffDayLeft - 1
			END
		END

		SET @FromDate = DATEADD(DAY, 7, @FromDate)
	END

	UPDATE dbo.EmployeeCalendar WITH (ROWLOCK)
	SET IsOffDay = 1
		,ShiftId = NULL
	WHERE EmpId = @empId
		AND WorkDate IN (
			SELECT WorkDate
			FROM #tblUpdateOffDay WITH (NOLOCK)
			)

	DROP TABLE #tblUpdateOffDay
END