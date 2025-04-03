/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeAttendance_ProcessingAndInsert] @empId INT = NULL
	,@fromTime DATETIME
	,@toTime DATETIME
	,@onlyUpdate BIT = 0
    ,@CompanyId SMALLINT = NULL
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
		,@tempFromDate DATE = @fromTime
		,@tempToDate DATE = @toTime
		,@today DATE = GETDATE()
        ,@serverTimeZone SMALLINT = -4
	DECLARE @tblDateRange TABLE (WorkDate DATE)
	CREATE TABLE #tmpEmployee (Id INT PRIMARY KEY IDENTITY(1, 1), EmpId INT)

	IF @tempToDate > @today
	BEGIN
		SET @tempToDate = @today
	END

	WHILE @tempFromDate <= @tempToDate
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM @tblDateRange
				WHERE WorkDate = @tempFromDate
				)
		BEGIN
			INSERT INTO @tblDateRange (WorkDate)
			VALUES (@tempFromDate)
		END

		SET @tempFromDate = DATEADD(DAY, 1, @tempFromDate)
	END

	IF EXISTS (
			SELECT EmpId
			FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
				LEFT JOIN @tblDateRange AS tbldate ON empca.WorkDate = tbldate.WorkDate
			WHERE (
					@empId IS NULL
					OR EmpId = @empId
					)
				AND tbldate.WorkDate IS NULL
			)
	BEGIN
		DECLARE @ErrCode INT = 0
			,@ErrMsg VARCHAR(200) = ''

		EXEC dbo.EmployeeCalendar_Insert @EmpId = @empId
			,@fromdate = @fromTime
			,@todate = @tempToDate
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END

	IF EXISTS (
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpTimeRecord'
			)
	BEGIN
		DROP TABLE #tmpTimeRecord
	END

	CREATE TABLE #tmpTimeRecord (
		Id INT
		,EmpId INT
		,RecordTime DATETIME
		,InOutType TINYINT
		)

	-- Get all in/out data into temp table to calculate
	INSERT INTO #tmpTimeRecord (
		Id
		,EmpId
		,RecordTime
		,InOutType
		)
	SELECT tr.Id
		,tr.EmpId
		,tr.RecordTime
		,tr.InOutType
	FROM dbo.TimeRecord AS tr WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON tr.EmpId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0
		AND DATEADD(MINUTE, CAST(ISNULL(config.Value, @serverTimeZone) AS REAL) * 60, DATEADD(HOUR, ABS(@serverTimeZone), tr.RecordTime))
            BETWEEN DATEADD(HH, - 2, CONVERT(VARCHAR(10), @fromTime, 111)) AND DATEADD(d, 2, CONVERT(VARCHAR(10), @toTime, 111))
		AND emp.JoinedDate <= CAST(tr.RecordTime AS DATE)
		AND (
			@empId IS NULL
			OR tr.EmpId = @empId
			)

	IF EXISTS (
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpLeaveRequestHalfDay'
			)
	BEGIN
		DROP TABLE #tmpLeaveRequestHalfDay
	END

	CREATE TABLE #tmpLeaveRequestHalfDay (
		EmpId INT
		,OnDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		)

	-- Get all leave request half day
	INSERT INTO #tmpLeaveRequestHalfDay (
		EmpId
		,OnDate
		,FromTime
		,ToTime
		)
	SELECT lv.EmpId
		,lv.OnDate
		,FromTime
		,ToTime
	FROM dbo.LeaveRequestDetail AS lv WITH (NOLOCK)
		INNER JOIN (
		SELECT ldt.empId
			,OnDate
		FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
			INNER JOIN dbo.WorkingTimeRequest AS wrq WITH (NOLOCK) ON ldt.RequestId = wrq.RequestId
		WHERE WorkType = 2
			AND IsHalfDay = 1 -- 2: leave, 1: Half day
			AND OnDate BETWEEN CONVERT(VARCHAR(10), @fromTime, 111)
				AND CONVERT(VARCHAR(10), DATEADD(d, 2, @toTime), 111)
			AND (
				@empId IS NULL
				OR ldt.EmpId = @empId
				)
			AND wrq.CurrentStatus IN (4, 6)
		GROUP BY ldt.empId
			,OnDate
		HAVING COUNT(*) = 1
		) a ON a.EmpId = lv.EmpId
			AND a.OnDate = lv.OnDate
		INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON lv.RequestId = rq.RequestId
	WHERE lv.IsHalfDay = 1
		AND (
			@empId IS NULL
			OR lv.EmpId = @empId
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
	SELECT ec.EmpId
		,ec.WorkDate
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
			WHEN IsInAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.EndCheckInTime)
			ELSE CAST(WorkDate + ' ' + s.EndCheckInTime AS DATETIME)
			END AS BeginCheckInTime
		,CASE 
			WHEN IsInAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.EndCheckInTime)
			ELSE CAST(WorkDate + ' ' + s.EndCheckInTime AS DATETIME)
			END AS EndCheckInTime
		,CASE 
			WHEN IsOutAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.BeginCheckOutTime)
			ELSE CAST(WorkDate + ' ' + s.BeginCheckOutTime AS DATETIME)
			END AS BeginCheckOutTime
		,CASE 
			WHEN IsOutAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.EndCheckOutTime)
			ELSE CAST(WorkDate + ' ' + s.EndCheckOutTime AS DATETIME)
			END AS EndCheckOutTime
		,BreakTimeMins
		,LeaveDay
	FROM dbo.EmployeeCalendar AS ec WITH (NOLOCK)
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ec.EmpId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ec.ShiftId
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0
        AND (
			@EmpId IS NULL
			OR emp.EmpId = @EmpId
			)
        AND (
			@CompanyId IS NULL
			OR ce.CompanyId = @CompanyId
			)
		AND ec.WorkDate BETWEEN @FromTime
			AND @ToTime
	ORDER BY ec.EmpId
		,ec.WorkDate

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
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'

	IF @empId IS NULL
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		SELECT e.EmpId
		FROM dbo.Employee AS e WITH (NOLOCK)
            INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
		WHERE e.[Enabled] = 1
		    AND e.isDeleted = 0
            AND (
			    @CompanyId IS NULL
			    OR ce.CompanyId = @CompanyId
			)
			AND EXISTS (
				SELECT 1
				FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
				WHERE DATEDIFF(DD, @fromTime, cl.WorkDate) >= 0
					AND DATEDIFF(DD, WorkDate, @toTime) >= 0
					AND e.EmpId = cl.EmpId
				)

		SET @i = 1

		WHILE EXISTS (
				SELECT 1
				FROM #tmpEmployee WITH (NOLOCK)
				WHERE Id = @i
				)
		BEGIN
			SELECT @TempEmpId = EmpId
			FROM #tmpEmployee WITH (NOLOCK)
			WHERE Id = @i

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForEmpId @TempEmpId
				,@fromTime
				,@toTime
				,@onlyUpdate

			SET @i = @i + 1
		END

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForWorkDay @empId
			,@fromTime
			,@toTime
	END
	ELSE
	BEGIN
		EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForEmpId @EmpId
			,@fromTime
			,@toTime
			,@onlyUpdate
	END

	EXEC dbo.Discipline_Insert @FromDate = @fromTime
		,@ToDate = @toTime
		,@EmpId = @EmpId

	DROP TABLE #tmpEmployee
    
    DROP TABLE #tmpTimeRecord

	DROP TABLE #tmpEmpCalendar

	DROP TABLE #tmpLeaveRequestHalfDay
END