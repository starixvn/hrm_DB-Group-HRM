USE bodb_HRM
GO

DECLARE @fromDate DATE = '2025-01-01'
    ,@toDate DATE = '2025-12-31'
DECLARE @OffDay TINYINT = 1
	,@LeaveDay TINYINT = 2
    -- request status
	,@PendingStatusId TINYINT = 1
	,@NotVerifiedStatusId TINYINT = 3
	,@RejectedStatusId TINYINT = 5
	,@VoidStatusId TINYINT = 7

-- leave request
CREATE TABLE #tblLeaveRequest (
	RequestId BIGINT
	,EmpId INT
	,WorkDate DATE
	,RequestTypeId SMALLINT
	,LeaveTypeId INT
	,WorkType TINYINT
	)

CREATE TABLE #tblHalfDayRequest (
	RequestId BIGINT
	,RequestTypeId SMALLINT
	,EmpId INT
	,WorkDate DATE
	,FromTime DATETIME
	,ToTime DATETIME
	,LeaveTypeId INT
	,WorkType TINYINT
	,LeaveDay DECIMAL(2, 1)
	)

INSERT INTO #tblLeaveRequest (
	RequestId
	,EmpId
	,WorkDate
	,RequestTypeId
	,LeaveTypeId
	,WorkType
	)
SELECT r.RequestId
	,empca.EmpId
	,empca.WorkDate
	,r.RequestType
	,lrdt.LeaveType
	,lrdt.WorkType
FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
	INNER JOIN dbo.LeaveRequestDetail AS lrdt WITH (NOLOCK) ON lrdt.EmpId = empca.EmpId
	AND lrdt.OnDate = empca.WorkDate
	AND lrdt.WorkType IN (@OffDay, @LeaveDay)
	AND lrdt.IsHalfDay = 0
	INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lrdt.RequestId = r.RequestId
	AND empca.EmpId = r.EmpId
	AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
WHERE empca.WorkDate BETWEEN @fromDate AND @toDate

INSERT INTO #tblLeaveRequest (
	RequestId
	,EmpId
	,WorkDate
	,RequestTypeId
	,LeaveTypeId
	,WorkType
	)
SELECT r.RequestId
	,empca.EmpId
	,empca.WorkDate
	,r.RequestType
	,lr.LeaveType
	,@LeaveDay AS WorkType
FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
	INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON lr.EmpId = empca.EmpId
	AND empca.WorkDate BETWEEN lr.FromDate AND lr.ToDate
	INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lr.RequestId = r.RequestId
	AND empca.EmpId = r.EmpId
	AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
WHERE empca.WorkDate BETWEEN @fromDate AND @toDate
	AND empca.IsOffDay = 0
	AND empca.IsHoliday = 0
    AND NOT EXISTS (
		SELECT 1
		FROM #tblLeaveRequest AS tblreq
		WHERE lr.RequestId = tblreq.RequestId
		)
	AND NOT EXISTS (
		SELECT ldt.RequestId
		FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
		WHERE lr.RequestId = ldt.RequestId
		)

UPDATE empca
SET empca.RequestId = lr.RequestId
	,empca.RequestTypeId = lr.RequestTypeId
	,empca.LeaveTypeId = lr.LeaveTypeId
	,empca.IsOffDay = CASE 
		WHEN lr.WorkType = @OffDay THEN 1
		ELSE empca.IsOffDay
		END
	,empca.IsLeaveDay = 1
	,empca.IsLeaveOffDay = CASE 
		WHEN lr.WorkType = @OffDay THEN 1
		ELSE 0
		END
	,empca.LeaveDay = 1
	,empca.FromTime = NULL
	,empca.ToTime = NULL
	,empca.LeaveTypeId2 = NULL
	,empca.FromTime2 = NULL
	,empca.ToTime2 = NULL
	,empca.ModifiedDate = GETDATE()
FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK)
	INNER JOIN #tblLeaveRequest AS lr ON empca.EmpId = lr.EmpId
	AND empca.WorkDate = lr.WorkDate
WHERE empca.WorkDate BETWEEN @fromDate AND @toDate
	AND lr.RequestId IS NOT NULL
	AND empca.IsLeaveDay = 0

INSERT INTO #tblHalfDayRequest (
	RequestId
	,RequestTypeId
	,EmpId
	,WorkDate
	,FromTime
	,ToTime
	,LeaveTypeId
	,WorkType
	,LeaveDay
	)
SELECT r.RequestId
	,r.RequestType
	,r.EmpId
	,lrdt.OnDate
	,lrdt.FromTime
	,lrdt.ToTime
	,lrdt.LeaveType
	,lrdt.WorkType
	,0.5 AS LeaveDay
FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON r.EmpId = ce.EmpId
	INNER JOIN dbo.LeaveRequestDetail AS lrdt WITH (NOLOCK) ON r.RequestId = lrdt.RequestId
	AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	AND lrdt.IsHalfDay = 1
	AND lrdt.WorkType = @LeaveDay
	AND lrdt.OnDate BETWEEN @fromDate AND @toDate
	INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.CompanyId = ce.CompanyId
    AND lrdt.LeaveType = lv.LeaveTypeId

UPDATE empca
SET empca.RequestId = lr.RequestId
	,empca.RequestTypeId = lr.RequestTypeId
	,empca.IsLeaveDay = 1
	,empca.LeaveDay = 0.5
	,empca.LeaveTypeId = lr.LeaveTypeId
	,empca.FromTime = lr.FromTime
	,empca.ToTime = lr.ToTime
	,empca.ModifiedDate = GETDATE()
FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
	INNER JOIN #tblHalfDayRequest AS lr ON empca.EmpId = lr.EmpId
    AND empca.WorkDate = lr.WorkDate
WHERE empca.WorkDate BETWEEN @fromDate AND @toDate
	AND empca.IsLeaveDay = 0

DROP TABLE #tblLeaveRequest

DROP TABLE #tblHalfDayRequest