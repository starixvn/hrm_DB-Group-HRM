USE bodb_HRM
GO

CREATE NONCLUSTERED INDEX IX_Employee_GroupId ON dbo.Employee(GroupId)
GO

DELETE FROM dbo.SystemConfigs WITH (ROWLOCK)
WHERE CompanyId IN (8, 16, 28) AND [Key]='EnableGroupDate'
GO

INSERT INTO dbo.SystemConfigs (CompanyId, [Key], [Value])
VALUES (8, 'EnableGroupDate', 'true')
    ,(16, 'EnableGroupDate', 'true')
    ,(28, 'EnableGroupDate', 'true')
GO

ALTER TABLE [dbo].[SystemConfigs] ADD CONSTRAINT [PK_SystemConfigs] PRIMARY KEY CLUSTERED 
(
	[CompanyId] ASC,
	[Key] ASC
) ON [PRIMARY]
GO