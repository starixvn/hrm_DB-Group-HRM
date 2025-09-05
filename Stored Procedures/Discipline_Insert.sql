/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Discipline_Insert]
(
    @FromDate DATETIME
    ,@ToDate DATETIME
    ,@EmpId INT = NULL
)
AS
/*
    Created: 20160418@Quinn.Vo
    Task: insert discipline.
    DB: bodb_HRM

    Revisions:
		- 20250829@Jay.Do: restructure: #233310 
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SyncFromDate DATETIME = '2016-01-01 00:00:00.000'
	DECLARE @ModifiedDate DATETIME = GETDATE()
		,@TotalWorkHoursWeekend_CheckInAfterDay DECIMAL(18, 2) = 11
		,@TotalWorkHoursWeekend DECIMAL(18, 2) = 9.75
		,@TotalWorkHours DECIMAL(18, 2) = 7
		,@LateInMins INT = 0
		,@EarlyOutMins INT = 15
		,@AnnualLeaveType INT = 2
		,@UnpaidLeaveType INT = 25
		,@GeneralLeaveType INT = 0
		,@KeepInViewLeaveType INT = 10
		,@PublicHolidayLeaveType INT = 13

    CREATE TABLE #tmpEmployeeAttendance (
        AttendanceDate DATETIME, EmpId INT, ShiftId INT
        ,InFixed DATETIME, OutFixed DATETIME
        ,ExpectedInTime DATETIME, ExpectedOutTime DATETIME
        ,LateIn INT, EarlyOut INT, TotalWorkHours DECIMAL(18, 2), LeaveDay DECIMAL(18, 2)
        ,PRIMARY KEY(AttendanceDate, EmpId)
    )

    INSERT INTO #tmpEmployeeAttendance (AttendanceDate, EmpId, ShiftId, InFixed, OutFixed, ExpectedInTime, ExpectedOutTime, LateIn, EarlyOut, TotalWorkHours, LeaveDay)
    SELECT AttendanceDate, EmpId, ShiftId, InFixed, OutFixed, ExpectedInTime, ExpectedOutTime, LateIn, EarlyOut, TotalWorkHours, ISNULL(LeaveDay, 0)
    FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
	WHERE att.AttendanceDate >= @SyncFromDate
		AND (@EmpId IS NULL OR att.EmpId = @EmpId)
		AND att.AttendanceDate BETWEEN @FromDate AND @ToDate
    --
    CREATE TABLE #tmpEmployeeCalendar (
        WorkDate DATETIME, EmpId INT, ShiftId INT
        ,IsOffDay BIT, LeaveDay DECIMAL (18, 1)
        ,PRIMARY KEY(WorkDate, EmpId)
    )

    INSERT INTO #tmpEmployeeCalendar (WorkDate, EmpId, ShiftId, IsOffDay, LeaveDay)
    SELECT WorkDate, EmpId, ShiftId, ISNULL(IsOffDay, 0), LeaveDay
    FROM dbo.EmployeeCalendar WITH (NOLOCK)
    WHERE (@EmpId IS NULL OR EmpId = @EmpId)
		AND WorkDate BETWEEN @FromDate AND @ToDate
    --
    CREATE TABLE #tmpDisciplineRequestTrans (EmpId INT, WorkDate DATE, RequestId BIGINT, DisciplineTypeId INT, IsIgnored BIT, IsOutOfControl BIT)
    CREATE NONCLUSTERED INDEX IX_tmpDisciplineRequestTrans_EmpId_WorkDate_DisciplineTypeId
    ON #tmpDisciplineRequestTrans (EmpId, WorkDate, DisciplineTypeId)

    INSERT INTO #tmpDisciplineRequestTrans (EmpId, WorkDate, RequestId, DisciplineTypeId, IsIgnored, IsOutOfControl)
    SELECT EmpId, WorkDate, RequestId, DisciplineTypeId, IsIgnored, IsOutOfControl
    FROM dbo.DisciplineRequestTrans WITH (NOLOCK)
	WHERE (
			@EmpId IS NULL
			OR EmpId = @EmpId
			)
		AND WorkDate >= CAST(@SyncFromDate AS DATE)
		AND WorkDate BETWEEN CAST(@FromDate AS DATE) AND CAST(@ToDate AS DATE)

	-- missing check in/out
	CREATE TABLE #tblMissingCheckInOutDiscipline (EmpId INT, WorkDate DATE, IsIgnored BIT, IsOutOfControl BIT, PRIMARY KEY(EmpId, WorkDate))

	INSERT INTO #tblMissingCheckInOutDiscipline (EmpId, WorkDate, IsIgnored, IsOutOfControl)
	SELECT EmpId
		,WorkDate
		,CASE 
			WHEN SUM(CASE WHEN IsIgnored = 0 THEN 1 ELSE 0 END) > 0 THEN 0
			ELSE 1 END
		,CASE 
			WHEN SUM(CASE WHEN IsOutOfControl = 0 THEN 1 ELSE 0 END) > 0 THEN 0
			ELSE 1 END
	FROM #tmpDisciplineRequestTrans
	WHERE DisciplineTypeId = 2
	GROUP BY EmpId
		,WorkDate
	
	UNION
	SELECT att.EmpId, att.AttendanceDate, 0, 0
	FROM #tmpEmployeeAttendance AS att
        INNER JOIN #tmpEmployeeCalendar AS empca ON att.EmpId = empca.EmpId
        AND att.AttendanceDate = empca.WorkDate
		AND empca.LeaveDay <> 1
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON att.EmpId = ce.EmpId
        INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		INNER JOIN dbo.DisciplineGroupRule AS rul WITH (NOLOCK) ON ce.GroupId = rul.GroupId
        AND es.IsLocal = rul.IsLocal
        AND rul.DisciplineTypeId = 2
		AND rul.[Value] = 1
	WHERE att.ShiftId IS NOT NULL
		AND (
			(
				att.InFixed IS NULL
				AND att.OutFixed IS NOT NULL
				AND @ModifiedDate > att.ExpectedInTime
				)
			OR (
				att.InFixed IS NOT NULL
				AND att.OutFixed IS NULL
				AND @ModifiedDate > att.ExpectedOutTime
				)
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tmpDisciplineRequestTrans AS drt
			WHERE drt.EmpId = att.EmpId
				AND drt.WorkDate = CAST(att.AttendanceDate AS DATE)
				AND drt.DisciplineTypeId = 2
			)

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblMissingCheckInOutDiscipline AS dis
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredMissingCheckInOut = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 2
	WHERE dis.IsIgnored = 0

	-- late in
	CREATE TABLE #tblLateInDiscipline (
		EmpId INT
		,WorkDate DATE
		,IsIgnored BIT
		,IsOutOfControl BIT
		)

	INSERT INTO #tblLateInDiscipline (
		EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
		)
	SELECT EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
	FROM #tmpDisciplineRequestTrans
	WHERE DisciplineTypeId = 3
	
	UNION
	SELECT empatt.EmpId
		,AttendanceDate
		,0
		,0
	FROM #tmpEmployeeAttendance AS empatt
		INNER JOIN #tmpEmployeeCalendar AS empca ON empatt.EmpId = empca.EmpId
		AND empatt.AttendanceDate = empca.WorkDate
		AND empca.LeaveDay <> 1
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON empatt.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		INNER JOIN dbo.DisciplineGroupRule AS rul WITH (NOLOCK) ON ce.GroupId = rul.GroupId
		AND es.IsLocal = rul.IsLocal
		AND rul.DisciplineTypeId = 3
		AND rul.Value = 1
	WHERE empatt.ShiftId IS NOT NULL
		AND empatt.LateIn > @LateInMins
		AND NOT EXISTS (
			SELECT 1
			FROM #tmpDisciplineRequestTrans
			WHERE EmpId = empatt.EmpId
				AND WorkDate = CAST(empatt.AttendanceDate AS DATE)
				AND DisciplineTypeId = 3
			)

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblLateInDiscipline AS dis WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredLateIn = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 3
	WHERE dis.IsIgnored = 0

	-- early out
	CREATE TABLE #tblEarlyOutDiscipline (
		EmpId INT
		,WorkDate DATE
		,IsIgnored BIT
		,IsOutOfControl BIT
		)

	INSERT INTO #tblEarlyOutDiscipline (
		EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
		)
	SELECT EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
	FROM #tmpDisciplineRequestTrans
	WHERE DisciplineTypeId = 4
	
	UNION
	SELECT empatt.EmpId
		,AttendanceDate
		,0
		,0
	FROM #tmpEmployeeAttendance AS empatt
		INNER JOIN #tmpEmployeeCalendar AS empca ON empatt.EmpId = empca.EmpId
		AND empatt.AttendanceDate = empca.WorkDate
		AND empca.LeaveDay <> 1
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON empatt.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		INNER JOIN dbo.DisciplineGroupRule AS rul WITH (NOLOCK) ON ce.GroupId = rul.GroupId
		AND es.IsLocal = rul.IsLocal
		AND rul.DisciplineTypeId = 4
		AND rul.Value = 1
	WHERE empatt.ShiftId IS NOT NULL
		AND empca.IsOffDay = 0
		AND empatt.EarlyOut > @EarlyOutMins
		AND NOT EXISTS (
			SELECT 1
			FROM #tmpDisciplineRequestTrans
			WHERE EmpId = empatt.EmpId
				AND WorkDate = CAST(empatt.AttendanceDate AS DATE)
				AND DisciplineTypeId = 4
			)

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblEarlyOutDiscipline AS dis WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredEarlyOut = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 4
	WHERE dis.IsIgnored = 0

	-- change shift
	CREATE TABLE #tblChangeShiftDiscipline (
		EmpId INT
		,WorkDate DATE
		,IsIgnored BIT
		,IsOutOfControl BIT
		)

	INSERT INTO #tblChangeShiftDiscipline (
		EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
		)
	SELECT EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
	FROM #tmpDisciplineRequestTrans
	WHERE DisciplineTypeId = 1

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblChangeShiftDiscipline AS dis WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredChangeShift = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 1
	WHERE dis.IsIgnored = 0

	-- working under time
	CREATE TABLE #tblWorkingUnderTimeDiscipline (
		WorkDate DATE
		,EmpId INT
		,IsIgnored BIT
		,IsOutOfControl BIT
		)

	INSERT INTO #tblWorkingUnderTimeDiscipline (
		WorkDate
		,EmpId
		,IsIgnored
		,IsOutOfControl
		)
	SELECT AttendanceDate
		,empatt.EmpId
		,0
		,0
	FROM #tmpEmployeeAttendance AS empatt
		INNER JOIN #tmpEmployeeCalendar AS empca ON empatt.EmpId = empca.EmpId
		AND empatt.AttendanceDate = empca.WorkDate
		AND empca.LeaveDay <> 1
		INNER JOIN dbo.[Shift] AS s WITH (NOLOCK) ON empatt.ShiftId = s.ShiftId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON empatt.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		INNER JOIN dbo.DisciplineGroupRule AS rul WITH (NOLOCK) ON ce.GroupId = rul.GroupId
		AND es.IsLocal = rul.IsLocal
		AND rul.DisciplineTypeId = 7
		AND rul.Value = 1
	WHERE (
			(
				s.IsInAfterDay = 0
				AND (
					(
						DATEPART(DW, empatt.AttendanceDate) IN (1, 7) -- Sunday or Saturday
						AND empatt.TotalWorkHours < @TotalWorkHoursWeekend
						)
					OR (
						DATEPART(DW, empatt.AttendanceDate) NOT IN (1, 7)
						AND empatt.TotalWorkHours < @TotalWorkHours
						)
					)
				)
			OR (
				s.IsInAfterDay = 1
				AND (
					(
						DATEPART(DW, empatt.AttendanceDate) IN (1, 2) -- Sunday or Monday
						AND empatt.TotalWorkHours < @TotalWorkHoursWeekend_CheckInAfterDay
						)
					OR (
						DATEPART(DW, empatt.AttendanceDate) NOT IN (1, 2)
						AND empatt.TotalWorkHours < @TotalWorkHours
						)
					)
				)
			)

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblWorkingUnderTimeDiscipline AS dis WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredWorkingUnderTime = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 7
	WHERE dis.IsIgnored = 0

	-- unpaid leave absent
	CREATE TABLE #tblUnpaidLeaveAbsentDiscipline (
		EmpId INT
		,WorkDate DATE
		,IsIgnored BIT
		,IsOutOfControl BIT
		)

	INSERT INTO #tblUnpaidLeaveAbsentDiscipline (
		EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
		)
	SELECT EmpId
		,WorkDate
		,CASE 
			WHEN SUM(CASE 
						WHEN IsIgnored = 0 THEN 1
						ELSE 0
						END) > 0 THEN 0
			ELSE 1
			END
		,CASE 
			WHEN SUM(CASE 
						WHEN IsOutOfControl = 0 THEN 1
						ELSE 0
						END) > 0 THEN 0
			ELSE 1
			END
	FROM #tmpDisciplineRequestTrans
	WHERE DisciplineTypeId = 8
	GROUP BY EmpId
		,WorkDate	

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblUnpaidLeaveAbsentDiscipline AS dis WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredUnpaidLeaveAbsent = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 8
	WHERE dis.IsIgnored = 0

	-- absent
	CREATE TABLE #tblAbsentDiscipline (
		EmpId INT
		,WorkDate DATE
		,IsIgnored BIT
		,IsOutOfControl BIT
		)

	INSERT INTO #tblAbsentDiscipline (
		EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
		)
	SELECT EmpId
		,WorkDate
		,CASE 
			WHEN SUM(CASE 
						WHEN IsIgnored = 0 THEN 1
						ELSE 0
						END) > 0 THEN 0
			ELSE 1
			END
		,CASE 
			WHEN SUM(CASE 
						WHEN IsOutOfControl = 0 THEN 1
						ELSE 0
						END) > 0 THEN 0
			ELSE 1
			END
	FROM #tmpDisciplineRequestTrans AS drt
	WHERE DisciplineTypeId = 5
		AND NOT EXISTS (
			SELECT 1
			FROM #tblUnpaidLeaveAbsentDiscipline
			WHERE EmpId = drt.EmpId
				AND WorkDate = drt.WorkDate
			)
	GROUP BY EmpId
		,WorkDate
	
	UNION
	SELECT att.EmpId
		,att.AttendanceDate
		,0
		,0
	FROM #tmpEmployeeAttendance AS att
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON att.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		INNER JOIN dbo.DisciplineGroupRule AS rul WITH (NOLOCK) ON ce.GroupId = rul.GroupId
		AND es.IsLocal = rul.IsLocal
		AND rul.DisciplineTypeId = 5
		AND rul.Value = 1
	WHERE att.ShiftId IS NOT NULL
		AND att.InFixed IS NULL
		AND att.OutFixed IS NULL
		AND @ModifiedDate > att.ExpectedOutTime
		AND att.LeaveDay <> 1

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblAbsentDiscipline AS dis WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredAbsent = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 5
	WHERE dis.IsIgnored = 0

	-- unplanned leave
	CREATE TABLE #tblUnplannedDiscipline (
		EmpId INT
		,WorkDate DATE
		,IsIgnored BIT
		,IsOutOfControl BIT
		)

	INSERT INTO #tblUnplannedDiscipline (
		EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
		)
	SELECT EmpId
		,WorkDate
		,CASE 
			WHEN SUM(CASE 
						WHEN IsIgnored = 0 THEN 1
						ELSE 0
						END) > 0 THEN 0
			ELSE 1
			END
		,CASE 
			WHEN SUM(CASE 
						WHEN IsOutOfControl = 0 THEN 1
						ELSE 0
						END) > 0 THEN 0
			ELSE 1
			END
	FROM #tmpDisciplineRequestTrans AS drt
	WHERE DisciplineTypeId = 9
		AND NOT EXISTS (
			SELECT 1
			FROM #tblUnpaidLeaveAbsentDiscipline
			WHERE EmpId = drt.EmpId
				AND WorkDate = drt.WorkDate
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblAbsentDiscipline
			WHERE EmpId = drt.EmpId
				AND WorkDate = drt.WorkDate
			)
	GROUP BY EmpId
		,WorkDate

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblUnplannedDiscipline AS dis WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredUnplannedLeave = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 9
	WHERE dis.IsIgnored = 0

	-- unpaid leave
	CREATE TABLE #tblUnpaidLeaveDiscipline (
		EmpId INT
		,WorkDate DATE
		,IsIgnored BIT
		,IsOutOfControl BIT
		)

	INSERT INTO #tblUnpaidLeaveDiscipline (
		EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
		)
	SELECT EmpId
		,WorkDate
		,CASE 
			WHEN SUM(CASE 
						WHEN IsIgnored = 0 THEN 1
						ELSE 0
						END) > 0 THEN 0
			ELSE 1
			END
		,CASE 
			WHEN SUM(CASE 
						WHEN IsOutOfControl = 0 THEN 1
						ELSE 0
						END) > 0 THEN 0
			ELSE 1
			END
	FROM #tmpDisciplineRequestTrans AS drt
	WHERE DisciplineTypeId = 6
		AND NOT EXISTS (
			SELECT 1
			FROM #tblUnpaidLeaveAbsentDiscipline
			WHERE EmpId = drt.EmpId
				AND WorkDate = drt.WorkDate
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblAbsentDiscipline
			WHERE EmpId = drt.EmpId
				AND WorkDate = drt.WorkDate
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblUnplannedDiscipline
			WHERE EmpId = drt.EmpId
				AND WorkDate = drt.WorkDate
			)
	GROUP BY EmpId
		,WorkDate

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblUnpaidLeaveDiscipline AS dis WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredUnpaidLeave = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 6
	WHERE dis.IsIgnored = 0

	-- weekend leave
	CREATE TABLE #tblWeekendLeaveDiscipline (
		EmpId INT
		,WorkDate DATE
		,IsIgnored BIT
		,IsOutOfControl BIT
		)

	INSERT INTO #tblWeekendLeaveDiscipline (
		EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
		)
	SELECT EmpId
		,WorkDate
		,CASE 
			WHEN SUM(CASE WHEN IsIgnored = 0 THEN 1 ELSE 0 END) > 0 THEN 0
			ELSE 1 END
		,CASE 
			WHEN SUM(CASE WHEN IsOutOfControl = 0 THEN 1 ELSE 0 END) > 0 THEN 0
			ELSE 1 END
	FROM #tmpDisciplineRequestTrans AS drt
	WHERE DisciplineTypeId = 10
	GROUP BY EmpId
		,WorkDate

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblWeekendLeaveDiscipline AS dis WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredWeekendLeave = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 10
	WHERE dis.IsIgnored = 0

	-- seven days
	CREATE TABLE #tblSevenDaysLeaveDiscipline (
		EmpId INT
		,WorkDate DATE
		,IsIgnored BIT
		,IsOutOfControl BIT
		)

	INSERT INTO #tblSevenDaysLeaveDiscipline (
		EmpId
		,WorkDate
		,IsIgnored
		,IsOutOfControl
		)
	SELECT EmpId
		,WorkDate
		,CASE 
			WHEN SUM(CASE WHEN IsIgnored = 0 THEN 1 ELSE 0 END) > 0 THEN 0
			ELSE 1 END
		,CASE 
			WHEN SUM(CASE WHEN IsOutOfControl = 0 THEN 1 ELSE 0 END) > 0 THEN 0
			ELSE 1 END
	FROM #tmpDisciplineRequestTrans AS drt
	WHERE DisciplineTypeId = 11
	GROUP BY EmpId
		,WorkDate

	UPDATE dis
	SET dis.IsIgnored = 1
	FROM #tblSevenDaysLeaveDiscipline AS dis WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.DisciplineIgnore AS dig WITH (NOLOCK) ON dis.EmpId = dig.EmpId
		AND dis.WorkDate = dig.WorkDate
		AND dig.IsIgnoredSevenDaysLeave = 1
		INNER JOIN dbo.DisciplineIgnoreDetail AS dd WITH (NOLOCK) ON dis.EmpId = dd.EmpId
		AND dis.WorkDate = dd.WorkDate
		AND dd.DisciplineTypeId = 11
	WHERE dis.IsIgnored = 0

	--
	CREATE TABLE #tblDiscipline (
		[EmpId] [int] NOT NULL
		,[WorkDate] [date] NOT NULL
		,[DisciplineScore] [decimal](5, 2) NULL
		,[IsOutOfControlReason] [bit] NULL
		,[EmployeeComment] [nvarchar](MAX) NULL
		,[ApproverComment] [nvarchar](MAX) NULL
		,[IsMissingCheckInOut] [bit] NULL
		,[IsLateIn] [bit] NULL
		,[IsEarlyOut] [bit] NULL
		,[IsWorkingUndertime] [bit] NULL
		,[IsChangeShift] [bit] NULL
		,[IsAbsent] [bit] NULL
		,[IsUnpaidLeave] [bit] NULL
		,[IsUnpaidLeaveAbsent] [bit] NULL
		,[IsUnplannedLeave] [bit] NULL
		,[IsWeekendLeave] [bit] NULL
		,IsSevenDaysLeave BIT NULL
		,[IsIgnoredMissingCheckInOut] [bit] NULL
		,[IsIgnoredLateIn] [bit] NULL
		,[IsIgnoredEarlyOut] [bit] NULL
		,[IsIgnoredWorkingUndertime] [bit] NULL
		,[IsIgnoredChangeShift] [bit] NULL
		,[IsIgnoredAbsent] [bit] NULL
		,[IsIgnoredUnpaidLeave] [bit] NULL
		,[IsIgnoredUnpaidLeaveAbsent] [bit] NULL
		,[IsIgnoredUnplannedLeave] [bit] NULL
		,[IsIgnoredWeekendLeave] [bit] NULL
		,IsIgnoredSevenDaysLeave BIT NULL
		,[IsOutOfControlMissingCheckInOut] [bit] NULL
		,[IsOutOfControlLateIn] [bit] NULL
		,[IsOutOfControlEarlyOut] [bit] NULL
		,[IsOutOfControlWorkingUndertime] [bit] NULL
		,[IsOutOfControlChangeShift] [bit] NULL
		,[IsOutOfControlAbsent] [bit] NULL
		,[IsOutOfControlUnpaidLeave] [bit] NULL
		,[IsOutOfControlUnpaidLeaveAbsent] [bit] NULL
		,[IsOutOfControlUnplannedLeave] [bit] NULL
		,[IsOutOfControlWeekendLeave] [bit] NULL
		,IsOutOfControlSevenDaysLeave BIT NULL
		)

	INSERT #tblDiscipline (
		[EmpId]
		,[WorkDate]
		,[DisciplineScore]
		,[EmployeeComment]
		,[ApproverComment]
		,[IsMissingCheckInOut]
		,[IsLateIn]
		,[IsEarlyOut]
		,[IsWorkingUndertime]
		,[IsChangeShift]
		,[IsAbsent]
		,[IsUnpaidLeave]
		,[IsUnpaidLeaveAbsent]
		,[IsUnplannedLeave]
		,[IsWeekendLeave]
		,IsSevenDaysLeave
		,[IsIgnoredMissingCheckInOut]
		,[IsIgnoredLateIn]
		,[IsIgnoredEarlyOut]
		,[IsIgnoredWorkingUndertime]
		,[IsIgnoredChangeShift]
		,[IsIgnoredAbsent]
		,[IsIgnoredUnpaidLeave]
		,[IsIgnoredUnpaidLeaveAbsent]
		,[IsIgnoredUnplannedLeave]
		,[IsIgnoredWeekendLeave]
		,IsIgnoredSevenDaysLeave
		,[IsOutOfControlMissingCheckInOut]
		,[IsOutOfControlLateIn]
		,[IsOutOfControlEarlyOut]
		,[IsOutOfControlWorkingUndertime]
		,[IsOutOfControlChangeShift]
		,[IsOutOfControlAbsent]
		,[IsOutOfControlUnpaidLeave]
		,[IsOutOfControlUnpaidLeaveAbsent]
		,[IsOutOfControlUnplannedLeave]
		,[IsOutOfControlWeekendLeave]
		,IsOutOfControlSevenDaysLeave
		)
	SELECT ce.EmpId
		,cal.WorkDate
		,(CASE 
			WHEN (
					upla.EmpId IS NOT NULL
					AND ISNULL(upla.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(8)
			ELSE 0 END + CASE 
			WHEN (
					lateleave.EmpId IS NOT NULL
					AND ISNULL(lateleave.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(9)
			ELSE 0 END + CASE 
			WHEN (
					ab.EmpId IS NOT NULL
					AND upla.EmpId IS NULL
					AND ISNULL(ab.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(5)
			ELSE 0 END + CASE 
			WHEN (
					upl.EmpId IS NOT NULL
					AND upla.EmpId IS NULL
					AND ab.EmpId IS NULL
					AND ISNULL(upl.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(6)
			ELSE 0 END + CASE 
			WHEN (
					la.EmpId IS NOT NULL
					AND ISNULL(la.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(3)
			ELSE 0 END + CASE 
			WHEN (
					ear.EmpId IS NOT NULL
					AND ISNULL(ear.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(4)
			ELSE 0 END + CASE 
			WHEN (
					wud.EmpId IS NOT NULL
					AND ISNULL(wud.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(7)
			ELSE 0 END + CASE 
			WHEN (
					mis.EmpId IS NOT NULL
					AND ISNULL(mis.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(2)
			ELSE 0 END + CASE 
			WHEN (
					changeshift.EmpId IS NOT NULL
					AND ISNULL(changeshift.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(1)
			ELSE 0 END + CASE 
			WHEN (
					wld.EmpId IS NOT NULL
					AND ISNULL(wld.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(10)
			ELSE 0 END + CASE 
			WHEN (
					lateleave.EmpId IS NULL
					AND sevendays.EmpId IS NOT NULL
					AND ISNULL(sevendays.IsIgnored, 0) = 0
					) THEN dbo.fncGetDisciplineScoreById(11)
			ELSE 0 END
			)
		,(
			SELECT CASE 
					WHEN rq.Remark <> '' THEN ('- ' + dt.[Name] + ': ' + rq.Remark + '. ')
					ELSE ''
					END
			FROM #tmpDisciplineRequestTrans AS drt
				INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON drt.RequestId = rq.RequestId
				INNER JOIN dbo.DisciplineType AS dt WITH (NOLOCK) ON drt.DisciplineTypeId = dt.DisciplineTypeId
			WHERE drt.EmpId = cal.EmpId
				AND drt.WorkDate = cal.WorkDate
			FOR XML PATH('')
			) AS EmployeeComment
		,(
			SELECT CASE 
					WHEN rq.ApproverComment <> '' THEN ('- ' + dt.[Name] + ': ' + rq.ApproverComment + '. ')
					ELSE ''
					END
			FROM #tmpDisciplineRequestTrans AS drt WITH (NOLOCK)
				INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON drt.RequestId = rq.RequestId
				INNER JOIN dbo.DisciplineType AS dt WITH (NOLOCK) ON drt.DisciplineTypeId = dt.DisciplineTypeId
			WHERE drt.EmpId = cal.EmpId
				AND drt.WorkDate = cal.WorkDate
			FOR XML PATH('')
			) AS ApproverComment
		,CASE 
			WHEN mis.EmpId IS NULL THEN 0
			ELSE 1
			END
		,CASE 
			WHEN la.EmpId IS NULL THEN 0
			ELSE 1
			END
		,CASE 
			WHEN ear.EmpId IS NULL THEN 0
			ELSE 1
			END
		,CASE 
			WHEN wud.EmpId IS NULL THEN 0
			ELSE 1
			END
		,CASE 
			WHEN changeshift.EmpId IS NULL THEN 0
			ELSE 1
			END
		,CASE 
			WHEN upla.EmpId IS NOT NULL
				OR ab.EmpId IS NULL THEN 0
			ELSE 1
			END
		,CASE 
			WHEN upla.EmpId IS NOT NULL
				OR ab.EmpId IS NOT NULL
				OR sevendays.EmpId IS NOT NULL
				OR upl.EmpId IS NULL THEN 0
			ELSE 1
			END
		,CASE 
			WHEN upla.EmpId IS NULL THEN 0
			ELSE 1
			END
		,CASE 
			WHEN lateleave.EmpId IS NULL THEN 0
			ELSE 1
			END
		,CASE 
			WHEN wld.EmpId IS NULL THEN 0
			ELSE 1
			END
		,CASE 
			WHEN lateleave.EmpId IS NOT NULL
				OR sevendays.EmpId IS NULL THEN 0
			ELSE 1
			END
		,ISNULL(mis.IsIgnored, 0)
		,ISNULL(la.IsIgnored, 0)
		,ISNULL(ear.IsIgnored, 0)
		,ISNULL(wud.IsIgnored, 0)
		,ISNULL(changeshift.IsIgnored, 0)
		,ISNULL(ab.IsIgnored, 0)
		,ISNULL(upl.IsIgnored, 0)
		,ISNULL(upla.IsIgnored, 0)
		,ISNULL(lateleave.IsIgnored, 0)
		,ISNULL(wld.IsIgnored, 0)
		,ISNULL(sevendays.IsIgnored, 0)
		,ISNULL(mis.IsOutOfControl, 0)
		,ISNULL(la.IsOutOfControl, 0)
		,ISNULL(ear.IsOutOfControl, 0)
		,ISNULL(wud.IsOutOfControl, 0)
		,ISNULL(changeshift.IsOutOfControl, 0)
		,ISNULL(ab.IsOutOfControl, 0)
		,ISNULL(upl.IsOutOfControl, 0)
		,ISNULL(upla.IsOutOfControl, 0)
		,ISNULL(lateleave.IsOutOfControl, 0)
		,ISNULL(wld.IsOutOfControl, 0)
		,ISNULL(sevendays.IsOutOfControl, 0)
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN #tmpEmployeeCalendar AS cal WITH (NOLOCK) ON ce.EmpId = cal.EmpId
		LEFT JOIN #tmpEmployeeAttendance AS att ON ce.EmpId = att.EmpId
		AND cal.WorkDate = att.AttendanceDate
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cal.ShiftId = sh.ShiftId
		LEFT JOIN #tblUnpaidLeaveAbsentDiscipline AS upla ON ce.EmpId = upla.EmpId
		AND cal.WorkDate = upla.WorkDate
		LEFT JOIN #tblAbsentDiscipline AS ab ON ce.EmpId = ab.EmpId
		AND cal.WorkDate = ab.WorkDate
		LEFT JOIN #tblUnplannedDiscipline AS lateleave ON ce.EmpId = lateleave.EmpId
		AND cal.WorkDate = lateleave.WorkDate
		LEFT JOIN #tblUnpaidLeaveDiscipline AS upl ON ce.EmpId = upl.EmpId
		AND cal.WorkDate = upl.WorkDate
		LEFT JOIN #tblWeekendLeaveDiscipline AS wld ON ce.EmpId = wld.EmpId
		AND cal.WorkDate = wld.WorkDate
		LEFT JOIN #tblLateInDiscipline AS la ON ce.EmpId = la.EmpId
		AND cal.WorkDate = la.WorkDate
		LEFT JOIN #tblEarlyOutDiscipline AS ear ON ce.EmpId = ear.EmpId
		AND cal.WorkDate = ear.WorkDate
		LEFT JOIN #tblWorkingUnderTimeDiscipline AS wud ON ce.EmpId = wud.EmpId
		AND cal.WorkDate = wud.WorkDate
		LEFT JOIN #tblMissingCheckInOutDiscipline AS mis ON ce.EmpId = mis.EmpId
		AND cal.WorkDate = mis.WorkDate
		LEFT JOIN #tblChangeShiftDiscipline AS changeshift ON ce.EmpId = changeshift.EmpId
		AND cal.WorkDate = changeshift.WorkDate
		LEFT JOIN #tblSevenDaysLeaveDiscipline AS sevendays ON ce.EmpId = sevendays.EmpId
		AND cal.WorkDate = sevendays.WorkDate
	WHERE ISNULL(ce.isDeleted, 0) = 0
		AND ce.[Enabled] = 1
		AND cal.WorkDate >= @SyncFromDate
		AND (
			upla.EmpId IS NOT NULL
			OR upl.EmpId IS NOT NULL
			OR ab.EmpId IS NOT NULL
			OR lateleave.EmpId IS NOT NULL
			OR wld.EmpId IS NOT NULL
			OR la.EmpId IS NOT NULL
			OR ear.EmpId IS NOT NULL
			OR wud.EmpId IS NOT NULL
			OR mis.EmpId IS NOT NULL
			OR changeshift.EmpId IS NOT NULL
			OR sevendays.EmpId IS NOT NULL
			)

	UPDATE edi
	SET edi.DisciplineScore = dis.DisciplineScore
		,edi.EmployeeComment = dis.EmployeeComment
		,edi.ApproverComment = dis.ApproverComment
		,edi.IsMissingCheckInOut = dis.IsMissingCheckInOut
		,edi.IsLateIn = dis.IsLateIn
		,edi.IsEarlyOut = dis.IsEarlyOut
		,edi.IsWorkingUndertime = dis.IsWorkingUndertime
		,edi.IsChangeShift = dis.IsChangeShift
		,edi.IsAbsent = dis.IsAbsent
		,edi.IsUnplannedLeave = dis.IsUnplannedLeave
		,edi.IsUnpaidLeave = dis.IsUnpaidLeave
		,edi.IsUnpaidLeaveAbsent = dis.IsUnpaidLeaveAbsent
		,edi.IsWeekendLeave = dis.IsWeekendLeave
		,edi.IsSevenDaysLeave = dis.IsSevenDaysLeave
		,edi.IsDeleted = 0
		,edi.ModifiedDate = @ModifiedDate
	FROM dbo.Discipline AS edi WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblDiscipline AS dis ON edi.EmpId = dis.EmpId
		AND edi.WorkDate = dis.WorkDate

	UPDATE edi
	SET edi.IsMissingCheckInOut = 0
		,edi.IsLateIn = 0
		,edi.IsEarlyOut = 0
		,edi.IsChangeShift = 0
		,edi.IsAbsent = 0
		,edi.IsUnplannedLeave = 0
		,edi.IsUnpaidLeave = 0
		,edi.IsUnpaidLeaveAbsent = 0
		,edi.IsWeekendLeave = 0
		,edi.IsSevenDaysLeave = 0
		,edi.IsDeleted = 1
		,edi.ModifiedDate = @ModifiedDate
	FROM dbo.Discipline AS edi WITH (ROWLOCK, UPDLOCK)
	WHERE NOT EXISTS (
			SELECT 1
			FROM #tblDiscipline
			WHERE edi.EmpId = EmpId
				AND edi.WorkDate = WorkDate
			)
		AND edi.WorkDate BETWEEN CAST(@FromDate AS DATE) AND CAST(@ToDate AS DATE)
		AND (@EmpId IS NULL OR edi.EmpId = @EmpId)

	INSERT dbo.Discipline (
		EmpId
		,[WorkDate]
		,[DisciplineScore]
		,[EmployeeComment]
		,[ApproverComment]
		,[IsMissingCheckInOut]
		,[IsLateIn]
		,[IsEarlyOut]
		,[IsWorkingUndertime]
		,[IsChangeShift]
		,[IsAbsent]
		,[IsUnplannedLeave]
		,[IsUnpaidLeave]
		,[IsUnpaidLeaveAbsent]
		,[IsWeekendLeave]
		,IsSevenDaysLeave
		,[IsDeleted]
		,[ModifiedBy]
		,[ModifiedDate]
		)
	SELECT dis.EmpId
		,dis.WorkDate
		,dis.DisciplineScore
		,dis.EmployeeComment
		,dis.ApproverComment
		,dis.IsMissingCheckInOut
		,dis.IsLateIn
		,dis.IsEarlyOut
		,dis.IsWorkingUndertime
		,dis.IsChangeShift
		,dis.IsAbsent
		,dis.IsUnplannedLeave
		,dis.IsUnpaidLeave
		,dis.IsUnpaidLeaveAbsent
		,dis.IsWeekendLeave
		,dis.IsSevenDaysLeave
		,0
		,NULL
		,@ModifiedDate
	FROM #tblDiscipline AS dis WITH (NOLOCK)
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.Discipline WITH (NOLOCK)
			WHERE EmpId = dis.EmpId
				AND WorkDate = dis.WorkDate
			)

	UPDATE di
	SET di.IsIgnoredMissingCheckInOut = dis.IsIgnoredMissingCheckInOut
		,di.IsIgnoredLateIn = dis.IsIgnoredLateIn
		,di.IsIgnoredEarlyOut = dis.IsIgnoredEarlyOut
		,di.IsIgnoredWorkingUndertime = dis.IsIgnoredWorkingUndertime
		,di.IsIgnoredChangeShift = dis.IsIgnoredChangeShift
		,di.IsIgnoredAbsent = dis.IsIgnoredAbsent
		,di.IsIgnoredUnplannedLeave = dis.IsIgnoredUnplannedLeave
		,di.IsIgnoredUnpaidLeave = dis.IsIgnoredUnpaidLeave
		,di.IsIgnoredUnpaidLeaveAbsent = dis.IsIgnoredUnpaidLeaveAbsent
		,di.IsIgnoredWeekendLeave = dis.IsIgnoredWeekendLeave
		,di.IsIgnoredSevenDaysLeave = dis.IsIgnoredSevenDaysLeave
	FROM dbo.DisciplineIgnore AS di WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblDiscipline AS dis ON di.EmpId = dis.EmpId
		AND di.WorkDate = dis.WorkDate

	DELETE di
	FROM dbo.DisciplineIgnore AS di WITH (ROWLOCK, UPDLOCK)
	WHERE NOT EXISTS (
			SELECT 1
			FROM #tblDiscipline
			WHERE di.EmpId = EmpId
				AND di.WorkDate = WorkDate
			)
		AND di.WorkDate BETWEEN CAST(@FromDate AS DATE) AND CAST(@ToDate AS DATE)
		AND (@EmpId IS NULL OR di.EmpId = @EmpId)

	INSERT INTO dbo.DisciplineIgnore (
		EmpId
		,WorkDate
		,IsIgnoredMissingCheckInOut
		,IsIgnoredLateIn
		,IsIgnoredEarlyOut
		,IsIgnoredWorkingUndertime
		,IsIgnoredChangeShift
		,IsIgnoredAbsent
		,IsIgnoredUnplannedLeave
		,IsIgnoredUnpaidLeave
		,IsIgnoredUnpaidLeaveAbsent
		,IsIgnoredWeekendLeave
		,IsIgnoredSevenDaysLeave
		)
	SELECT EmpId
		,WorkDate
		,IsIgnoredMissingCheckInOut
		,IsIgnoredLateIn
		,IsIgnoredEarlyOut
		,IsIgnoredWorkingUndertime
		,IsIgnoredChangeShift
		,IsIgnoredAbsent
		,IsIgnoredUnplannedLeave
		,IsIgnoredUnpaidLeave
		,IsIgnoredUnpaidLeaveAbsent
		,IsIgnoredWeekendLeave
		,IsIgnoredSevenDaysLeave
	FROM #tblDiscipline AS dis
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.DisciplineIgnore WITH (NOLOCK)
			WHERE EmpId = dis.EmpId
				AND WorkDate = dis.WorkDate
			)

	UPDATE doc
	SET doc.IsOutOfControlMissingCheckInOut = dis.IsOutOfControlMissingCheckInOut
		,doc.IsOutOfControlLateIn = dis.IsOutOfControlLateIn
		,doc.IsOutOfControlEarlyOut = dis.IsOutOfControlEarlyOut
		,doc.IsOutOfControlWorkingUndertime = dis.IsOutOfControlWorkingUndertime
		,doc.IsOutOfControlChangeShift = dis.IsOutOfControlChangeShift
		,doc.IsOutOfControlAbsent = dis.IsOutOfControlAbsent
		,doc.IsOutOfControlUnplannedLeave = dis.IsOutOfControlUnplannedLeave
		,doc.IsOutOfControlUnpaidLeave = dis.IsOutOfControlUnpaidLeave
		,doc.IsOutOfControlUnpaidLeaveAbsent = dis.IsOutOfControlUnpaidLeaveAbsent
		,doc.IsOutOfControlWeekendLeave = dis.IsOutOfControlWeekendLeave
		,doc.IsOutOfControlSevenDaysLeave = dis.IsOutOfControlSevenDaysLeave
	FROM dbo.DisciplineOutOfControl AS doc WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblDiscipline AS dis ON doc.EmpId = dis.EmpId
		AND doc.WorkDate = dis.WorkDate

	DELETE doc
	FROM dbo.DisciplineOutOfControl AS doc WITH (ROWLOCK, UPDLOCK)
	WHERE NOT EXISTS (
			SELECT 1
			FROM #tblDiscipline
			WHERE doc.EmpId = EmpId
				AND doc.WorkDate = WorkDate
			)
		AND doc.WorkDate BETWEEN CAST(@FromDate AS DATE) AND CAST(@ToDate AS DATE)
		AND (@EmpId IS NULL OR doc.EmpId = @EmpId)

	INSERT INTO dbo.DisciplineOutOfControl (
		EmpId
		,WorkDate
		,IsOutOfControlMissingCheckInOut
		,IsOutOfControlLateIn
		,IsOutOfControlEarlyOut
		,IsOutOfControlWorkingUndertime
		,IsOutOfControlChangeShift
		,IsOutOfControlAbsent
		,IsOutOfControlUnplannedLeave
		,IsOutOfControlUnpaidLeave
		,IsOutOfControlUnpaidLeaveAbsent
		,IsOutOfControlWeekendLeave
		,IsOutOfControlSevenDaysLeave
		)
	SELECT EmpId
		,WorkDate
		,IsOutOfControlMissingCheckInOut
		,IsOutOfControlLateIn
		,IsOutOfControlEarlyOut
		,IsOutOfControlWorkingUndertime
		,IsOutOfControlChangeShift
		,IsOutOfControlAbsent
		,IsOutOfControlUnplannedLeave
		,IsOutOfControlUnpaidLeave
		,IsOutOfControlUnpaidLeaveAbsent
		,IsOutOfControlWeekendLeave
		,IsOutOfControlSevenDaysLeave
	FROM #tblDiscipline AS dis
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.DisciplineOutOfControl WITH (NOLOCK)
			WHERE EmpId = dis.EmpId
				AND WorkDate = dis.WorkDate
			)

    DROP TABLE #tmpEmployeeAttendance

    DROP TABLE #tmpEmployeeCalendar

    DROP TABLE #tmpDisciplineRequestTrans

	DROP TABLE #tblMissingCheckInOutDiscipline

	DROP TABLE #tblLateInDiscipline

	DROP TABLE #tblEarlyOutDiscipline

	DROP TABLE #tblChangeShiftDiscipline

	DROP TABLE #tblWorkingUnderTimeDiscipline

	DROP TABLE #tblUnpaidLeaveAbsentDiscipline

	DROP TABLE #tblAbsentDiscipline

	DROP TABLE #tblUnplannedDiscipline

	DROP TABLE #tblUnpaidLeaveDiscipline

	DROP TABLE #tblWeekendLeaveDiscipline

	DROP TABLE #tblSevenDaysLeaveDiscipline

	DROP TABLE #tblDiscipline
END