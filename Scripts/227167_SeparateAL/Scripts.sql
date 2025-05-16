
ALTER TABLE bodb_HRM.dbo.LeaveTrans  
ADD ExtraDays numberic(18,1) NULL
GO


INSERT INTO [dbo].[LeaveTrans]
           ([EmpId]
           ,[RequestId]
           ,[Description]
           ,[FromDate]
           ,[ToDate]
           ,[DeductDays]
           ,[CreditDays]
           ,[Deleted]
           ,[CreatedDate]
           ,[CreatedBy]
           ,[ModifiedDate]
           ,[ModifiedBy]
           ,[OldLeaveTransId]
           ,[ExtraDays])
     VALUES
           (311
           ,NULL
           ,''
           ,'2025-05-15 00:00:00.000'
           ,'2025-12-31 00:00:00.000'
           ,0
           ,0
           ,0
           ,'2025-05-15 00:00:00.000'
           ,null
           ,null
           ,null
           ,null
           ,20)
GO
