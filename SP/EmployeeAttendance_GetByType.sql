USE [bodb_HRM]
GO
/****** Object:  StoredProcedure [dbo].[EmployeeAttendance_GetByType]    Script Date: 3/7/2025 5:31:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeAttendance_GetByType] @fromtime DATE
	,@totime DATE
	,@EmpId INT = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@excludeUserDelete INT = 1
	,@isLocal BIT = NULL
	,@SupervisorId INT = NULL
	,@type SMALLINT
	,@isRealDate BIT = 0
AS
/*
Created: Tom.Vo@2013-10-31
Task: get attentance list of employees by type
DB: HRM_SMS
Original:

Revisions:
	- Merlin.Le@20200713: Get section and department - Redmine Id: 110683
Param's Explanation:
	@type: 0-all, 1-missing checkin; 2-missing check out, 3: latein; 4-earlyout, 5- not work
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @today DATETIME
		,@now DATETIME
		,@StartDate DATETIME
		,@EndDate DATETIME
		,@employeeIds VARCHAR(MAX)
		-- request type
		,@LateInRequestTypeId TINYINT = 3
		,@EarlyOutRequestTypeId TINYINT = 4
		,@ChangeShiftRequestTypeId TINYINT = 5
		,@LeaveRequestTypeId TINYINT = 6
		,@KeepInViewRequestTypeId TINYINT = 7
		-- request status
		,@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7
	CREATE TABLE #tmpGroup (GroupId INT PRIMARY KEY)

	CREATE TABLE #tmpEmployee (EmpId INT PRIMARY KEY)

	IF (@isRealDate = 1)
	BEGIN
		SET @fromtime = DATEADD(d, - 1, @fromtime)
	END

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpGroup (GroupId)
		SELECT val
		FROM dbo.fnc_strSplit(@TeamIds, ',')
	END
	ELSE
	BEGIN
		INSERT INTO #tmpGroup (GroupId)
		SELECT GroupId
		FROM dbo.[Group] WITH (NOLOCK)
		WHERE ISNULL(IsDeleted, 0) = 0
	END

	IF @EmpId IS NULL
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		SELECT DISTINCT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, @excludeUserDelete, 1)
	END
	ELSE
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		VALUES (@EmpId)
	END

	SET @now = dateadd(hh, 7, GETUTCDATE())
	SET @today = convert(VARCHAR(10), @now, 111) -- use UTC because the server use GMT-4

	CREATE TABLE #tmpDailyRequest (
		RequestId BIGINT
		,EmpId INT
		,WorkDate DATE
		,RequestType INT
		,InOutMins INT
		,RequestDate DATETIME
		,FromDate DATETIME
		,ToDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		,FromShift INT
		,ToShift INT
		,TotalDays NUMERIC(18, 2)
		,CurrentStatus TINYINT
		,KeepInViewTypeId TINYINT
		,Remark NVARCHAR(2000)
		,CreatedDate DATETIME
		,LeaveTypeId INT
		)

	SELECT @employeeIds = COALESCE(@employeeIds + ',', '') + CAST(EmpId AS VARCHAR(20))
	FROM #tmpEmployee WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @fromDate = @fromtime
		,@toDate = @totime
		,@empIds = @employeeIds

	-- check in/out
	INSERT INTO #tmpDailyRequest (
		RequestDate
		,RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,CurrentStatus
		,Remark
		,CreatedDate
		)
	SELECT cio.RequestTime
		,r.RequestId
		,r.EmpId
		,r.RequestType
		,cio.OnDate
		,cio.OnDate
		,0
		,r.CurrentStatus
		,r.Remark
		,r.CreatedDate
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.CheckInOutRequest AS cio WITH (NOLOCK) ON r.RequestId = cio.RequestId
		AND cio.OnDate BETWEEN @fromtime
			AND @totime
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)

	-- late in/early out
	INSERT INTO #tmpDailyRequest (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,InOutMins
		,CurrentStatus
		,Remark
		,CreatedDate
		)
	SELECT r.RequestId
		,r.EmpId
		,r.RequestType
		,lieo.OnDate
		,lieo.OnDate
		,0
		,(CASE 
			WHEN r.RequestType = @LateInRequestTypeId THEN lieo.LateInMins
			ELSE lieo.EarlyOutMins END
			)
		,r.CurrentStatus
		,r.Remark
		,r.CreatedDate
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK) ON r.RequestId = lieo.RequestId
		AND lieo.OnDate BETWEEN @fromtime
			AND @totime
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)

	-- keep in view
	INSERT INTO #tmpDailyRequest (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,CurrentStatus
		,KeepInViewTypeId
		,Remark
		,CreatedDate
		)
	SELECT r.RequestId
		,r.EmpId
		,r.RequestType
		,kiv.OnDate
		,kiv.OnDate
		,kiv.FromTime
		,kiv.ToTime
		,(CASE 
			WHEN kiv.IsHalfDay = 1 THEN 0.5
			ELSE 1 END
			)
		,r.CurrentStatus
		,kiv.KeepInViewType
		,r.Remark
		,r.CreatedDate
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON r.RequestId = kiv.RequestId
		AND kiv.OnDate BETWEEN @fromtime
			AND @totime
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)

	-- Leave request
	INSERT INTO #tmpDailyRequest (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,CurrentStatus
		,Remark
		,CreatedDate
		,LeaveTypeId
		)
	SELECT DISTINCT r.RequestId
		,r.EmpId
		,r.RequestType
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,CurrentStatus
		,r.Remark
		,r.CreatedDate
		,lr.LeaveType
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE (
			(
				lr.FromDate BETWEEN @fromtime
					AND @totime
				AND lr.ToDate >= @totime
				)
			OR (
				lr.FromDate <= @fromtime
				AND lr.ToDate >= @totime
				)
			OR lr.ToDate BETWEEN @fromtime
				AND @totime
			)
		AND EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
			WHERE lr.RequestId = ldt.RequestId
			)

	-- Leave request
	INSERT INTO #tmpDailyRequest (
		RequestId
		,EmpId
		,WorkDate
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromTime
		,ToTime
		,CurrentStatus
		,Remark
		,CreatedDate
		,LeaveTypeId
		)
	SELECT DISTINCT r.RequestId
		,r.EmpId
		,ldt.OnDate
		,r.RequestType
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,CASE WHEN ldt.IsHalfDay = 1 THEN ldt.FromTime ELSE NULL END
		,CASE WHEN ldt.IsHalfDay = 1 THEN ldt.ToTime ELSE NULL END
		,r.CurrentStatus
		,r.Remark
		,r.CreatedDate
		, ldt.LeaveType
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN [dbo].LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		INNER JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
		AND ldt.WorkType IN (1, 2) -- off, leave
	WHERE (
			(
				datediff(d, @fromtime, lr.FromDate) <= 0
				AND datediff(d, @totime, lr.ToDate) >= 0
				)
			OR (
				datediff(d, @fromtime, lr.FromDate) >= 0
				AND datediff(d, @totime, lr.FromDate) <= 0
				)
			OR (
				datediff(d, @fromtime, lr.ToDate) >= 0
				AND datediff(d, @totime, lr.ToDate) <= 0
				)
			)
		AND EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)

	-- change shift
	INSERT INTO #tmpDailyRequest (
		RequestId
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,ToShift
		,CurrentStatus
		,Remark
		,CreatedDate
		)
	SELECT r.RequestId
		,r.EmpId
		,r.RequestType
		,cs.FromDate
		,cs.ToDate
		,COUNT(1) TotalDays
		,MAX(csd.FromShift) FromShift
		,MAX(csd.ToShift) ToShift
		,r.CurrentStatus
		,r.Remark
		,r.CreatedDate
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON r.RequestId = cs.RequestId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		INNER JOIN dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK) ON csd.RequestId = cs.RequestId
	WHERE (
			(
				cs.FromDate BETWEEN @fromtime
					AND @totime
				AND cs.ToDate >= @totime
				)
			OR (
				cs.FromDate <= @fromtime
				AND cs.ToDate >= @totime
				)
			OR cs.ToDate BETWEEN @fromtime
				AND @totime
			)
		AND EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)
	GROUP BY r.CreatedDate
		,r.RequestId
		,r.EmpId
		,r.RequestType
		,cs.FromDate
		,cs.ToDate
		,r.CurrentStatus
		,r.Remark

	IF (@isRealDate = 1)
	BEGIN
		SET @fromtime = DATEADD(d, 1, @fromtime)
	END

	SET @StartDate = @fromtime
	SET @EndDate = @totime

	WHILE DATEPART(dw, @StartDate) <> 2
	BEGIN
		SET @StartDate = DATEADD(d, - 1, @StartDate)
	END

	WHILE DATEPART(dw, @EndDate) <> 1
	BEGIN
		SET @EndDate = DATEADD(d, 1, @EndDate)
	END

	DECLARE @OutOffDay TABLE (
		WorkDate DATETIME
		,EmpId INT
		)
	DECLARE @StartDate_tmp DATETIME
		,@EndDate_tmp DATETIME

	WHILE @StartDate <= @EndDate
	BEGIN
		SET @StartDate_tmp = @StartDate
		SET @EndDate_tmp = DATEADD(d, 6, @StartDate)
		SET @StartDate = DATEADD(d, 7, @StartDate)

		INSERT INTO @OutOffDay (
			WorkDate
			,EmpId
			)
		SELECT WorkDate
			,cl.EmpId
		FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
			INNER JOIN (
			SELECT c.EmpId
			FROM dbo.EmployeeCalendar AS c WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON c.EmpId = es.EmpId
			WHERE WorkDate BETWEEN @StartDate_tmp
					AND @EndDate_tmp
				AND c.IsOffDay = 1
				AND (
					@EmpId IS NULL
					OR c.EmpId = @EmpId
					)
			GROUP BY c.EmpId
				,es.OffDaysbyWeek
			HAVING COUNT(c.EmpId) > es.OffDaysbyWeek
			) AS a ON cl.EmpId = a.EmpId
		WHERE WorkDate BETWEEN @StartDate_tmp
				AND @EndDate_tmp
			AND cl.IsOffDay = 1
			AND (
				@EmpId IS NULL
				OR cl.EmpId = @EmpId
				)
	END

	SELECT T.Code
		,T.EmpId
		,T.FullName
		,T.NickName
		,T.[Team]
		,T.[TeamCode]
		,T.[Rank]
		,T.AttendanceDate
		,T.ShiftId
		,COALESCE(T.ShiftCode, CASE 
				WHEN ISNULL(T.IsHoliday, 0) = 0
					AND (T.ShiftId IS NULL OR T.ShiftId = -1)
					AND isOffday = 1 THEN 'Off day'
				WHEN ISNULL(T.IsHoliday, 0) = 1
					AND (
						T.InFixed IS NULL
						AND T.OutFixed IS NULL
						) THEN 'PH'
				ELSE ''
				END, '') ShiftCode
		,T.ExpectedInTime
		,T.ExpectedOutTime
		,CASE 
			WHEN T.IsShiftCrossDay = 1
				AND ISNULL(T.IsHoliday, 0) = 0
				AND T.ShiftId IS NULL
				AND isOffday = 1 THEN NULL
			ELSE T.InFixed
			END InFixed
		,CASE 
			WHEN T.IsShiftCrossDay = 1
				AND ISNULL(T.IsHoliday, 0) = 0
				AND T.ShiftId IS NULL
				AND isOffday = 1 THEN NULL
			ELSE T.OutFixed
			END OutFixed
		,T.LateIn
		,T.EarlyOut
		,CASE 
			WHEN T.IsShiftCrossDay = 1
				AND ISNULL(T.IsHoliday, 0) = 0
				AND T.ShiftId IS NULL
				AND isOffday = 1 THEN NULL
			ELSE T.TotalWorkHours
			END TotalWorkHours
		,T.Absence
		,T.isNotWork
		,T.isOffday
		,T.IsHoliday AS IsPublicHoliday
		,(CASE 
			WHEN (
					(
						od.EmpId IS NOT NULL
						OR (
							AttendanceDate1 IS NOT NULL
							AND isMissingCheckin = 1
							)
						OR (
							AttendanceDate1 IS NOT NULL
							AND isMissingCheckOut = 1
							)
						)
					AND CONVERT(NVARCHAR(20), T.AttendanceDate1, 111) < CONVERT(NVARCHAR(20), GETDATE(), 111)
					) THEN 1
			ELSE 0 END
			) AS IsWarning
		,T.IsOvertime
		,T.OvertimeHours
		,T.OvertimeStatus
		,ISNULL(stuff((CASE 
					WHEN AttendanceDate1 IS NOT NULL
						AND (
							isLateIn = 1
							AND LateIn > 0
							) THEN (', Late In')
					ELSE '' END
					) + (CASE 
					WHEN AttendanceDate1 IS NOT NULL
						AND (
							isEarlyOut = 1
							AND EarlyOut > 0
							) THEN ', Early Out'
					ELSE '' END
					) + (CASE 
					WHEN AttendanceDate1 IS NOT NULL
						AND isMissingCheckin = 1 THEN ', Missing Check-in'
					ELSE '' END
					) + (CASE 
					WHEN AttendanceDate1 IS NOT NULL
						AND isMissingCheckOut = 1
						AND CONVERT(NVARCHAR(20), T.AttendanceDate1, 111) < CONVERT(NVARCHAR(20), GETDATE(), 111) THEN ', Missing Check-out'
					ELSE '' END
					) + (CASE 
					WHEN AttendanceDate1 IS NOT NULL
						AND IsKeepInView = 1 THEN ', CL day' + CASE 
							WHEN LeaveDay = 0.5 THEN ' (Half day)'
							ELSE ''
							END
					ELSE '' END
					) + (CASE 
					WHEN ISNULL(T.IsHoliday, 0) = 0
						AND isOffday = 1
						AND (ShiftId IS NULL OR ShiftId = -1) THEN (CASE 
							WHEN od.EmpId IS NULL THEN ', Off day'
							ELSE ', Off day no match' END
							)
					ELSE '' END
					) + (CASE 
					WHEN ISNULL(T.IsHoliday, 0) = 0
						AND isOffday = 1
						AND ShiftId IS NOT NULL
						AND ShiftId != -1
						AND od.EmpId IS NOT NULL THEN ', Off day no match'
					ELSE '' END
					) + (CASE 
					WHEN ISNULL(T.IsHoliday, 0) = 1
						AND ShiftId IS NULL THEN ', PH'
					ELSE '' END
					) + (CASE 
					WHEN isNotWork = 1
						AND T.LeaveTypeId IS NULL THEN ', Absent'
					ELSE (
							(CASE 
								WHEN lv.[Name] IS NULL THEN ''
								ELSE ', ' + lv.[Name] + (CASE 
										WHEN lv2.[Name] IS NULL THEN ''
										ELSE ' & ' + lv2.[Name] END
										) + (CASE 
										WHEN LeaveDay = 0.5 THEN ' (Half day)'
										ELSE '' END
										) END
								) + CASE 
							WHEN LeaveDay = 0.5
								AND isNotWork = 1 THEN ', Absent'
							ELSE '' END
							) END
					), 1, 2, ''), CASE 
				WHEN AttendanceDate1 IS NULL THEN 'No Data'
				ELSE NULL
				END) AS Notes
		,T.SectionCode
		,T.DepartmentCode
	FROM (
		SELECT e.Code
			,e.EmpId
			,FullName
			,NickName
			,g.[Name] [Team]
			,g.Code [TeamCode]
			,g.[Rank]
			,c.WorkDate AS AttendanceDate
			,a.AttendanceDate AS AttendanceDate1
			,c.ShiftId
			,s.code AS ShiftCode
			,s.BeginCheckInTime AS ExpectedInTime
			,s.BeginCheckOutTime AS ExpectedOutTime
			,a.InFixed
			,a.OutFixed
			,a.LateIn
			,a.EarlyOut
			,TotalWorkHours
			,c.IsKeepInView
			,c.LeaveDay
			,ISNULL(a.LeaveTypeId, c.LeaveTypeId) AS LeaveTypeId
			,ISNULL(a.LeaveTypeId2, c.LeaveTypeId2) AS LeaveTypeId2
			,Absence
			,(CASE 
				WHEN isnull(a.Absence, 0) = 0
					AND isnull(a.LateIn, 0) > 0 THEN 1
				ELSE 0 END
				) AS isLateIn
			,(CASE 
				WHEN isnull(a.Absence, 0) = 0
					AND isnull(a.EarlyOut, 0) > 15 THEN 1
				ELSE 0 END
				) AS isEarlyOut
			,(CASE 
				WHEN (
						isnull(a.Absence, 0) = 0
						AND a.InFixed IS NULL
						AND @now > (
							(CASE 
								WHEN s.IsInAfterDay = 1 THEN DATEADD(DD, 1, a.AttendanceDate)
								ELSE a.AttendanceDate END
								) + ' ' + s.EndCheckInTime
							)
						) THEN 1
				ELSE 0 END
				) AS isMissingCheckin
			,(CASE 
				WHEN (
						isnull(a.Absence, 0) = 0
						AND a.OutFixed IS NULL
						AND @now > (
							(CASE 
								WHEN s.IsOutAfterDay = 1 THEN DATEADD(DD, 1, a.AttendanceDate)
								ELSE a.AttendanceDate END
								) + ' ' + s.EndCheckOutTime
							)
						) THEN 1
				ELSE 0 END
				) AS isMissingCheckOut
			,(CASE 
				WHEN (
						a.ShiftId IS NOT NULL
						AND a.InFixed IS NULL
						AND a.OutFixed IS NULL
						AND a.TotalWorkHours IS NULL
						AND @now > (
							(CASE 
								WHEN s.IsInAfterDay = 1 THEN DATEADD(DD, 1, a.AttendanceDate)
								ELSE a.AttendanceDate END
								) + ' ' + s.EndCheckInTime
							)
						) THEN 1
				ELSE 0 END
				) AS isNotWork
			,c.isOffday
			,CONVERT(BIT, CASE 
					WHEN ot.EmpId IS NULL THEN 0
					ELSE 1
					END) IsOvertime
			,(ISNULL(ot.NormalHours, 0) + ISNULL(ot.OffHours, 0) + ISNULL(ot.PublicHours, 0) + ISNULL(ot.SpecialHours, 0)) OvertimeHours
			,ot.[Status] AS OvertimeStatus
			,c.IsHoliday
			,(CASE 
				WHEN ISNULL(s_CrossDay.IsOutAfterDay, 0) = 1 THEN 1
				ELSE 0 END
				) AS IsShiftCrossDay
			,sec.Code AS SectionCode
			,de.Code AS DepartmentCode
		FROM dbo.Employee AS e WITH (NOLOCK)
			INNER JOIN dbo.tmpEmployeeCalendar AS c WITH (NOLOCK) ON c.EmpId = e.EmpId
			AND c.WorkDate BETWEEN @fromtime
				AND @totime
			INNER JOIN #tmpEmployee AS tblemp ON e.EmpId = tblemp.EmpId
			LEFT JOIN dbo.EmployeeSummary AS e_s WITH (NOLOCK) ON e_s.EmpId = e.EmpId
			LEFT JOIN dbo.EmployeeCalendar AS c_CrossDay WITH (NOLOCK) ON c_CrossDay.WorkDate = DATEADD(D, - 1, c.WorkDate)
			AND c_CrossDay.EmpId = e.EmpId
			LEFT JOIN dbo.[Shift] AS s_CrossDay WITH (NOLOCK) ON s_CrossDay.ShiftId = c_CrossDay.ShiftId
			LEFT JOIN dbo.EmployeeCalendar AS c_CurDay WITH (NOLOCK) ON c_CurDay.WorkDate = DATEADD(D, - 1, c.WorkDate)
			AND c_CurDay.EmpId = e.EmpId
			LEFT JOIN dbo.[Shift] AS s_CurDay WITH (NOLOCK) ON s_CurDay.ShiftId = c_CurDay.ShiftId
			AND (
				(
					s_CrossDay.IsInAfterDay = 0
					OR @isRealDate = 0
					)
				OR (
					(
						s_CrossDay.IsInAfterDay = 1
						OR s_CurDay.IsInAfterDay = 1
						)
					AND @isRealDate = 1
					AND c.WorkDate = c_CrossDay.WorkDate
					)
				)
			LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = c.ShiftId
			LEFT JOIN dbo.EmployeeAttendance AS a WITH (NOLOCK) ON a.AttendanceDate = c.WorkDate
			AND a.empid = e.empid
			LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.groupid = g.groupid
			INNER JOIN dbo.[Section] AS sec WITH (NOLOCK) ON sec.SectionId = g.SectionId
			INNER JOIN dbo.[Department] AS de WITH (NOLOCK) ON de.DepartmentId = sec.DepartmentId
			INNER JOIN #tmpGroup AS tmpgr ON g.GroupId = tmpgr.GroupId
			LEFT JOIN dbo.OTDailyRequest AS ot WITH (NOLOCK) ON a.attendancedate = ot.OvertimeDate
			AND a.EmpId = ot.EmpId
		WHERE @isLocal IS NULL
			OR e_s.IsLocal = @isLocal
		) AS T
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeId = T.LeaveTypeId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON lv2.LeaveTypeId = T.LeaveTypeId2
		LEFT JOIN @OutOffDay AS od ON t.AttendanceDate = od.WorkDate
		AND t.EmpId = od.EmpId
	WHERE @type = 0
		OR (
			@type = 1
			AND ISNULL(T.isMissingCheckin, 1) = 1
			)
		OR (
			@type = 2
			AND T.isMissingCheckout = 1
			)
		OR (
			@type = 3
			AND T.isLateIn = 1
			)
		OR (
			@type = 4
			AND T.isEarlyOut = 1
			)
		OR (
			@type = 5
			AND T.isNotWork = 1
			)
	ORDER BY attendancedate DESC
		,[Rank]
		,TeamCode
		,T.code

	SELECT c.WorkDate
		,rd.EmpId
		,rd.RequestDate
		,rd.FromDate
		,rd.ToDate
		,rd.FromTime
		,rd.ToTime
		,rd.TotalDays
		,rd.CurrentStatus
		,rd.KeepInViewTypeId
		,rd.Remark
		,rd.CreatedDate
		,(CASE 
			WHEN rd.RequestType = 5
				OR rd.RequestType = 7 THEN (CASE 
					WHEN s1.ShiftID IS NULL THEN 'OFF'
					ELSE s1.[Name] END
					)
			ELSE s3.[Name] END
			) AS FromShift
		,(CASE 
			WHEN s2.ShiftID IS NULL THEN 'OFF'
			ELSE s2.[Name] END
			) AS ToShift
		,rd.InOutMins AS TotalMins
		,rd.RequestType
		,rd.LeaveTypeId
		,l.[Name] AS LeaveTypeName
	FROM #tmpDailyRequest AS rd WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS c WITH (NOLOCK) ON (
			(
				rd.WorkDate IS NOT NULL AND rd.WorkDate = c.WorkDate) 
				OR (rd.WorkDate IS NULL AND c.WorkDate BETWEEN CAST(rd.FromDate AS DATE) AND CAST(rd.ToDate AS DATE))
			)
		AND c.EmpId = rd.EmpId
		AND (
			(
				rd.RequestType = @LeaveRequestTypeId
				--AND rd.RequestId = c.RequestId
				AND c.IsHoliday = 0
				AND c.IsOffDay = 0
				--AND c.IsKeepInView = 0
				)
			OR rd.RequestType <> @LeaveRequestTypeId
			)
		LEFT JOIN dbo.LeaveType AS l WITH (NOLOCK) ON l.LeaveTypeId = rd.LeaveTypeId
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftId = rd.FromShift
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftId = rd.ToShift
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftId = c.ShiftId

	DROP TABLE #tmpGroup

	DROP TABLE #tmpEmployee

	DROP TABLE #tmpDailyRequest
END
