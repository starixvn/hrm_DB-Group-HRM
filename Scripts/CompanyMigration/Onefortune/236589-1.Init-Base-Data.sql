USE [bodb_HRM]
GO

DECLARE @CompanyId INT = 21;
DECLARE @CurrentTimeZone VARCHAR(50) = 'Taipei Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone VARCHAR(50) = 'SA Western Standard Time'; 
DECLARE @TimeZoneOffset VARCHAR(5) = 8; 
DECLARE @SiteId INT = 23;

INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
VALUES (@CompanyId, 'TimeZone', CAST(@TimeZoneOffset AS VARCHAR(1))),
    (@CompanyId, 'SyncWorkingShift', '{"Enable": false,"LocationCode": "","Timezone":' + CAST(@TimeZoneOffset AS VARCHAR(1)) + '}'),
    --(@CompanyId, 'EnableGroupDate', 'true'),
    (@CompanyId, 'AnnualLeaveResetTimeLine', '1')

INSERT INTO dbo.Mail_Config(AppName, [Description], SettingId, MailFrom, IsEncrypt)
VALUES ('One Fortune', 'One Fortune', 2, 'hrm.admin@enpine.com', 0)

DECLARE @AppMailId VARCHAR(50) = (SELECT TOP 1 AppId FROM dbo.Mail_Config WHERE AppName = 'One Fortune');
INSERT INTO dbo.SystemConfigs([Key], [Value], [CompanyId])
VALUES ('MailSetting', '{"Enable": true, "AppMailId":' + @AppMailId +', "EmailSD": "", "EmailGo": ""}', @CompanyId)

INSERT INTO [dbo].[CompanySite]([CompanyId], [SiteId], [AccessToken], [Domain], [ModifiedDate])
VALUES (@CompanyId, @SiteId, 'Mlmr9ZBsCHdpBAvoc88xoTZuVowfMckRguMNlBHEzWo=', 'https://hrm-new.onefortuneproperty.com', NULL),
    (@CompanyId, @SiteId, 'Mlmr9ZBsCHdpBAvoc88xoTZuVowfMckRguMNlBHEzWo=', 'https://hrm.onefortuneproperty.com', NULL)
GO