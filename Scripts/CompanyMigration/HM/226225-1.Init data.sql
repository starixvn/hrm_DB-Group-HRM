USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'SE Asia Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone NVARCHAR(50) = 'SA Western Standard Time'; 
SET @CompanyId = 4;

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


INSERT INTO dbo.SystemConfigs([Key], [Value], [CompanyId])
	VALUES ('MailSetting', '{"Enable": false, "AppMailId": "0", "EmailSD": "", "EmailGo": ""}', @CompanyId)

INSERT INTO [dbo].[CompanySite]
           ([CompanyId]
           ,[SiteId]
           ,[AccessToken]
           ,[Domain]
           ,[ModifiedDate])
     VALUES
           (4, 7, 'iNwj8G0D4VikvwGh7//acyKlmW3vkvw6qy9LYTbm+dE=', 'https://hrm.smstower-vn.com', NULL)
GO
