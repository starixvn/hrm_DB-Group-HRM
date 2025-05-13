USE [bodb_HRM]
GO
DECLARE @LocationCode VARCHAR(10) = 'WGI'
DECLARE @CompanyId INT = (SELECT TOP 1 CompanyId FROM Company WHERE Name = @LocationCode);
DECLARE @CurrentTimeZone VARCHAR(50) = 'Taipei Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone VARCHAR(50) = 'SA Western Standard Time'; 
DECLARE @TimeZoneOffset VARCHAR(5) = 8; 
DECLARE @SiteId INT = 27;

IF EXISTS (SELECT 1 FROM [dbo].[SystemConfigs] WHERE [Key] = 'TimeZone' AND CompanyId = @CompanyId)
    UPDATE [dbo].[SystemConfigs]
    SET [Value] = @TimeZoneOffset
    WHERE [Key] = 'TimeZone' AND CompanyId = @CompanyId
ELSE
    INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
    VALUES (@CompanyId, 'TimeZone', @TimeZoneOffset)

IF EXISTS (SELECT 1 FROM [dbo].[SystemConfigs] WHERE [Key] = 'SyncWorkingShift' AND CompanyId = @CompanyId)
    UPDATE [dbo].[SystemConfigs]
    SET [Value] = '{"Enable": true,"LocationCode": "' + @LocationCode + '","Timezone":' + @TimeZoneOffset + '}'
    WHERE [Key] = 'SyncWorkingShift' AND CompanyId = @CompanyId
ELSE
    INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
    VALUES (@CompanyId, 'SyncWorkingShift', '{"Enable": true,"LocationCode": "' + @LocationCode + '","Timezone":' + @TimeZoneOffset + '}')


IF NOT EXISTS (SELECT 1 FROM [dbo].[SystemConfigs] WHERE [Key] = 'EnableGroupDate' AND Value = 'true' AND CompanyId = @CompanyId)
	INSERT INTO [dbo].[SystemConfigs] 
		VALUES('EnableGroupDate', 'true', @CompanyId)

INSERT INTO dbo.Mail_Config(AppName, [Description], SettingId, MailFrom, IsEncrypt)
VALUES (@LocationCode, @LocationCode, 2, 'hrm.admin@enpine.com', 0)

DECLARE @AppMailId VARCHAR(50) = (SELECT TOP 1 AppId FROM dbo.Mail_Config WHERE AppName = @LocationCode);
INSERT INTO dbo.SystemConfigs([Key], [Value], [CompanyId])
    VALUES ('MailSetting', '{"Enable": true, "AppMailId":' + @AppMailId +', "EmailSD": "", "EmailGo": ""}', @CompanyId)

INSERT INTO [dbo].[CompanySite]
           ([CompanyId]
           ,[SiteId]
           ,[AccessToken]
           ,[Domain]
           ,[ModifiedDate])
     VALUES
           (@CompanyId, @SiteId, '1zyKmGCrowW/I3hquY47/+pfnP6PKtjMAA2FOTMZUI0=', 'https://hrm-new.ghrworld.com', NULL),
           (@CompanyId, @SiteId, '1zyKmGCrowW/I3hquY47/+pfnP6PKtjMAA2FOTMZUI0=', 'https://hrm.ghrworld.com', NULL)
GO