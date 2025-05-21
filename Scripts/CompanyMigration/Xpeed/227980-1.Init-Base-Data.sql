USE [bodb_HRM]
GO

DECLARE @CompanyId INT = 28;
DECLARE @CurrentTimeZone VARCHAR(50) = 'Taipei Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone VARCHAR(50) = 'SA Western Standard Time'; 
DECLARE @TimeZoneOffset VARCHAR(5) = 8; 
DECLARE @SiteId INT = 25;

INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
VALUES (@CompanyId, 'TimeZone', @TimeZoneOffset)

INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
VALUES (@CompanyId, 'SyncWorkingShift', '{"Enable": true,"LocationCode": "XPC","Timezone":' + @TimeZoneOffset + '}')


IF NOT EXISTS (SELECT 1 FROM [dbo].[SystemConfigs] WHERE [Key] = 'EnableGroupDate' AND Value = 'true' AND CompanyId = @CompanyId)
	INSERT INTO [dbo].[SystemConfigs] 
		VALUES('EnableGroupDate', 'true', @CompanyId)

INSERT INTO dbo.Mail_Config(AppName, [Description], SettingId, MailFrom, IsEncrypt)
VALUES ('Xpeed', 'Xpeed', 2, 'hrm.admin@enpine.com', 0)

DECLARE @AppMailId VARCHAR(50) = (SELECT TOP 1 AppId FROM dbo.Mail_Config WHERE AppName = 'Xpeed');
INSERT INTO dbo.SystemConfigs([Key], [Value], [CompanyId])
    VALUES ('MailSetting', '{"Enable": true, "AppMailId":' + @AppMailId +', "EmailSD": "", "EmailGo": ""}', @CompanyId)

INSERT INTO [dbo].[CompanySite]
           ([CompanyId]
           ,[SiteId]
           ,[AccessToken]
           ,[Domain]
           ,[ModifiedDate])
     VALUES
           (@CompanyId, @SiteId, 'Oe1UTqRJXq3SpFfLorLgXRk/FKdlQ7kAmwkHW+iYLwE=', 'https://hrm.xpeedcorp.com', NULL),
           (@CompanyId, @SiteId, 'Oe1UTqRJXq3SpFfLorLgXRk/FKdlQ7kAmwkHW+iYLwE=', 'https://hrm-new.xpeedcorp.com', NULL)
GO