USE [bodb_HRM]
GO

INSERT INTO [dbo].[SystemConfigs] ([Key], [Value], [CompanyId])
     VALUES ('TimeZone', 7, 3),
        ('SyncWorkingShift', '{"Enable": true,"LocationCode": "SMS","Timezone": 7,"ApiUrl": "https://owp1.nexdev.net/api/hrm/workingshift"}', 3),
        ('TimeZone', 8, 8),
        ('SyncWorkingShift', '{"Enable": true,"LocationCode": "WGI","Timezone": 8,"ApiUrl": "https://owp1.nexdev.net/api/hrm/workingshift"}', 8),
        ('TimeZone', 7, 9),
        ('SyncWorkingShift', '{"Enable": true,"LocationCode": "CTS","Timezone": 7,"ApiUrl": "https://owp1.nexdev.net/api/hrm/workingshift"}', 9)
GO