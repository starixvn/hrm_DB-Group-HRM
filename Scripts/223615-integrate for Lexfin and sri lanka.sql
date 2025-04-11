use bodb_HRM
go

set identity_insert dbo.Company on
insert into dbo.Company(CompanyId, [Name], CountryCode, IsActive)
values (29, 'Sri Lanka', 'SLK', 1)
set identity_insert dbo.Company off
go

declare @LexfinCompanyId SMALLINT = 6
    ,@SriLankaCompanyId SMALLINT = 29
    ,@SMSCompanyId SMALLINT = 3

insert into dbo.CompanySite (CompanyId, SiteId, AccessToken, Domain)
values (@LexfinCompanyId, 15, '7eVoo8qcGF+U7yxITZgSAXQHnYjFcrHi0bPCmkZeq/k=', 'https://hrm-lexfin.nexdev.net')
    ,(@SriLankaCompanyId, 33, 'tZ08DhV/cwk14FQI0jqfQ8KHHFgQiimmxcWA0IqPS4M=', 'https://hrm-slk.nexdev.net')

insert into dbo.SystemConfigs ([Key], [Value], CompanyId)
values ('TimeZone', '8', @LexfinCompanyId)
    ,('SyncWorkingShift', '{"Enable": false,"LocationCode": "","Timezone": 8}', @LexfinCompanyId)
    ,('MailSetting', '{"Enable": true, "AppMailId": 2, "EmailSD": "", "EmailGo": ""}', @LexfinCompanyId)
    ,('TimeZone', '5.5', @SriLankaCompanyId)
    ,('SyncWorkingShift', '{"Enable": false,"LocationCode": "","Timezone": 5.5}', @SriLankaCompanyId)
    ,('MailSetting', '{"Enable": true, "AppMailId": 3, "EmailSD": "", "EmailGo": ""}', @SriLankaCompanyId)

set identity_insert dbo.Mail_Setting on 
insert into dbo.Mail_Setting(SettingId, SettingName, IsAuth, [Username], [Password], [Server], [Port])
values (2, 'mail.enpine.com:465 (hrm.admin@enpine.com)', 1, 'hrm.admin@enpine.com', 'Welcome@2025!', 'mail.enpine.com', 465)
set identity_insert dbo.Mail_Setting off

set identity_insert dbo.Mail_Config on 
insert into dbo.Mail_Config(AppId, AppName, [Description], SettingId, MailFrom, IsEncrypt)
values (2, 'Lexfin', 'Lexfin', 2, 'hrm.admin@enpine.com', 0)
    ,(3, 'Sri Lanka', 'Sri Lanka', 2, 'hrm.admin@enpine.com', 0)
set identity_insert dbo.Mail_Config off

insert into dbo.RefResource (RefName, ResourceId, [Value], IsActive, CompanyId)
values ('LimitUseAnnualLeaveBalance', 1, '0', 1, @LexfinCompanyId)
    ,('EnableAdditionalAnnualLeaveBalance', 1, '0', 1, @LexfinCompanyId)
    ,('EnableOffdayReplacement', 1, '0', 1, @LexfinCompanyId)
    ,('AnnualLeaveBalanceForLocal', 1, '0', 1, @LexfinCompanyId)
    ,('AnnualLeaveBalanceForExpat', 1, '0', 1, @LexfinCompanyId)
    ,('EnableHospitalizationLeaveBalance', 1, '0', 1, @LexfinCompanyId)
    ,('EnableSickLeaveBalance', 1, '0', 1, @LexfinCompanyId)
    -- sri lanka
    ,('LimitUseAnnualLeaveBalance', 1, '0', 1, @SriLankaCompanyId)
    ,('EnableAdditionalAnnualLeaveBalance', 1, '0', 1, @SriLankaCompanyId)
    ,('EnableOffdayReplacement', 1, '0', 1, @SriLankaCompanyId)
    ,('AnnualLeaveBalanceForLocal', 1, '0', 1, @SriLankaCompanyId)
    ,('AnnualLeaveBalanceForExpat', 1, '0', 1, @SriLankaCompanyId)
    ,('EnableHospitalizationLeaveBalance', 1, '0', 1, @SriLankaCompanyId)
    ,('EnableSickLeaveBalance', 1, '0', 1, @SriLankaCompanyId)

-- leave type
insert into dbo.LeaveType (
    LeaveTypeId, Code, Name, IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction,
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, OrderNo, Description, CompanyId)
select LeaveTypeId, Code, Name, IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction,
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, OrderNo, Description, @LexfinCompanyId 
from dbo.LeaveType with (nolock)
where CompanyId = @SMSCompanyId

insert into dbo.LeaveType (
    LeaveTypeId, Code, Name, IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction,
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, OrderNo, Description, CompanyId)
select LeaveTypeId, Code, Name, IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction,
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, OrderNo, Description, @SriLankaCompanyId 
from dbo.LeaveType with (nolock)
where CompanyId = @SMSCompanyId

-- shift
insert into dbo.[Shift] (Code, [Name], BeginCheckInTime, EndCheckInTime, BeginCheckOutTime, EndCheckOutTime, BreakTimeMins, OrderNo, CrossDay, Color, TotalHours
    ,IsInAfterDay, IsOutAfterDay, IsDisabled, CompanyId, OldShiftId)
select Code, [Name], BeginCheckInTime, EndCheckInTime, BeginCheckOutTime, EndCheckOutTime, BreakTimeMins, OrderNo, CrossDay, Color, TotalHours
    ,IsInAfterDay, IsOutAfterDay, IsDisabled, @LexfinCompanyId, OldShiftId
from dbo.[Shift] with (nolock)
where CompanyId = @SMSCompanyId and IsDisabled = 0 and ISNULL(Code, '') != ''

insert into dbo.[Shift] (Code, [Name], BeginCheckInTime, EndCheckInTime, BeginCheckOutTime, EndCheckOutTime, BreakTimeMins, OrderNo, CrossDay, Color, TotalHours
    ,IsInAfterDay, IsOutAfterDay, IsDisabled, CompanyId, OldShiftId)
select Code, [Name], BeginCheckInTime, EndCheckInTime, BeginCheckOutTime, EndCheckOutTime, BreakTimeMins, OrderNo, CrossDay, Color, TotalHours
    ,IsInAfterDay, IsOutAfterDay, IsDisabled, @SriLankaCompanyId, OldShiftId
from dbo.[Shift] with (nolock)
where CompanyId = @SMSCompanyId and IsDisabled = 0 and ISNULL(Code, '') != ''

-- lookup data
insert into dbo.LookupData (LookupId, Code, [Name], [Value], CompanyId)
select LookupId, Code, [Name], [Value], @LexfinCompanyId
from dbo.LookupData with (nolock)
where CompanyId = @SMSCompanyId and LookupId != 1

insert into dbo.LookupData (LookupId, Code, [Name], [Value], CompanyId)
select LookupId, Code, [Name], [Value], @SriLankaCompanyId
from dbo.LookupData with (nolock)
where CompanyId = @SMSCompanyId and LookupId != 1
