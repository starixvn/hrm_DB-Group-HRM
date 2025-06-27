use bodb_HRM
go

UPDATE dbo.EmployeeCalendar
SET IsHoliday = 0
WHERE EmpId IN (4826, 4835, 5253)
	AND WorkDate = '2025-08-03'