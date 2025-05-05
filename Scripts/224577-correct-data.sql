use bodb_HRM
go

delete tmp
from dbo.tmpEmployeeAttendace as tmp with (rowlock)
    inner join dbo.CompanyEmployee AS ce with (nolock) on tmp.EmpId = ce.EmpId
where ce.CompanyId = 9 and tmp.WorkDate <= '2025-05-01'