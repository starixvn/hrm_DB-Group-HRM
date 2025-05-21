USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'Taipei Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone NVARCHAR(50) = 'SA Western Standard Time'; 
SET @CompanyId = 12;

IF EXISTS (SELECT 1 FROM [dbo].[SystemConfigs] WHERE [Key] = 'TimeZone' AND CompanyId = @CompanyId)
    UPDATE [dbo].[SystemConfigs]
    SET [Value] = '8'
    WHERE [Key] = 'TimeZone' AND CompanyId = @CompanyId
ELSE
    INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
    VALUES (@CompanyId, 'TimeZone', '8')

-- Update or Insert SystemConfigs
IF EXISTS (SELECT 1 FROM [dbo].[SystemConfigs] WHERE [Key] = 'SyncWorkingShift' AND CompanyId = @CompanyId)
    UPDATE [dbo].[SystemConfigs]
    SET [Value] = '{"Enable": false,"LocationCode": "CTS","Timezone": 8}'
    WHERE [Key] = 'SyncWorkingShift' AND CompanyId = @CompanyId
ELSE
    INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
    VALUES (@CompanyId, 'SyncWorkingShift', '{"Enable": false,"LocationCode": "CTS","Timezone": 8}')

INSERT INTO [dbo].[CompanySite]
           ([CompanyId]
           ,[SiteId]
           ,[AccessToken]
           ,[Domain]
           ,[ModifiedDate])
     VALUES
           (@companyId, 20, 'U3UbTpq6F+UNQycd9Ww58XuZAZIsfIlmHA6pvSg7wd4=', 'https://hrm-new.connectshorecorp.com', NULL),
           (@companyId, 20, 'U3UbTpq6F+UNQycd9Ww58XuZAZIsfIlmHA6pvSg7wd4=', 'https://hrm.connectshorecorp.com', NULL)

DECLARE @AppMailId INT;

INSERT INTO [dbo].[Mail_Config]
           ([AppName]
           ,[Description]
           ,[SettingId]
           ,[MailFrom]
           ,[IsEncrypt])
     VALUES
           ('Connectshore'
           ,'Connectshore'
           ,2
           ,'hrm.admin@enpine.com'
           ,0)

SELECT @AppMailId = SCOPE_IDENTITY()

INSERT INTO dbo.SystemConfigs([Key], [Value], [CompanyId])
    VALUES ('MailSetting', CONCAT('{"Enable": false, "AppMailId": "', @AppMailId, '", "EmailSD": "", "EmailGo": ""}'), @CompanyId)

GO
