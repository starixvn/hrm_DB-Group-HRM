USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'SE Asia Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone NVARCHAR(50) = 'SA Western Standard Time'; 
SET @CompanyId = 3;


INSERT INTO dbo.DisciplineType (DisciplineTypeId, Name, Score, IsActive)
SELECT DisciplineTypeId, Name, Score, IsActive 
FROM HRM.dbo.DisciplineType;

INSERT INTO dbo.LogAction (
    LogActionId, Name, SpName
)
SELECT 
    la.LogActionId, 
    la.Name, 
    la.SpName
FROM HRM.dbo.LogAction la;



SET IDENTITY_INSERT dbo.JobLevel ON;
INSERT INTO [dbo].[JobLevel]
           (JobLevelId
		   ,Name
           ,IsDeleted
           ,ModifiedBy
           ,ModifiedDate)
     SELECT
			jl.JobLevelId
           ,jl.Name
           ,jl.IsDeleted
           ,NULL
           ,jl.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
	FROM HRM.dbo.JobLevel AS jl WITH (NOLOCK)
SET IDENTITY_INSERT dbo.JobLevel OFF;


-- #region LOOKUP TABLE
SET IDENTITY_INSERT dbo.Lookup ON;

INSERT INTO dbo.Lookup (Id, Code, Name)
SELECT Id, Code, Name FROM HRM.dbo.Lookup;

SET IDENTITY_INSERT dbo.Lookup OFF;

DECLARE @MaxId INT;
SELECT @MaxId = MAX(Id) FROM dbo.Lookup;
DBCC CHECKIDENT ('dbo.Lookup', RESEED, @MaxId);
-- #endregion

INSERT INTO [dbo].[Country]
           ([CountryCode]
           ,[CountryName]
           ,[CountryOrder]
           ,[Nationality])
     SELECT
           CountryCode
           ,CountryName
           ,CountryOrder
           ,Nationality
    FROM [HRM].[dbo].[Country] WITH (NOLOCK)



INSERT INTO [dbo].[SystemConfigs] ([Key], [Value], [CompanyId])
     VALUES ('TimeZone', 7, 3),
        ('SyncWorkingShift', '{"Enable": true,"LocationCode": "SMS","Timezone": 7}', 3),
        ('TimeZone', 8, 8),
        ('SyncWorkingShift', '{"Enable": true,"LocationCode": "WGI","Timezone": 8}', 8),
        ('TimeZone', 7, 9),
        ('SyncWorkingShift', '{"Enable": true,"LocationCode": "CTS","Timezone": 7}', 9)
        ('MailSetting', '{"Enable": true, "AppMailId": 1, "EmailSD": "", "EmailGo": ""}', 3)



SET IDENTITY_INSERT [dbo].[Company] ON 

INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (1, N'Nexcel', N'VN', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (2, N'Lumiplus', N'VN', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (3, N'SMS', N'VN', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (4, N'Hồng Mã', N'VN', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (5, N'CTI', N'PH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (6, N'Lexfin', N'PH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (7, N'Group HR', N'NULL', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (8, N'WGI', N'NULL', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (9, N'Cabintech', N'NULL', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (10, N'Acora', N'MY', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (11, N'Ascentis', N'TW', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (12, N'Connectshore Corp', N'PH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (13, N'Cymabell', N'PH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (14, N'DAR', N'VN', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (15, N'DIGIBYTESKY', N'PH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (16, N'Element Strategies', N'PH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (17, N'Finetic', N'MY', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (18, N'Hyjay', N'TW', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (19, N'Letstalk', N'TW', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (20, N'Next Fortune', N'TW', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (21, N'One Fortune Property', N'PH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (22, N'One Lab', N'TW', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (23, N'Oseas', N'MY', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (24, N'PSB', N'KH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (25, N'PSP', N'PH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (26, N'Sandsdover', N'PH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (27, N'Thendermill', N'PH', NULL, NULL, 1, NULL)
INSERT [dbo].[Company] ([CompanyId], [Name], [CountryCode], [ModifiedBy], [ModifiedDate], [IsActive], [IsDeleted]) VALUES (28, N'Xpeed Corp', N'PH', NULL, NULL, 1, NULL)
SET IDENTITY_INSERT [dbo].[Company] OFF



INSERT INTO [dbo].[CompanySite]
           ([CompanyId]
           ,[SiteId]
           ,[AccessToken]
           ,[Domain]
           ,[ModifiedDate])
     VALUES
           (3 ,1 ,'oNhr7dJMpicekc25a2X1q554Cc/qM5SO8d6wwJkawWo=' ,'https://hrm.sms-vn.com' ,NULL),
           (3 ,1 ,'oNhr7dJMpicekc25a2X1q554Cc/qM5SO8d6wwJkawWo=' ,'https://hrm-new.sms-vn.com' ,NULL),
           (3 ,1 ,'oNhr7dJMpicekc25a2X1q554Cc/qM5SO8d6wwJkawWo=' ,'https://epa-api1.sms-vn.com' ,NULL)



SET IDENTITY_INSERT [dbo].[Mail_Config] ON 
INSERT INTO [dbo].[Mail_Config]
           ([AppId]
		   ,[AppName]
           ,[Description]
           ,[SettingId]
           ,[MailFrom]
           ,[IsEncrypt])
     VALUES
           (1
           ,'HRMS'
           ,'HRMS'
           ,1
           ,'hr.mail@sms-vn.com'
		   ,0)
GO
SET IDENTITY_INSERT [dbo].[Mail_Config] OFF


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
           (1
           ,'mail.sms-vn.com:25 (hr.mail@sms-vn.com)'
           ,1
           ,'hr.mail@sms-vn.com'
           ,'!QA2ws3edp'
           ,'mail.sms-vn.com'
		   ,25)

SET IDENTITY_INSERT [dbo].[Mail_Setting] OFF

GO