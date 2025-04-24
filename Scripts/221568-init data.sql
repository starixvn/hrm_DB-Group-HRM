use bodb_HRM
go

insert into dbo.CompanySite (CompanyId, SiteId, AccessToken, Domain)
values (7, 35, '0/XDyxPbRr7gxtpufJiDMQCjTXnRmv4MpApxGdeozdU=', 'https://go.nexdev.net')

insert into dbo.SystemConfigs ([Key], [Value], CompanyId)
values ('TimeZone', '8', 7)
