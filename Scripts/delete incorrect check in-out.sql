use bodb_HRM
go

delete t
from dbo.TimeRecord as t
	inner join dbo.Employee as e on t.EmpId = e.EmpId
	inner join dbo.CompanyEmployee as ce on e.EmpId = ce.EmpId
	left join dbo.TimeRecordExt AS ext on t.Id = ext.ID
where ce.CompanyId = 9 -- cabintech
	and t.RecordTime >= '2025-06-02'
	and ext.Id is null