USE [bodb_HRM]
GO

DECLARE @CompanyId SMALLINT = 26;
DECLARE @CurrentTimeZone VARCHAR(50) = 'Taipei Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone VARCHAR(50) = 'SA Western Standard Time'; 
DECLARE @TimeZoneOffset VARCHAR(5) = 8; 
DECLARE @SiteId INT = 24;

INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
VALUES (@CompanyId, 'TimeZone', @TimeZoneOffset)

INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
VALUES (@CompanyId, 'SyncWorkingShift', '{"Enable": false,"LocationCode": "","Timezone":' + @TimeZoneOffset + '}')

INSERT INTO dbo.Mail_Config(AppName, [Description], SettingId, MailFrom, IsEncrypt)
VALUES ('Sandsdover', 'Sandsdover', 2, 'hrm.admin@enpine.com', 0)

DECLARE @AppMailId VARCHAR(50)

SELECT @AppMailId = AppId
FROM dbo.Mail_Config WITH (NOLOCK) WHERE AppName = 'Sandsdover'

INSERT INTO dbo.SystemConfigs([Key], [Value], [CompanyId])
VALUES ('MailSetting', '{"Enable": true, "AppMailId":' + @AppMailId +', "EmailSD": "", "EmailGo": ""}', @CompanyId)

INSERT INTO [dbo].[CompanySite]([CompanyId], [SiteId], [AccessToken], [Domain], [ModifiedDate])
VALUES (@CompanyId, @SiteId, 'cfJ8B8jtw7OeG19VpWYzNwcOHeL61uSim+elocTFoPw=', 'https://hrm-new.sandsdover.com', NULL),
    (@CompanyId, @SiteId, 'cfJ8B8jtw7OeG19VpWYzNwcOHeL61uSim+elocTFoPw=', 'https://hrm.sandsdover.com', NULL)
GO