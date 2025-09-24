/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_MonthlyWorkingHours]
(
    @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@Employee NVARCHAR(200) = NULL
	,@IsLocal BIT = NULL
	,@EmployeeStatusIds VARCHAR(10) = ''
)
AS
/*
    Created: Tim@2019-06-24
    Task: monthly working hours
    DB: bodb_HRM

    Revisions:
        -20250417@Tim: get Unit Code [Redmine: #224530]
        -20250813@Jay: change db structure [Redmine: #235678]
        -20250919@Tim: user status filter [Redmine: #239089]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATE = GETDATE()
		,@EmpIds VARCHAR(MAX) = ''
		-- employee status
		,@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
		-- leave type 
		,@KIVByHourLeaveType INT = 48
	CREATE TABLE #tblGroupIds (GroupId INT PRIMARY KEY)
	CREATE TABLE #tblEmployeeIds (EmpId INT PRIMARY KEY)
    DECLARE @tblStatus TABLE (Id TINYINT)

	IF ISNULL(@TeamIds, '') != ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
		WHERE ISNUMERIC(value) = 1
	END

    IF ISNULL(@EmployeeStatusIds, '') != ''
    BEGIN
        INSERT INTO @tblStatus (Id)
		SELECT value
		FROM STRING_SPLIT(@EmployeeStatusIds, ',')
    END

	INSERT INTO #tblEmployeeIds (EmpId)
	SELECT ce.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e (NOLOCK) ON ce.UserId = e.UserId
        INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
			AND ce.IsSpecialUser = 0
		INNER JOIN (
		SELECT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1, @CompanyId)
		) AS [member] ON ce.EmpId = [member].EmpId
	WHERE (
			ISNULL(@EmployeeStatusIds, '') = ''
            OR EXISTS (
                SELECT 1
                FROM @tblStatus AS s
                WHERE (s.Id = @Enable AND ce.[Enabled] = 1 AND ce.isDeleted = 0)
                    OR (s.Id = @Disabled AND ce.[Enabled] = 0 AND ce.isDeleted = 0)
                    OR (s.Id = @Deleted AND ce.isDeleted = 1)
                )
			)
		AND (
			ce.Nickname LIKE '%' + ISNULL(@Employee, '') + '%'
			OR e.FullName LIKE '%' + ISNULL(@Employee, '') + '%'
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE tbl.GroupId = ce.GroupId
			)

	SELECT @EmpIds = COALESCE(@EmpIds + ',', '') + CAST(EmpId AS VARCHAR(10))
	FROM #tblEmployeeIds WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
        ,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @EmpIds

	SELECT ce.EmpId
		,empca.WorkDate
		,(CASE 
			WHEN empatt.TotalWorkHours > 0 THEN empatt.TotalWorkHours
			ELSE (
				SELECT DATEDIFF(mi, min(t.RequestTime), max(t.RequestTime)) / 60.0
				FROM (
					SELECT cio.EmpId, cio.OnDate, cio.RequestTime
					FROM dbo.CheckInOutRequest AS cio WITH (NOLOCK)
						INNER JOIN dbo.WorkingTimeRequest AS w WITH (NOLOCK) ON cio.RequestId = w.RequestId
					WHERE cio.EmpId = ce.EmpId
                        AND cio.OnDate = empca.WorkDate
                        AND w.CurrentStatus NOT IN (3, 5, 7)
				) AS t
			)
			END) AS TotalWorkingHours
		,empca.IsHoliday
		,empca.IsOffDay
		,(CASE 
			WHEN empca.IsLeaveDay = 1
				AND (empca.LeaveTypeId = @KIVByHourLeaveType OR empca.LeaveTypeId2 = @KIVByHourLeaveType) THEN 0
			ELSE empca.IsLeaveDay END
			) AS IsLeaveDay
		,(CASE 
			WHEN empca.LeaveTypeId = @KIVByHourLeaveType AND empca.LeaveTypeId2 = @KIVByHourLeaveType THEN empca.LeaveDay - 1
			WHEN empca.LeaveTypeId = @KIVByHourLeaveType OR empca.LeaveTypeId2 = @KIVByHourLeaveType THEN empca.LeaveDay - 0.5
			ELSE empca.LeaveDay END
			) AS LeaveDay
		,(CASE 
			WHEN empca.WorkDate < DATEADD(DAY, -1, @Today)
				AND empatt.ShiftId IS NOT NULL
				AND empatt.InFixed IS NULL
				AND empatt.OutFixed IS NOT NULL
				AND empatt.TotalWorkHours IS NULL THEN 1
			ELSE 0 END
			) AS IsMissingCheckIn
		,(CASE 
			WHEN empca.WorkDate < DATEADD(DAY, -1, @Today)
				AND empatt.ShiftId IS NOT NULL
				AND empatt.OutFixed IS NULL
				AND empatt.InFixed IS NOT NULL
				AND empatt.TotalWorkHours IS NULL THEN 1
			ELSE 0 END
			) AS IsMissingCheckOut
		,(CASE 
			WHEN empca.WorkDate < DATEADD(DAY, -1, @Today)
				AND empca.ShiftId IS NOT NULL
				AND (
					empsum.IsDefaultSchedule = 0
					OR (
						empsum.IsLocal = 1
						AND empsum.IsDefaultSchedule = 1
						AND NOT (
							empca.IsHoliday = 1
							OR empca.IsOffDay = 1
							)
						)
					)
				AND empatt.InFixed IS NULL
				AND empatt.OutFixed IS NULL
				AND empatt.TotalWorkHours IS NULL THEN 1
			ELSE 0 END
			) AS IsAbsent
		,r.CurrentStatus AS RequestStatusId
		,empca.LeaveTypeId
		,lv.Code
		,lv.[Name]
		,empca.FromTime
		,empca.ToTime
		,empca.LeaveTypeId2
		,lv2.Code AS LeaveCode
		,lv2.[Name] AS LeaveName
	INTO #tblEmployeeCalendar
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid WITH (NOLOCK) ON ce.EmpId = empid.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON ce.EmpId = empca.EmpId
		LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON ce.EmpId = empatt.EmpId
		AND CAST(empatt.AttendanceDate AS DATE) = empca.WorkDate
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON empca.LeaveTypeId = lv.LeaveTypeId
        AND lv.CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId
        AND lv2.CompanyId = @CompanyId
		LEFT JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON empca.RequestId = r.RequestId
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate

	SELECT ce.EmpId
		,ce.Code
		,ce.NickName
		,e.FullName
        ,ce.[Enabled]
        ,ce.IsDeleted
		,empsum.WorkingDays
        ,u.Code AS UnitCode
		,dep.Code AS DepartmentCode
		,dep.[Name] AS DepartmentName
		,gr.GroupId AS TeamId
		,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e (NOLOCK) ON ce.UserId = e.UserId
		INNER JOIN #tblEmployeeIds AS empid WITH (NOLOCK) ON ce.EmpId = empid.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
        INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON dep.UnitId = u.UnitId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
	ORDER BY gr.[Name]
		,ce.Code

	SELECT EmpId
		,WorkDate
		,TotalWorkingHours
		,IsHoliday
		,IsOffDay
		,IsLeaveDay
		,LeaveDay
		,IsMissingCheckIn
		,IsMissingCheckOut
		,IsAbsent
		,RequestStatusId
		,LeaveTypeId
		,Code AS LeaveTypeCode
		,[Name] AS LeaveTypeName
		,FromTime
		,ToTime
		,LeaveTypeId2
		,LeaveCode AS LeaveTypeCode2
		,LeaveName AS LeaveTypeName2
	FROM #tblEmployeeCalendar WITH (NOLOCK)
	ORDER BY EmpId
		,WorkDate

	DROP TABLE #tblGroupIds
	DROP TABLE #tblEmployeeIds
	DROP TABLE #tblEmployeeCalendar
END