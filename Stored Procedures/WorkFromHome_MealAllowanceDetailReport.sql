/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[WorkFromHome_MealAllowanceDetailReport] @CompanyId SMALLINT
    ,@FromDate DATE
	,@ToDate DATE
	,@TeamId VARCHAR(MAX) = ''
	,@EmployeeId INT = NULL
	,@IsLocal BIT = NULL
AS
/*
Created: 20211109@Quinn.Vo
Task: Get meal allowance report
DB: HRM
Original:

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tmpToDate DATETIME = DATEADD(SECOND, -1, DATEADD(DAY, 2, CONVERT(DATETIME, @ToDate)))
        ,@serverTimeZone SMALLINT = -4
        ,@clientTimeZone SMALLINT

    SELECT @clientTimeZone = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'TimeZone'

    SET @clientTimeZone = ISNULL(@clientTimeZone, @serverTimeZone)

	CREATE TABLE #tmpEmployee (EmpId INT)

	CREATE TABLE #tmpTeam (GroupId INT)

	IF ISNULL(@TeamId, '') <> ''
	BEGIN
		INSERT INTO #tmpTeam (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamId, ',')
	END

	INSERT INTO #tmpEmployee (EmpId)
	SELECT e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
	WHERE ce.CompanyId = @CompanyId
        AND (
			@EmployeeId IS NULL
			OR e.EmpId = @EmployeeId
			)
		AND (
			ISNULL(@TeamId, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tmpTeam AS tbl WITH (NOLOCK)
				WHERE e.GroupId = tbl.GroupId
				)
			)
		AND (
			@IsLocal IS NULL
			OR es.IsLocal = @IsLocal
			)

	CREATE TABLE #tmpInOut (
		EmpId INT
		,RecordTime DATETIME
		)

	CREATE CLUSTERED INDEX ix_tmpInOut ON #tmpInOut (
		EmpId
		,RecordTime
		)

	INSERT INTO #tmpInOut (
		EmpId
		,RecordTime
		)
	SELECT tr.EmpId
		,RecordTime
	FROM dbo.TimeRecord AS tr WITH (NOLOCK)
		INNER JOIN dbo.TimeRecordExt AS te WITH (NOLOCK) ON tr.ID = te.ID
		INNER JOIN #tmpEmployee AS tmpemp WITH (NOLOCK) ON tr.EmpId = tmpemp.EmpId
	WHERE DATEADD(HOUR, @clientTimeZone, DATEADD(HOUR, ABS(@serverTimeZone), tr.RecordTime)) BETWEEN DATEADD(DAY, - 1, @FromDate)
			AND @tmpToDate

	CREATE TABLE #tmpEmpAttandance (
		EmpId INT
		,WorkDate DATE
		,ShiftId INT
		,InFixed DATETIME
		,OutFixed DATETIME
		,TotalWorkHours DECIMAL(18, 2)
		,TotalDays DECIMAL(18, 2)
		)

	INSERT INTO #tmpEmpAttandance (
		EmpId
		,WorkDate
		,ShiftId
		,InFixed
		,OutFixed
		,TotalWorkHours
		,TotalDays
		)
	SELECT att.EmpId
		,att.AttendanceDate AS WorkDate
		,att.ShiftId
		,att.InFixed
		,att.OutFixed
		,att.TotalWorkHours
		,CASE 
			WHEN DATEDIFF(HOUR, att.ExpectedInTime, att.ExpectedOutTime) >= 9 THEN CASE 
					WHEN ISNULL(att.TotalWorkHours, 0) >= 8 THEN 1
					ELSE CASE 
							WHEN ISNULL(att.TotalWorkHours, 0) >= 3.5 THEN 0.5
							ELSE 0
							END
					END
			ELSE CASE 
					WHEN ISNULL(att.TotalWorkHours, 0) >= 7 THEN 1
					ELSE CASE 
							WHEN ISNULL(att.TotalWorkHours, 0) >= 3.5 THEN 0.5
							ELSE 0
							END
					END
			END AS TotalDays
	FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
		INNER JOIN #tmpEmployee AS e WITH (NOLOCK) ON att.EmpId = e.EmpId
		INNER JOIN dbo.tmpEmployeeCalendar AS tcl WITH (NOLOCK) ON att.EmpId = tcl.EmpId
		AND att.AttendanceDate = tcl.WorkDate
	WHERE ISNULL(att.TotalWorkHours, 0) > 3
		AND tcl.LeaveDay <> 1
		AND att.AttendanceDate BETWEEN @FromDate
			AND @ToDate
		AND EXISTS (
			SELECT 1
			FROM #tmpInOut AS tblinout WITH (NOLOCK)
			WHERE att.EmpId = tblinout.EmpId
				AND (
					att.InFixed = tblinout.RecordTime
					OR att.OutFixed = tblinout.RecordTime
					)
			)

	SELECT a.WorkDate
		,a.ShiftId
		,s.Code AS ShiftCode
		,a.InFixed
		,a.OutFixed
		,a.TotalWorkHours
		,a.TotalDays
		,e.EmpId
		,e.Code
		,e.FullName
		,e.NickName
		,g.GroupId AS TeamId
		,g.[Name] AS Team
		,sec.Code AS Section
		,dep.Code AS Department
	FROM #tmpEmpAttandance AS a WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON a.EmpId = e.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId
		INNER JOIN dbo.Section AS sec WITH (NOLOCK) ON sec.SectionId = g.SectionId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = sec.DepartmentId
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = a.ShiftId
        AND s.CompanyId = @CompanyId
	ORDER BY dep.Code
		,sec.Code
		,g.[Name]
		,e.Code
		,a.WorkDate

	DROP TABLE #tmpEmployee

	DROP TABLE #tmpTeam

	DROP TABLE #tmpEmpAttandance

	DROP TABLE #tmpInOut
END