USE bodb_HRM
GO

/*
delete tmp
from dbo.tmpEmployeeAttendace as tmp with (rowlock)
    inner join dbo.CompanyEmployee AS ce with (nolock) on tmp.EmpId = ce.EmpId
where ce.CompanyId = 9 and tmp.WorkDate <= '2025-05-01'

UPDATE empca
SET empca.IsHoliday = 1
	,empca.IsOffDay = 0
	,empca.ModifiedDate = GETDATE()
FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
	INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
	INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
	LEFT JOIN dbo.Holiday AS holiday WITH (NOLOCK) ON ce.CompanyId = holiday.CompanyId
    AND empca.WorkDate BETWEEN holiday.FromDate
		AND holiday.ToDate
WHERE ce.CompanyId = 3
    AND emp.[Enabled] = 1
	AND ISNULL(emp.IsDeleted, 0) = 0
	AND empca.WorkDate in ('2025-04-30', '2025-05-01')
	AND empca.IsHoliday = 0
	AND (empsum.IsLocal = 1 OR empsum.IsExpatUseHoliday = 1)
GO

UPDATE empca
SET empca.IsHoliday = 0
	,empca.ModifiedDate = GETDATE()
FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK)
	INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
WHERE ce.CompanyId = 3
	AND empca.WorkDate = '2025-06-12'
	AND empca.IsHoliday = 1
*/

-- missing Management Level
SET IDENTITY_INSERT dbo.ManagementLevel ON 
GO
INSERT dbo.ManagementLevel (ManagementLevelId, [Name], IsDeleted, ModifiedBy, ModifiedDate)
VALUES (1, N'M1-A', 0, NULL, GETDATE()),
    (2, N'M1-B', 0, NULL, GETDATE()),
    (3, N'M2-A', 0, NULL, GETDATE()),
    (4, N'M2-B', 0, NULL, GETDATE()),
    (5, N'M3-A', 0, NULL, GETDATE()),
    (6, N'M3-B', 0, NULL, GETDATE()),
    (7, N'M4', 0, NULL, GETDATE()),
    (8, N'M5', 0, NULL, GETDATE()),
    (9, N'M6', 0, NULL, GETDATE()),
    (10, N'M7', 0, NULL, GETDATE())
GO
SET IDENTITY_INSERT dbo.ManagementLevel OFF
GO

-- missing CL
INSERT INTO dbo.KeepInViewByDayTrans (EmpId, RequestId, CreditDays, DeductDays, InYear)
SELECT e.UserId, -e.UserId, trans.CreditDays, trans.DeductDays, trans.InYear
FROM CabintechHRM.dbo.KeepInViewByDayTrans AS trans WITH (NOLOCK)
    INNER JOIN CabintechHRM.dbo.Employee AS e WITH (NOLOCK) ON trans.EmpId = e.EmpId
WHERE trans.RequestId <= 0
GO

-- enable Sick Leave
UPDATE dbo.LeaveType WITH (ROWLOCK)
SET isShown = 1
WHERE CompanyId = 6 AND LeaveTypeId = 29
GO

UPDATE dbo.RefResource WITH (ROWLOCK)
SET [Value] = '1'
WHERE CompanyId = 6
    AND RefName = 'EnableSickLeaveBalance'
GO