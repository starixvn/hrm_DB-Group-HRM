use [bodb_HRM]
go

update [dbo].[Shift] with (rowlock)
set IsDisabled = 1
where ShiftId=408
go

exec [dbo].[EmployeeAttendance_ProcessingAndInsert] @empId = 3816
	,@fromTime = '2025-04-19'
	,@toTime = '2025-04-19'
	,@onlyUpdate = 0
    ,@CompanyId = 3
go

exec [dbo].[EmployeeAttendance_ProcessingAndInsert] @empId = 4182
	,@fromTime = '2025-04-19'
	,@toTime = '2025-04-19'
	,@onlyUpdate = 0
    ,@CompanyId = 3