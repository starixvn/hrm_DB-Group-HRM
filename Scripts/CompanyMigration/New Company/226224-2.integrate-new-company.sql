--BEGIN TRANSACTION

USE [bodb_HRM]
GO

DECLARE @SMSCompanyId INT = 3;
DECLARE @tmpCompany TABLE (
    CompanyId INT,
    CompanyName NVARCHAR(100),
    SiteId INT,
    SiteName NVARCHAR(100),
    AccessToken NVARCHAR(200),
    SiteURL NVARCHAR(200),
    TimeZone INT,
    AppId INT
);

INSERT INTO @tmpCompany (CompanyName, SiteId, SiteName, AccessToken, SiteURL, TimeZone) VALUES
('Acora', 30, 'Acora HRM', 'D/R5zQnWEhRB4hcnLOAOYpByEI+Oo/j7T2gZiV2t+dk=', 'https://acora.klc.nexdev.net', 8),
('Ascentis', 31, 'Ascentis HRM', 'B3v8FzV19t4uMcQUDwEuFkIPMIWPd+fnFLbtEmOSDrQ=', 'https://ascentis.klc.nexdev.net', 8),
('BPO', 32, 'BPO HRM', 'OVoIac/+43Va3oshwlsh6MXTAVAVbkhLRfKvyZbOiGI=', 'https://bpo.klc.nexdev.net', 8),
('DAR', 33, 'DAR HRM', 'AMSLTPLopOWGKnlbsEsfKn2M7WlGF9MOW5jlN1Tec9M=', 'https://dar.klc.nexdev.net', 7),
('EMC', 34, 'EMC HRM', 'Rnkkq74y7idh3gczIqbOUtxhIaqPo2OgindFp92c6Pk=', 'https://emc.klc.nexdev.net', 8),
('FTS', 35, 'FTS HRM', 'a+6ccsNlqFSq7EyS+5tYwJ38UE7jG8JAkSBjTRIu9dw=', 'https://fts.klc.nexdev.net', 8),
('Hyjay', 36, 'Hyjay HRM', 'u6z/lVQQZl/Ht1xAgS/4oTTkWQIH7j+bDDhHV5cNBQg=', 'https://hyjay.klc.nexdev.net', 8),
('Letstalk', 37, 'LT HRM', 'PYyvyOqKFhAxNMrMFUsCba3BM0c5+LON+c7eg1LzKuU=', 'https://lt.klc.nexdev.net', 8),
('Next Fortune', 38, 'Next Fortune HRM', 'uoTWF3w0c/mnz63fKDkWtFRC95n+J+TBEmI0kzDdMDs=', 'https://ascentis.klc.nexdev.net', 8),
('One Lab', 39, 'One Lab HRM', 'k+0Kuyr4yp57za+A84TFj2nIjb2hWvmZg/m/c0NI/sw=', 'https://oneLab.klc.nexdev.net', 8),
('OSEAS', 40, 'OSEAS HRM', 'VMvYdwQ3qlIN8W7DdxLIY5G+EFAAOpwW/X9R7geXRxE=', 'https://oseas.klc.nexdev.net', 8),
('SSI', 41, 'SSI HRM', 'kDOSvQKy1079KPhcY79leU9POAYLswmbpVxgUcyfFyc=', 'https://ssi.klc.nexdev.net', 8);

--Insert Company
INSERT INTO dbo.Company(Name, CountryCode, IsActive)
SELECT t.CompanyName, 'TW', 1
FROM @tmpCompany t
LEFT JOIN dbo.Company c WITH(NOLOCK) ON c.Name = t.CompanyName
WHERE c.CompanyId IS NULL;

--Update companyId
UPDATE t
SET CompanyId = c.CompanyId
FROM @tmpCompany t
INNER JOIN dbo.Company c WITH(NOLOCK) ON c.Name = t.CompanyName

--Insert CompanySite
INSERT INTO dbo.CompanySite (CompanyId, SiteId, AccessToken, Domain)
SELECT c.CompanyId, t.SiteId, t.AccessToken, t.SiteURL
FROM @tmpCompany t
INNER JOIN dbo.Company c WITH(NOLOCK) ON c.Name = t.CompanyName;

-- Mail Config
INSERT INTO dbo.Mail_Config(AppName, [Description], SettingId, MailFrom, IsEncrypt)
SELECT t.CompanyName, t.CompanyName, 2, 'hrm.admin@enpine.com', 0
FROM @tmpCompany t
INNER JOIN dbo.Company c WITH(NOLOCK) ON c.Name = t.CompanyName;

UPDATE t
SET t.AppId = mc.AppId
FROM @tmpCompany t
JOIN dbo.Mail_Config mc ON t.CompanyName = mc.AppName;

--Insert SystemConfigs TimeZone
INSERT INTO dbo.SystemConfigs ([Key], [Value], CompanyId)
SELECT 'TimeZone', t.TimeZone, c.CompanyId
FROM @tmpCompany t
INNER JOIN dbo.Company c WITH(NOLOCK) ON c.Name = t.CompanyName;

--Insert SystemConfigs SyncWorkingShift
INSERT INTO dbo.SystemConfigs ([Key], [Value], CompanyId)
SELECT 'SyncWorkingShift', '{"Enable": false,"LocationCode": "","Timezone": ' + CAST(t.TimeZone AS NVARCHAR(10)) + '}', c.CompanyId
FROM @tmpCompany t
INNER JOIN dbo.Company c WITH(NOLOCK) ON c.Name = t.CompanyName;

--Insert SystemConfigs MailSetting
INSERT INTO dbo.SystemConfigs ([Key], [Value], CompanyId)
SELECT 'MailSetting', '{"Enable": true, "AppMailId": ' + CAST(t.AppId AS NVARCHAR(10)) + ', "EmailSD": "", "EmailGo": ""}', c.CompanyId
FROM @tmpCompany t
INNER JOIN dbo.Company c WITH(NOLOCK) ON c.Name = t.CompanyName;

-- Insert into RefResource for each company and resource
WITH ResourceList AS (
    SELECT RefName FROM (VALUES
        ('LimitUseAnnualLeaveBalance'),
        ('EnableAdditionalAnnualLeaveBalance'),
        ('EnableOffdayReplacement'),
        ('AnnualLeaveBalanceForLocal'),
        ('AnnualLeaveBalanceForExpat'),
        ('EnableHospitalizationLeaveBalance'),
        ('EnableSickLeaveBalance')
    ) AS R(RefName)
)
INSERT INTO dbo.RefResource (RefName, ResourceId, [Value], IsActive, CompanyId)
SELECT 
    r.RefName,
    1,
    '0',
    1,
    c.CompanyId
FROM @tmpCompany t
INNER JOIN dbo.Company c WITH(NOLOCK) ON c.Name = t.CompanyName
CROSS JOIN ResourceList r;

-- Insert into LeaveType
insert into dbo.LeaveType (
    LeaveTypeId, Code, Name, IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction,
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, OrderNo, Description, CompanyId)
select LeaveTypeId, Code, Name, IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction,
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, OrderNo, Description, t.CompanyId
from dbo.LeaveType l with (nolock)
cross join @tmpCompany t
where l.CompanyId = @SMSCompanyId

--Insert Shift
insert into dbo.[Shift] (Code, [Name], BeginCheckInTime, EndCheckInTime, BeginCheckOutTime, EndCheckOutTime, BreakTimeMins, OrderNo, CrossDay, Color, TotalHours
    ,IsInAfterDay, IsOutAfterDay, IsDisabled, CompanyId, OldShiftId)
select Code, [Name], BeginCheckInTime, EndCheckInTime, BeginCheckOutTime, EndCheckOutTime, BreakTimeMins, OrderNo, CrossDay, Color, TotalHours
    ,IsInAfterDay, IsOutAfterDay, IsDisabled, t.CompanyId, OldShiftId
from dbo.[Shift] s with (nolock)
cross join @tmpCompany t
where s.CompanyId = @SMSCompanyId and s.IsDisabled = 0 and ISNULL(Code, '') != ''

-- lookup data
insert into dbo.LookupData (LookupId, Code, [Name], [Value], CompanyId)
select LookupId, Code, [Name], [Value], t.CompanyId
from dbo.LookupData l with (nolock)
cross join @tmpCompany t
where l.CompanyId = @SMSCompanyId and l.LookupId != 1


--ROLLBACK