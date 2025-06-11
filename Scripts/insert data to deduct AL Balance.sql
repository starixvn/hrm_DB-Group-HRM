INSERT INTO dbo.tmpLeaveBalance (EmpId, RequestId, TotalDays, InYear, InMonth, [Status])
SELECT lr.EmpId, lr.RequestId, lr.TotalDays, YEAR(lr.FromDate), MONTH(lr.FromDate), CASE WHEN r.CurrentStatus IN (1, 2) THEN 0 ELSE 1 END
FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
    INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON lr.EmpId = e.EmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE lr.LeaveType = 2 -- annual leave
    AND ce.CompanyId = 6
    AND r.CurrentStatus IN (1, 2, 4, 6)
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.tmpLeaveBalance AS tmpbl WITH (NOLOCK)
        WHERE e.EmpId = tmpbl.EmpId
            AND r.RequestId = tmpbl.RequestId
    )

INSERT INTO dbo.tmpLeaveBalance (EmpId, RequestId, TotalDays, InYear, InMonth, [Status])
SELECT lr.EmpId, lr.RequestId, CASE WHEN ldt.IsHalfDay = 1 THEN 0.5 ELSE 1 END, YEAR(ldt.OnDate), MONTH(ldt.OnDate), CASE WHEN r.CurrentStatus IN (1, 2) THEN 0 ELSE 1 END
FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
    INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
    INNER JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON lr.EmpId = e.EmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE lr.LeaveType = 0 -- general leave
    AND ldt.LeaveType = 2 -- annual leave
    AND ce.CompanyId = 6
    AND r.CurrentStatus IN (1, 2, 4, 6)
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.tmpLeaveBalance AS tmpbl WITH (NOLOCK)
        WHERE e.EmpId = tmpbl.EmpId
            AND r.RequestId = tmpbl.RequestId
    )

INSERT INTO dbo.LeaveTrans (EmpId, RequestId, [Description], FromDate, ToDate, DeductDays, CreditDays, Deleted)
SELECT lr.EmpId, lr.RequestId, 'Leave Request', lr.FromDate, lr.ToDate, lr.TotalDays, 0, 0
FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
    INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON lr.EmpId = e.EmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE lr.LeaveType = 2 -- annual leave
    AND ce.CompanyId = 6
    AND r.CurrentStatus IN (4, 6)
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.LeaveTrans AS ltrans WITH (NOLOCK)
        WHERE e.EmpId = ltrans.EmpId
            AND r.RequestId = ltrans.RequestId
    )

INSERT INTO dbo.LeaveTrans (EmpId, RequestId, [Description], FromDate, ToDate, DeductDays, CreditDays, Deleted)
SELECT lr.EmpId, lr.RequestId, 'Leave Request', ldt.OnDate, ldt.OnDate, CASE WHEN ldt.IsHalfDay = 1 THEN 0.5 ELSE 1 END, 0, 0
FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
    INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
    INNER JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON lr.EmpId = e.EmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE lr.LeaveType = 0 -- general leave
    AND ldt.LeaveType = 2 -- annual leave
    AND ce.CompanyId = 6
    AND r.CurrentStatus IN (4, 6)
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.LeaveTrans AS ltrans WITH (NOLOCK)
        WHERE e.EmpId = ltrans.EmpId
            AND r.RequestId = ltrans.RequestId
    )