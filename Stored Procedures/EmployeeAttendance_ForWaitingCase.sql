/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeAttendance_ForWaitingCase] @CompanyId SMALLINT = NULL
AS
/*
Created:
Task:
DB: HRM

Revisions:

*/
BEGIN
	SET XACT_ABORT ON;

	DECLARE @i INT
		,@TempEmpId INT
		,@TempWorkDate DATE
		,@TempShiftId INT
		,@fromDate DATE
		,@toDate DATE
        ,@serverTimeZone SMALLINT = -4
	CREATE TABLE #tmpEmployee (Id INT PRIMARY KEY IDENTITY(1, 1), EmpId INT, CompanyId SMALLINT, WorkDate DATE)

	SELECT @fromDate = MIN(att.WorkDate)
		,@toDate = MAX(att.WorkDate)
	FROM dbo.tmpEmployeeAttendace AS att WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON att.EmpId = ce.EmpId
    WHERE @CompanyId IS NULL
        OR ce.CompanyId = @CompanyId

	INSERT INTO #tmpEmployee (EmpId, CompanyId, WorkDate)
	SELECT TOP 100 att.EmpId
		,ce.CompanyId
        ,att.WorkDate
	FROM dbo.tmpEmployeeAttendace AS att WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON att.EmpId = ce.EmpId
    WHERE @CompanyId IS NULL
        OR ce.CompanyId = @CompanyId

	DELETE tmp
	FROM dbo.tmpEmployeeAttendace AS tmp WITH (ROWLOCK)
		INNER JOIN #tmpEmployee AS e WITH (NOLOCK) ON tmp.EmpId = e.EmpId
	WHERE tmp.WorkDate = e.WorkDate

	IF EXISTS (
			SELECT 1
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpTimeRecord'
			)
	BEGIN
		DROP TABLE #tmpTimeRecord
	END

	CREATE TABLE #tmpTimeRecord (Id INT, EmpId INT, RecordTime DATETIME, InOutType TINYINT)

	-- Get all in/out data into temp table to calculate
	INSERT INTO #tmpTimeRecord (Id, EmpId, RecordTime, InOutType)
	SELECT ti.Id, ti.EmpId, ti.RecordTime, ti.InOutType
	FROM dbo.TimeRecord AS ti WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ti.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'
	WHERE DATEADD(HOUR, CAST(ISNULL(config.Value, @serverTimeZone) AS REAL) * 60, DATEADD(HOUR, ABS(@serverTimeZone), ti.RecordTime))
        BETWEEN DATEADD(HH, - 2, CONVERT(VARCHAR(10), @fromDate, 111)) AND DATEADD(d, 2, CONVERT(VARCHAR(10), @toDate, 111))
		AND EXISTS (
			SELECT 1
			FROM #tmpEmployee AS e WITH (NOLOCK)
			WHERE e.EmpId = ti.EmpId
			)

	IF EXISTS (
			SELECT 1
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpLeaveRequestHalfDay'
			)
	BEGIN
		DROP TABLE #tmpLeaveRequestHalfDay
	END

	CREATE TABLE #tmpLeaveRequestHalfDay (EmpId INT, OnDate DATETIME, FromTime DATETIME, ToTime DATETIME)

	-- Get all leave request half day
	INSERT INTO #tmpLeaveRequestHalfDay (EmpId, OnDate, FromTime, ToTime)
	SELECT lv.EmpId, lv.OnDate, FromTime, ToTime
	FROM dbo.LeaveRequestDetail AS lv WITH (NOLOCK)
		INNER JOIN (
		SELECT ldt.empId
			,OnDate
		FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
			INNER JOIN dbo.WorkingTimeRequest AS wrq WITH (NOLOCK) ON ldt.RequestId = wrq.RequestId
		WHERE WorkType = 2
			AND IsHalfDay = 1 -- 2: leave, 1: Half day
			AND DATEDIFF(DD, @fromDate, OnDate) >= 0
			AND DATEDIFF(DD, OnDate, DATEADD(DD, 2, @toDate)) >= 0
			AND EXISTS (
				SELECT 1
				FROM #tmpEmployee AS tmp WITH (NOLOCK)
				WHERE tmp.EmpId = ldt.EmpId
				)
			AND wrq.CurrentStatus IN (4, 6)
		GROUP BY ldt.empId
			,OnDate
		HAVING COUNT(1) = 1
		) a ON a.EmpId = lv.EmpId
		AND a.OnDate = lv.OnDate
		INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON lv.RequestId = rq.RequestId
	WHERE lv.IsHalfDay = 1
		AND EXISTS (
			SELECT 1
			FROM #tmpEmployee AS tmp WITH (NOLOCK)
			WHERE tmp.EmpId = lv.EmpId
			)
		AND rq.CurrentStatus IN (4, 6)

	-- Get all calendars of employees into temp table
	IF EXISTS (
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpEmpCalendar'
			)
	BEGIN
		DROP TABLE #tmpEmpCalendar
	END

	CREATE TABLE #tmpEmpCalendar (
		Id INT PRIMARY KEY IDENTITY(1, 1)
		,EmpId INT
		,WorkDate DATETIME
		,ShiftId INT
		,IsHoliday BIT
		,IsOffDay BIT
		,IsLeaveDay BIT
		,LeaveTypeId INT NULL
		,IsKeepInView BIT
		,LateIn INT
		,EarlyOut INT
		,RequestedCheckInTime DATETIME
		,RequestedCheckOutTime DATETIME
		,BeginCheckInTime DATETIME
		,EndCheckInTime DATETIME
		,BeginCheckOutTime DATETIME
		,EndCheckOutTime DATETIME
		,BreakTimeMins INT
		,LeaveDay DECIMAL(18, 1)
		)

	INSERT INTO #tmpEmpCalendar (
		EmpId
		,WorkDate
		,ShiftId
		,IsHoliday
		,IsOffDay
		,IsLeaveDay
		,LeaveTypeId
		,IsKeepInView
		,LateIn
		,EarlyOut
		,RequestedCheckInTime
		,RequestedCheckOutTime
		,BeginCheckInTime
		,EndCheckInTime
		,BeginCheckOutTime
		,EndCheckOutTime
		,BreakTimeMins
		,LeaveDay
		)
	SELECT e.EmpId
		,e.WorkDate
		,ec.ShiftId
		,ec.IsHoliday
		,ec.IsOffDay
		,ec.IsLeaveDay
		,ec.LeaveTypeId
		,ec.IsKeepInView
		,ec.LateIn
		,ec.EarlyOut
		,ec.RequestedCheckinTime
		,ec.RequestedCheckoutTime
		,CASE
			WHEN s.IsInAfterDay = 1 THEN DATEADD(D, 1, ec.WorkDate + ' ' + s.EndCheckInTime)
			ELSE CAST(ec.WorkDate + ' ' + s.EndCheckInTime AS DATETIME)
			END AS BeginCheckInTime
		,CASE 
			WHEN s.IsInAfterDay = 1 THEN DATEADD(d, 1, ec.WorkDate + ' ' + s.EndCheckInTime)
			ELSE CAST(ec.WorkDate + ' ' + s.EndCheckInTime AS DATETIME)
			END AS EndCheckInTime
		,CASE 
			WHEN s.IsOutAfterDay = 1 THEN DATEADD(d, 1, ec.WorkDate + ' ' + s.BeginCheckOutTime)
			ELSE CAST(ec.WorkDate + ' ' + s.BeginCheckOutTime AS DATETIME)
			END AS BeginCheckOutTime
		,CASE 
			WHEN s.IsOutAfterDay = 1 THEN DATEADD(d, 1, ec.WorkDate + ' ' + s.EndCheckOutTime)
			ELSE CAST(ec.WorkDate + ' ' + s.EndCheckOutTime AS DATETIME)
			END AS EndCheckOutTime
		,s.BreakTimeMins
		,ec.LeaveDay
	FROM #tmpEmployee AS e WITH (NOLOCK)
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.EmpId = e.EmpId
		AND ec.WorkDate = e.WorkDate
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ec.ShiftId
	ORDER BY e.EmpId
		,e.WorkDate

    -- convert to server time zone
    UPDATE empca
    SET empca.BeginCheckInTime = CASE WHEN empca.BeginCheckInTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.BeginCheckInTime) END
        ,empca.EndCheckInTime = CASE WHEN empca.EndCheckInTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.EndCheckInTime) END
        ,empca.BeginCheckOutTime = CASE WHEN empca.BeginCheckOutTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.BeginCheckOutTime) END
        ,empca.EndCheckOutTime = CASE WHEN empca.EndCheckOutTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.EndCheckOutTime) END
    FROM #tmpEmpCalendar AS empca WITH (ROWLOCK)
        INNER JOIN #tmpEmployee AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON emp.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'

	IF EXISTS (
			SELECT 1
			FROM #tmpEmpCalendar WITH (NOLOCK)
			)
	BEGIN
		SET @i = 1

		WHILE EXISTS (
				SELECT 1
				FROM #tmpEmpCalendar WITH (NOLOCK)
				WHERE Id = @i
				)
		BEGIN
			SELECT @TempEmpId = EmpId
				,@TempWorkDate = WorkDate
				,@TempShiftId = ShiftId
			FROM #tmpEmpCalendar
			WHERE Id = @i

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForEmpId @TempEmpId
				,@TempWorkDate
				,@TempWorkDate
				,1

			EXEC dbo.Discipline_Insert @FromDate = @TempWorkDate
				,@ToDate = @TempWorkDate
				,@EmpId = @TempEmpId

			SET @i = @i + 1
		END
	END

    DROP TABLE #tmpEmployee

	DROP TABLE #tmpTimeRecord

	DROP TABLE #tmpEmpCalendar

	DROP TABLE #tmpLeaveRequestHalfDay
END