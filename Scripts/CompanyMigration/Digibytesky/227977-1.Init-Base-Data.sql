USE [bodb_HRM]
GO

DECLARE @CompanyId SMALLINT = 15;
DECLARE @CurrentTimeZone VARCHAR(50) = 'Taipei Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone VARCHAR(50) = 'SA Western Standard Time'; 
DECLARE @TimeZoneOffset VARCHAR(5) = 8; 
DECLARE @SiteId INT = 19;

INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
VALUES (@CompanyId, 'TimeZone', @TimeZoneOffset)

INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
VALUES (@CompanyId, 'SyncWorkingShift', '{"Enable": false,"LocationCode": "","Timezone":' + @TimeZoneOffset + '}')

INSERT INTO dbo.Mail_Config(AppName, [Description], SettingId, MailFrom, IsEncrypt)
VALUES ('Digibytesky', 'Digibytesky', 2, 'hrm.admin@enpine.com', 0)

DECLARE @AppMailId VARCHAR(50)

SELECT @AppMailId = AppId
FROM dbo.Mail_Config WITH (NOLOCK) WHERE AppName = 'Digibytesky'

INSERT INTO dbo.SystemConfigs([Key], [Value], [CompanyId])
VALUES ('MailSetting', '{"Enable": true, "AppMailId":' + @AppMailId +', "EmailSD": "", "EmailGo": ""}', @CompanyId)

INSERT INTO [dbo].[CompanySite]([CompanyId], [SiteId], [AccessToken], [Domain], [ModifiedDate])
VALUES (@CompanyId, @SiteId, 'cOt3qqoBLY/Lyxp4geFhMpKYRC8yDqD+jwe6DsHM9tM=', 'https://hrm-digibytesky.nexdev.net', NULL)
GO