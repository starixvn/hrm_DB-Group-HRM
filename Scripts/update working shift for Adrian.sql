use bodb_HRM
go

update dbo.EmployeeCalendar with (rowlock)
set ShiftId=NULL
where EmpId = 211 and WorkDate >= '2025-04-28'