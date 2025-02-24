USE [bodb_HRM]
GO
DECLARE @CompanyId INT = 3;


INSERT INTO [dbo].[RefResource]
           (RefName
           ,ResourceId
           ,[Value]
           ,[Description]
           ,IsActive
		   ,CompanyId)
     SELECT
           RefName
           ,ResourceId
           ,[Value]
           ,[Description]
           ,IsActive
		   ,@CompanyId
	FROM [SMSHRM].[dbo].[RefResource] 
GO





