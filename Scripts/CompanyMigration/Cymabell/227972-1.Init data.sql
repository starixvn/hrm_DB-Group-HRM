USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'Taipei Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone NVARCHAR(50) = 'SA Western Standard Time'; 
SET @CompanyId = 13;

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


INSERT INTO dbo.SystemConfigs([Key], [Value], [CompanyId])
	VALUES ('MailSetting', '{"Enable": false, "AppMailId": "0", "EmailSD": "", "EmailGo": ""}', @CompanyId)

INSERT INTO [dbo].[CompanySite]
           ([CompanyId]
           ,[SiteId]
           ,[AccessToken]
           ,[Domain]
           ,[ModifiedDate])
     VALUES
           (@companyId, 21, 'db6Qh0emq4AUO2DHjoafA11yxXLhlj5b/110hPOGwFU=', 'https://hrm.smstower-vn.com', NULL)
GO
