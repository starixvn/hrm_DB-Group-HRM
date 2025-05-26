USE bodb_HRM
GO

/*
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

ALTER TABLE [dbo].[SystemConfigs] ALTER COLUMN [Key] VARCHAR(30) NOT NULL
GO

ALTER TABLE [dbo].[SystemConfigs] ADD CONSTRAINT [PK_SystemConfigs] PRIMARY KEY CLUSTERED 
(
	[CompanyId] ASC,
	[Key] ASC
) ON [PRIMARY]
GO
*/

CREATE NONCLUSTERED INDEX IX_EmployeeSupervisor_EmpId_ActionType_IsDeleted
ON dbo.EmployeeSupervisor (EmpId, ActionType, IsDeleted)
GO

CREATE NONCLUSTERED INDEX IX_EmployeeSupervisor_OwnerId_ActionType_IsDeleted
ON dbo.EmployeeSupervisor (OwnerId, ActionType, IsDeleted)
GO

CREATE NONCLUSTERED INDEX IX_GroupSupervisor_GroupId_ActionType_IsDeleted
ON dbo.GroupSupervisor (GroupId, ActionType, IsDeleted)
GO

CREATE NONCLUSTERED INDEX IX_GroupSupervisor_OwnerId_ActionType_IsDeleted
ON dbo.GroupSupervisor (OwnerId, ActionType, IsDeleted)
GO

CREATE NONCLUSTERED INDEX IX_Employee_EmpId_GroupId_Enabled_IsDeleted
ON dbo.Employee (EmpId, GroupId, [Enabled], IsDeleted)
GO