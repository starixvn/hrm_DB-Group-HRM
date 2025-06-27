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
	and empca.IsLeaveDay = 1 AND empca.LeaveTypeId != lr.LeaveTypeId

DROP TABLE #tblLeaveRequest