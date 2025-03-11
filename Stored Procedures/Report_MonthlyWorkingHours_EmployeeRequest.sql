/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_MonthlyWorkingHours_EmployeeRequest] @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@Employee NVARCHAR(200) = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
	,@EmployeeStatusId TINYINT = NULL
AS
/*
Created: Tim.Trinh@2019-08-20
Task: get employee request
DB: HRM
Original:

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE -- employee status
		@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
		-- work type
		,@OffDay TINYINT = 1
		,@LeaveDay TINYINT = 2
		,@WorkDay TINYINT = 3
		-- request type
		,@CheckInRequestTypeId TINYINT = 1
		,@CheckOutRequestTypeId TINYINT = 2
		,@LateInRequestTypeId TINYINT = 3
		,@EarlyOutRequestTypeId TINYINT = 4
		,@ChangeShiftRequestTypeId TINYINT = 5
		,@LeaveRequestTypeId TINYINT = 6
		,@KeepInViewRequestTypeId TINYINT = 7
		,@OvertimeRequestTypeId TINYINT = 8
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7

	CREATE TABLE #tblGroupIds (GroupId INT)

	CREATE TABLE #tblEmployeeIds (EmpId INT)

	CREATE TABLE #tblRequestIds (RequestId INT)

	CREATE TABLE #tblRequestInDaily (
		RequestId BIGINT
		,EmpId INT
		,RequestType TINYINT
		,InOutMins INT
		,ActualInOutMins INT
		,RequestedTime DATETIME
		,FromDate DATE
		,ToDate DATE
		,FromTime DATETIME
		,ToTime DATETIME
		,FromShift INT
		,ToShift INT
		,TotalDays NUMERIC(18, 1)
		,IsHalfDay BIT
		,KeepInViewType TINYINT
		)

	CREATE TABLE #tblGeneralLeaveDetail (
		RequestId BIGINT
		,LeaveCountDetails NVARCHAR(MAX)
		)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT val
		FROM dbo.fnc_strSplit(@TeamIds, ',')
	END

	INSERT INTO #tblEmployeeIds (EmpId)
	SELECT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN (
		SELECT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1, @CompanyId)
		) AS [member] ON emp.EmpId = [member].EmpId
	WHERE (
			@EmployeeStatusId IS NULL
			OR (
				@EmployeeStatusId = @Enable
				AND emp.[Enabled] = 1
				AND emp.isDeleted = 0
				)
			OR (
				@EmployeeStatusId = @Disabled
				AND emp.[Enabled] = 0
				AND emp.isDeleted = 0
				)
			OR (
				@EmployeeStatusId = @Deleted
				AND emp.isDeleted = 1
				)
			)
		AND (
			emp.NickName LIKE '%' + ISNULL(@Employee, '') + '%'
			OR emp.FullName LIKE '%' + ISNULL(@Employee, '') + '%'
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl
			WHERE tbl.GroupId = emp.GroupId
			)

	SELECT @FromDate = CONVERT(VARCHAR(10), @FromDate, 111)
		,@ToDate = DATEADD(ms, - 2, DATEADD(d, 1, CONVERT(VARCHAR(10), @ToDate, 111)))

	INSERT INTO #tblRequestIds (RequestId)
	SELECT req.RequestId
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid ON req.EmpId = empid.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = empid.EmpId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON req.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS leavereq WITH (NOLOCK) ON req.RequestId = leavereq.RequestId
		LEFT JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON req.RequestId = kiv.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS mio WITH (NOLOCK) ON req.RequestId = mio.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON req.RequestId = cs.RequestId
	WHERE (
			req.RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
			AND inout.OnDate BETWEEN @FromDate
					AND @ToDate
			)
		OR (
			req.RequestType = @LeaveRequestTypeId
			AND (
				(
					leavereq.FromDate BETWEEN @FromDate
						AND @ToDate
					AND leavereq.ToDate >= @ToDate
					)
				OR (
					leavereq.FromDate <= @FromDate
					AND leavereq.ToDate >= @ToDate
					)
				OR leavereq.ToDate BETWEEN @FromDate
					AND @ToDate
				)
			)
		OR (
			req.RequestType = @KeepInViewRequestTypeId
			AND kiv.OnDate BETWEEN @FromDate
				AND @ToDate
			)
		OR (
			req.RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId)
			AND mio.OnDate BETWEEN @FromDate
				AND @ToDate
			)
		OR (
			req.RequestType = @ChangeShiftRequestTypeId
			AND (
				(
					cs.FromDate BETWEEN @FromDate
						AND @ToDate
					AND cs.ToDate >= @ToDate
					)
				OR (
					cs.FromDate <= @FromDate
					AND cs.FromDate <= @ToDate
					AND cs.ToDate >= @ToDate
					)
				OR cs.ToDate BETWEEN @FromDate
					AND @ToDate
				)
			)

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,InOutMins
		,ActualInOutMins
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,inout.OnDate
		,inout.OnDate
		,0
		,CASE 
			WHEN req.RequestType = @LateInRequestTypeId THEN inout.LateInMins
			ELSE inout.EarlyOutMins
			END
		,CASE 
			WHEN req.RequestType = @LateInRequestTypeId THEN att.LateIn
			ELSE att.EarlyOut
			END
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON req.RequestId = inout.RequestId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON inout.EmpId = att.EmpId
		AND inout.OnDate = att.AttendanceDate

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,IsHalfDay
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,lr.FromDate
		,lr.ToDate
		,CASE 
			WHEN ldt.FromTime IS NULL THEN lr.FromDate
			ELSE ldt.FromTime
			END
		,CASE 
			WHEN ldt.ToTime IS NULL THEN lr.ToDate
			ELSE ldt.ToTime
			END
		,lr.TotalDays
		,1
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON req.RequestId = lr.RequestId
		LEFT JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
	WHERE lr.TotalDays = 0.5
		AND ldt.IsHalfDay = 1

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,IsHalfDay
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,lr.FromDate
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,0
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON req.RequestId = lr.RequestId
	WHERE lr.TotalDays <> 0.5

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,IsHalfDay
		,KeepInViewType
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,kiv.OnDate
		,kiv.OnDate
		,kiv.OnDate
		,kiv.FromTime
		,kiv.ToTime
		,CASE 
			WHEN kiv.IsHalfDay = 0 THEN 1
			ELSE 0.5
			END TotalDays
		,kiv.IsHalfDay
		,kiv.KeepInViewType
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON req.RequestId = kiv.RequestId

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,mio.RequestTime
		,mio.OnDate
		,mio.OnDate
		,1 AS TotalDays
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.CheckInOutRequest AS mio WITH (NOLOCK) ON req.RequestId = mio.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = mio.OnDate
		AND ec.EmpId = mio.EmpId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON mio.OnDate = att.AttendanceDate
		AND mio.EmpId = att.EmpId
	WHERE req.CurrentStatus = @ApprovedStatusId

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,mio.RequestTime
		,mio.OnDate
		,mio.OnDate
		,1 AS TotalDays
		,ec.ShiftID
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.CheckInOutRequest AS mio WITH (NOLOCK) ON req.RequestId = mio.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = mio.OnDate
		AND ec.EmpId = mio.EmpId
	WHERE req.CurrentStatus <> @ApprovedStatusId

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,ToShift
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,cs.FromDate
		,cs.ToDate
		,COUNT(1) AS TotalDays
		,MAX(csdt.FromShift) AS FromShift
		,MAX(csdt.ToShift) AS ToShift
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON req.RequestId = cs.RequestId
		INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON csdt.RequestId = cs.RequestId
	GROUP BY req.RequestId
		,req.EmpId
		,req.RequestType
		,cs.FromDate
		,cs.ToDate

	INSERT INTO #tblGeneralLeaveDetail (
		RequestId
		,LeaveCountDetails
		)
	SELECT DISTINCT wt.RequestId
		,STUFF((
				SELECT ', ' + CAST(SUM(LeaveDay) AS NVARCHAR(100)) + CASE 
						WHEN SUM(LeaveDay) > 1 THEN ' days '
						ELSE ' day '
						END + Code
				FROM (
					SELECT RequestId
						,CASE 
							WHEN IsOffDay = 1 THEN 'Off'
							ELSE CASE 
									WHEN IsHoliday = 1 THEN 'PH'
									ELSE Code
									END
							END AS Code
						,CASE 
							WHEN IsOffDay <> 1
								AND IsHoliday <> 1 THEN LeaveDay
							ELSE 1
							END AS LeaveDay
					FROM (
						SELECT ldt.RequestId
							,lt1.Code
							,CASE 
								WHEN ldt.IsHalfDay = 0 THEN 1
								ELSE 0.5
								END AS LeaveDay
							,CASE 
								WHEN ldt.WorkType = 1
									OR (
										WorkType IN (0, 3)
										AND cl.IsOffDay = 1
										) THEN 1
								ELSE 0
								END AS IsOffDay
							,CASE 
								WHEN ldt.WorkType = 1
									OR (
										WorkType IN (0, 3)
										AND cl.IsHoliday = 1
										) THEN 1
								ELSE 0
								END AS IsHoliday
						FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							INNER JOIN #tblRequestIds AS r ON r.RequestId = ldt.RequestId
							LEFT JOIN dbo.LeaveType AS lt1 WITH (NOLOCK) ON lt1.LeaveTypeId = ldt.LeaveType
                            AND lt1.CompanyId = @CompanyId
							LEFT JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON ldt.OnDate = cl.WorkDate
							AND ldt.EmpId = cl.EmpId
						WHERE ldt.WorkType <> 3
						) AS a
					) AS b
				WHERE b.RequestId = wt.RequestId
				GROUP BY b.RequestId
					,b.Code
				FOR XML PATH('')
				), 1, 2, '') AS LeaveCountDetails
	FROM (
		SELECT req.RequestId
			,req.CreatedDate
			,req.EmpId
		FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
			INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		) AS wt

	SELECT r.RequestId
		,r.RequestType AS RequestTypeId
		,r.Currentstatus AS RequestStatusId
		,r.CreatedDate
		,rd.RequestedTime AS RequestedDate
		,rd.FromDate
		,rd.ToDate
		,rd.TotalDays
		,rd.IsHalfDay
		,rd.FromTime
		,rd.ToTime
		,rd.KeepInViewType AS KeepInViewTypeId
		,gdt.LeaveCountDetails
		,r.Remark
		,rd.InOutMins AS TotalMinutes
		,rd.ActualInOutMins
		,(CASE 
			WHEN r.RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId, @ChangeShiftRequestTypeId, @KeepInViewRequestTypeId) THEN (CASE 
					WHEN s1.ShiftID IS NULL THEN 'OFF'
					ELSE s1.[Name] END
					)
			ELSE s3.[Name] END
			) AS FromShift
		,(CASE 
			WHEN s2.ShiftId IS NULL THEN 'OFF'
			ELSE s2.[Name] END
			) AS ToShift
		,lv.LeaveTypeId
		,lv.[Name] AS LeaveType
		,e.EmpId AS EmployeeId
		,e.NickName
		,e.FullName
		,g.[Name] AS Team
		,sec.[Name] AS Section
		,dep.[Name] AS Department
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS rq ON r.RequestId = rq.RequestId
		INNER JOIN #tblRequestInDaily AS rd ON r.RequestId = rd.RequestID
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS inoutmiss WITH (NOLOCK) ON r.RequestId = inoutmiss.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS csr WITH (NOLOCK) ON r.RequestId = csr.RequestId
		LEFT JOIN #tblGeneralLeaveDetail AS gdt ON r.RequestId = gdt.RequestId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = r.EmpId
		LEFT JOIN dbo.EmployeeCalendar AS c WITH (NOLOCK) ON c.empid = r.empid
		AND c.WorkDate = convert(VARCHAR(10), rd.FromDate, 111)
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftId = rd.FromShift
        AND s1.CompanyId = @CompanyId
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftId = rd.ToShift
        AND s2.CompanyId = @CompanyId
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftId = c.ShiftId
        AND s3.CompanyId = @CompanyId
		LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		LEFT JOIN dbo.Section AS sec WITH (NOLOCK) ON sec.SectionId = g.SectionId
		LEFT JOIN dbo.Department AS dep WITH (NOLOCK ) ON dep.DepartmentId = sec.DepartmentId
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeId = lr.LeaveType
        AND lv.CompanyId = @CompanyId
	ORDER BY r.CreatedDate DESC

	DROP TABLE #tblGroupIds

	DROP TABLE #tblEmployeeIds

	DROP TABLE #tblRequestInDaily

	DROP TABLE #tblGeneralLeaveDetail

	DROP TABLE #tblRequestIds
END