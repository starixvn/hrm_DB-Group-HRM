use bodb_HRM
go

update dbo.Company set [Name] = 'Ninetrix'
where CompanyId=29
go

update dbo.CompanySite set Domain = 'hrm-ntx.nexdev.net'
where CompanyId=29
go