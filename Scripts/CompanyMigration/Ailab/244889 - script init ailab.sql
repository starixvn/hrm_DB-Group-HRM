use bodb_HRM
go

insert into dbo.Company ([Name], CountryCode, IsActive)
values ('Consultech Ailab', 'UAE', 1)

declare @companyId smallint

select @companyId = CompanyId
from dbo.Company
where [Name] = 'Consultech Ailab'

insert into dbo.CompanySite (CompanyId, SiteId, AccessToken, Domain)
values (@companyId, 43, 'e0oafOZXTrAfApY5PFBc8LF6jiNjMNN4GKtLpM+UAAA=', 'https://hrm-ailab.ghrworld.com')

insert into dbo.SystemConfigs([Key], [Value], CompanyId)
values ('AnnualLeaveResetTimeLine', '1', @companyId)
    ,('EnableGroupDate', 'true', @companyId)
    ,('TimeZone', '11', @companyId)
    ,('IsShowSubCompany', 'false', @companyId)
    ,('SyncWorkingShift', '{"Enable": false,"LocationCode": "","Timezone": 11}', @companyId)
    ,('MailSetting', '{"Enable": false, "AppMailId": 0, "EmailSD": "", "EmailGo": ""}', @companyId)

insert into dbo.RefResource (RefName, ResourceId, [Value], CompanyId)
values ('LimitUseAnnualLeaveBalance', 1, 0, @companyId)
    ,('EnableAdditionalAnnualLeaveBalance', 1, 0, @companyId)
    ,('EnableOffdayReplacement', 1, 0, @companyId)
    ,('AnnualLeaveBalanceForLocal', 1, 0, @companyId)
    ,('AnnualLeaveBalanceForExpat', 1, 0, @companyId)
    ,('EnableHospitalizationLeaveBalance', 1, 0, @companyId)
    ,('EnableSickLeaveBalance', 1, 0, @companyId)

insert into dbo.LookupData (LookupId, Code, [Name], [Value], CompanyId)
select LookupId, Code, [Name], [Value], @companyId
from dbo.LookupData with (nolock)
where CompanyId = 3 and LookupId != 1

insert into dbo.LeaveType (
    LeaveTypeId, Code, [Name], IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction,
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, OrderNo, [Description], CompanyId)
select LeaveTypeId, Code, [Name], IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction,
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, OrderNo, NULL, @companyId
from dbo.LeaveType with (nolock)
where CompanyId = 3 and isShown=1