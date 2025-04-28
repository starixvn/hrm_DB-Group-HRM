use bodb_HRM
go

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
WHERE emp.[Enabled] = 1
	AND ISNULL(emp.IsDeleted, 0) = 0
	AND empca.WorkDate in ('2025-04-30', '2025-05-01')
	AND empca.IsHoliday = 0
	AND (empsum.IsLocal = 1 OR empsum.IsExpatUseHoliday = 1)