/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_MonthlyWorkingHours_EmployeeRequest]
(
    @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@Employee NVARCHAR(200) = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
	,@EmployeeStatusIds VARCHAR(10) = ''
)
AS
/*
    Created: Tim.Trinh@2019-08-20
    Task: get employee request
    DB: bodb_HRM

    Revisions:
        -20250417@Tim: get Unit Code [Redmine: #224530]
        -20250813@Jay: change db structure [Redmine: #235678]
        -20250919@Tim: user status filter [Redmine: #239089]
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
    DECLARE @tblStatus TABLE (Id TINYINT)

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
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
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
		INNER JOIN dbo.Employee AS e (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		INNER JOIN (
		SELECT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1, @CompanyId)
		) AS [member] ON ce.EmpId = [member].EmpId
	WHERE (
			@EmployeeStatusIds IS NULL
            OR EXISTS (
                SELECT 1
                FROM @tblStatus AS s
                WHERE (s.Id = @Enable AND ce.[Enabled] = 1 AND ce.isDeleted = 0)
                    OR (s.Id = @Disabled AND ce.[Enabled] = 0 AND ce.isDeleted = 0)
                    OR (s.Id = @Deleted AND ce.isDeleted = 1)
                )
			)
		AND (
			ce.NickName LIKE '%' + ISNULL(@Employee, '') + '%'
			OR e.FullName LIKE '%' + ISNULL(@Employee, '') + '%'
			)
		AND (
			@IsLocal IS NULL
			OR es.IsLocal = @IsLocal
			)
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl
			WHERE tbl.GroupId = ce.GroupId
			)

	INSERT INTO #tblRequestIds (RequestId)
	SELECT req.RequestId
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid ON req.EmpId = empid.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = empid.EmpId
	WHERE (
			req.RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
            AND EXISTS (
                SELECT 1
                FROM dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) 
                WHERE req.RequestId = inout.RequestId
                    AND inout.OnDate BETWEEN @FromDate AND @ToDate
                )
			)
		OR (
			req.RequestType = @LeaveRequestTypeId
            AND EXISTS (
                SELECT 1
                FROM dbo.LeaveRequest AS lr WITH (NOLOCK)
                WHERE req.RequestId = lr.RequestId
                    AND (
				        (
					        lr.FromDate BETWEEN @FromDate AND @ToDate
					        AND lr.ToDate >= @ToDate
					        )
				        OR (
					        lr.FromDate <= @FromDate
					        AND lr.ToDate >= @ToDate
					        )
				        OR lr.ToDate BETWEEN @FromDate AND @ToDate
				    )
                )
			)
		OR (
			req.RequestType = @KeepInViewRequestTypeId
            AND EXISTS (
                SELECT 1
                FROM dbo.KeepInViewRequest AS kiv WITH (NOLOCK)
                WHERE req.RequestId = kiv.RequestId
                    AND kiv.OnDate BETWEEN @FromDate AND @ToDate
                )
			)
		OR (
			req.RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId)
            AND EXISTS (
                SELECT 1
                FROM dbo.CheckInOutRequest AS mio WITH (NOLOCK)
                WHERE req.RequestId = mio.RequestId
			        AND mio.OnDate BETWEEN @FromDate AND @ToDate
                )
			)
		OR (
			req.RequestType = @ChangeShiftRequestTypeId
            AND EXISTS (
                SELECT 1
                FROM dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
                WHERE req.RequestId = cs.RequestId
			        AND (
				        (
					        cs.FromDate BETWEEN @FromDate AND @ToDate
					        AND cs.ToDate >= @ToDate
					        )
				        OR (
					        cs.FromDate <= @FromDate
					        AND cs.FromDate <= @ToDate
					        AND cs.ToDate >= @ToDate
					        )
				        OR cs.ToDate BETWEEN @FromDate AND @ToDate
				        )
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
		AND CAST(inout.OnDate AS DATETIME) = att.AttendanceDate

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
		,ce.EmpId AS EmployeeId
		,ce.NickName
		,e.FullName
        ,g.Code AS TeamCode
		,g.[Name] AS TeamName
        ,dep.Code AS DepartmentCode
		,dep.[Name] AS DepartmentName
        ,u.Code AS UnitCode
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = r.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupId = g.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK ) ON dep.DepartmentId = g.DepartmentId
        INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON dep.UnitId = u.UnitId
		INNER JOIN #tblRequestIds AS rq ON r.RequestId = rq.RequestId
		INNER JOIN #tblRequestInDaily AS rd ON r.RequestId = rd.RequestID
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS inoutmiss WITH (NOLOCK) ON r.RequestId = inoutmiss.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS csr WITH (NOLOCK) ON r.RequestId = csr.RequestId
		LEFT JOIN #tblGeneralLeaveDetail AS gdt ON r.RequestId = gdt.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS c WITH (NOLOCK) ON c.empid = r.empid
		AND c.WorkDate = convert(VARCHAR(10), rd.FromDate, 111)
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftId = rd.FromShift
        AND s1.CompanyId = @CompanyId
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftId = rd.ToShift
        AND s2.CompanyId = @CompanyId
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftId = c.ShiftId
        AND s3.CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeId = lr.LeaveType
        AND lv.CompanyId = @CompanyId
	ORDER BY r.CreatedDate DESC

	DROP TABLE #tblGroupIds

	DROP TABLE #tblEmployeeIds

	DROP TABLE #tblRequestInDaily

	DROP TABLE #tblGeneralLeaveDetail

	DROP TABLE #tblRequestIds
END