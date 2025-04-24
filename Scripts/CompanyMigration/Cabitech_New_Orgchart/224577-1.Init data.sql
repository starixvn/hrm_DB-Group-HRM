USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'SE Asia Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone NVARCHAR(50) = 'SA Western Standard Time'; 
SET @CompanyId = 9;

IF EXISTS (SELECT 1 FROM [dbo].[SystemConfigs] WHERE [Key] = 'TimeZone' AND CompanyId = @CompanyId)
    UPDATE [dbo].[SystemConfigs]
    SET [Value] = '7'
    WHERE [Key] = 'TimeZone' AND CompanyId = @CompanyId
ELSE
    INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
    VALUES (@CompanyId, 'TimeZone', '7')

-- Update or Insert SystemConfigs
IF EXISTS (SELECT 1 FROM [dbo].[SystemConfigs] WHERE [Key] = 'SyncWorkingShift' AND CompanyId = @CompanyId)
    UPDATE [dbo].[SystemConfigs]
    SET [Value] = '{"Enable": false,"LocationCode": "CTS","Timezone": 7}'
    WHERE [Key] = 'SyncWorkingShift' AND CompanyId = @CompanyId
ELSE
    INSERT INTO [dbo].[SystemConfigs] (CompanyId, [Key], [Value])
    VALUES (@CompanyId, 'SyncWorkingShift', '{"Enable": false,"LocationCode": "CTS","Timezone": 7}')
GO

INSERT INTO dbo.SystemConfigs([Key], [Value], [CompanyId])
	VALUES ('MailSetting', '{"Enable": true, "AppMailId": 4, "EmailSD": "", "EmailGo": ""}', 9)

INSERT INTO [dbo].[CompanySite]
           ([CompanyId]
           ,[SiteId]
           ,[AccessToken]
           ,[Domain]
           ,[ModifiedDate])
     VALUES
           (9, 18, 'Jd7cgaMTpeieADKdy9IOrCMtlHM5FeEHo+LVkai+flU=', 'https://hrm.comtechsb.com', NULL),
           (9, 18, 'Jd7cgaMTpeieADKdy9IOrCMtlHM5FeEHo+LVkai+flU=', 'https://hrm-cabintech.nexdev.net', NULL)
GO

SET IDENTITY_INSERT [dbo].[Mail_Config] ON 
INSERT INTO [dbo].[Mail_Config]
           ([AppId]
		   ,[AppName]
           ,[Description]
           ,[SettingId]
           ,[MailFrom]
           ,[IsEncrypt])
     VALUES
           (4
           ,'CTS'
           ,'CTS'
           ,3
           ,'hrm@comtechsb.com'
		   ,0)

SET IDENTITY_INSERT [dbo].[Mail_Config] OFF
GO


SET IDENTITY_INSERT [dbo].[Mail_Setting] ON 
INSERT INTO [dbo].[Mail_Setting]
           ([SettingId]
		   ,[SettingName]
           ,[IsAuth]
           ,[Username]
           ,[Password]
           ,[Server]
           ,[Port])
     VALUES
           (3
           ,'mail.comtechsb.com:465 (hrm@comtechsb.com)'
           ,1
           ,'hrm@comtechsb.com'
           ,'>2btuS+6'
           ,'mail.comtechsb.com'
		   ,465)
SET IDENTITY_INSERT [dbo].[Mail_Setting] OFF
GO
