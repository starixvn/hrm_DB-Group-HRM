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
('Acora', 38, 'Acora HRM', 'Cnt9dwonueJHqMoBkIJrWaWvRyGbGoKgBJqRsKY6c5s=', 'https://hrm-acora.nexdev.net', 8),
('Ascentis', 28, 'Ascentis HRM', 'GNWs3aN7RfeYHirMuWGg5JXlmSP5HhhNcBk/y5WQbYY=', 'https://hrm-ascentis.nexdev.net', 8),
('BPO', 41, 'BPO HRM', 'HiJ0K7O02rCT9aZTzwCacBnPNmEPJAL6Pn3aykB6w9M=', 'https://hrm-bpo.nexdev.net', 8),
('EMC', 40, 'EMC HRM', 'rNbGnHoUEVUMDOvC67QYekzWTwS4tGVd/1BTyIBLmOk=', 'https://hrm-emc.nexdev.net', 8),
('FTS', 37, 'FTS HRM', 'Rv31qCV5cpI3J1QbIZQcIDPThudUr6nRz7NVfPwvXuk=', 'https://hrm-fts.nexdev.net', 8),
('Hyjay', 29, 'Hyjay HRM', '3i3LN8QmL90y/VLHVpoXf0jADEVzNrLYdeN00cEcrlI=', 'https://hrm-hyjay.nexdev.net', 8),
('Letstalk', 30, 'Letstalk HRM', 'o05Wfft4OuHlTFD/ii7pPKsEgEWPjNDIWpeW6EXXbcI=', 'https://hrm-letstalk.nexdev.net', 8),
('Next Fortune', 31, 'Next Fortune HRM', 'p9ViJmRSSo0IjYRkhuRFAGSCVVrMoIVcDsPkDF2Ta3o=', 'https://hrm-nexfortune.nexdev.net', 8),
('One Lab', 32, 'One Lab HRM', 'E5U2LkEzy71lis6TbNAak3GvNYtX6RMAQWqli/x+TZU=', 'https://hrm-onelab.nexdev.net', 8),
('OSEAS', 36, 'OSEAS HRM', '1mii5aPBU2hwUQMwY/r2+yeRRLZ97SvZU9BHvCzinUs=', 'https://hrm-oseas.nexdev.net', 8),
('SSI', 39, 'SSI HRM', 'pdSqXKdx2P3zrTBPOd9ixznAx27IZXuvLYgkmwJ1DJ0=', 'https://hrm-ssi.nexdev.net', 8);

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

--Insert SystemConfigs MailSetting
INSERT INTO dbo.SystemConfigs ([Key], [Value], CompanyId)
SELECT 'EnableGroupDate', 'true', c.CompanyId
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
