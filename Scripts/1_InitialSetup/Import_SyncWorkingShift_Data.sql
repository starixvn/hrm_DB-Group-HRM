USE [bodb_HRM]
GO

INSERT INTO [dbo].[SystemConfigs]
           ([Key]
           ,[Value]
           ,[CompanyId])
     VALUES
           ('SyncWorkingShift'
			,'{"Enable": true,"LocationCode": "SMS","Timezone": 7,"ApiUrl": "https://owp1.nexdev.net/api/hrm/workingshift"}'
			,4
			)
GO