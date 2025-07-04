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

DROP TABLE #tblHalfDayRequest