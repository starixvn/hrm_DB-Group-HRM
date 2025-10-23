/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

/*
	Created: 20251023@Henry
	Task:  create payroll settings
	DB: bodb_HRM

	Revisions:
		20251023@Henry: create payroll settings - [Redmine: #241812]
*/


CREATE TABLE [dbo].[PayrollItemSetting](
	[PayrollItemSettingId] [int] IDENTITY(1,1) NOT NULL,
	[CompanyId] [smallint] NOT NULL,
	[Type] [nvarchar](255) NOT NULL,
	[Taxable] [bit] NOT NULL,
	[Category] [smallint] NOT NULL,
	[IsMultiSelect] [bit] NOT NULL,
	[IsActive] [bit] NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[ModifiedBy] [int] NULL,
	[ModifiedDate] [datetime] NULL,
 CONSTRAINT [PK_PayrollItemSetting] PRIMARY KEY CLUSTERED 
(
	[PayrollItemSettingId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[AllowanceItemSetting](
	[AllowanceItemSettingId] [int] IDENTITY(1,1) NOT NULL,
	[PayrollItemSettingId] [int] NOT NULL,
	[ItemName] [nvarchar](255) NOT NULL,
	[Amount] [varchar](100) NULL,
	[IsPercent] [bit] NOT NULL,
	[IsActive] [bit] NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[ModifiedBy] [int] NULL,
	[ModifiedDate] [datetime] NULL,
 CONSTRAINT [PK_AllowanceItemSetting] PRIMARY KEY CLUSTERED 
(
	[AllowanceItemSettingId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[EmployeePayroll](
	[EmpId] [int] NOT NULL,
	[SalaryStructureId] [int] NOT NULL,
	[SpecialSubsidy] [varchar](100) NULL,
	[NoOfDependent] [int] NOT NULL
 CONSTRAINT [PK_EmployeePayroll] PRIMARY KEY CLUSTERED 
(
	[EmpId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[EmployeePayrollAllowance](
	[EmpId] [int] NOT NULL,
	[AllowanceItemSettingId] [int] NOT NULL
 CONSTRAINT [PK_EmployeePayrollAllowance] PRIMARY KEY CLUSTERED 
(
	[EmpId] ASC,
	[AllowanceItemSettingId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[PayrollItemSetting] ADD CONSTRAINT [DF_PayrollItemSetting_Taxable] DEFAULT ((1)) FOR [Taxable]
GO

ALTER TABLE [dbo].[PayrollItemSetting] ADD CONSTRAINT [DF_PayrollItemSetting_IsMultiSelect] DEFAULT ((0)) FOR [IsMultiSelect]
GO

ALTER TABLE [dbo].[AllowanceItemSetting] ADD CONSTRAINT [DF_AllowanceItemSetting_IsPercent] DEFAULT ((0)) FOR [IsPercent]
GO

ALTER TABLE [dbo].[EmployeePayroll] ADD CONSTRAINT [DF_EmployeePayroll_NoOfDependent] DEFAULT ((0)) FOR [NoOfDependent]
GO

-- Insert PayrollItemSetting for all companies
INSERT INTO [dbo].[PayrollItemSetting] ([CompanyId], [Type], [Taxable], [Category], [IsMultiSelect], [IsActive], [IsDeleted])
SELECT 
    c.CompanyId,
    pis.[Type],
    pis.[Taxable],
    pis.[Category],
    pis.[IsMultiSelect],
    pis.[IsActive],
    pis.[IsDeleted]
FROM [dbo].[Company] c
CROSS JOIN (
    VALUES 
    ('Basic Salary', 1, 1, 0, 1, 0),
    ('Job Level Add-On', 1, 1, 0, 1, 0),
    ('Management Allowance', 1, 2, 0, 1, 0),
    ('Overseas Allowance', 1, 2, 0, 1, 0),
    ('Skill Set Add-On', 1, 2, 1, 1, 0),
    ('Mobilephone Allowance', 0, 2, 0, 1, 0),
    ('Transportation Allowance', 1, 2, 0, 1, 0),
) AS pis([Type], [Taxable], [Category], [IsMultiSelect], [IsActive], [IsDeleted])
GO

-- Insert Management Allowance items for each ManagementLevel
INSERT INTO [dbo].[AllowanceItemSetting] ([PayrollItemSettingId], [ItemName], [Amount], [IsPercent], [IsActive], [IsDeleted], [CreatedDate])
SELECT 
    pis.PayrollItemSettingId,
    ml.[Name] AS ItemName,
    'XyvgtDHO0Uo=' AS Amount, -- 0
    0 AS IsPercent,
    1 AS IsActive,
    0 AS IsDeleted,
    GETDATE() AS CreatedDate
FROM [dbo].[ManagementLevel] ml
CROSS JOIN [dbo].[PayrollItemSetting] pis
INNER JOIN [dbo].[Company] c ON pis.CompanyId = c.CompanyId
WHERE ml.IsDeleted = 0
    AND pis.[Type] = 'Management Allowance'
GO


-- Insert ManagementAllowance for users based on their ManagementLevel
INSERT INTO [dbo].[EmployeePayrollAllowance] ([EmpId], [AllowanceItemSettingId])
SELECT 
    ce.[EmpId],
    ais.[AllowanceItemSettingId]
FROM [dbo].[CompanyEmployee] ce
INNER JOIN [dbo].[ManagementLevel] ml ON ce.[ManagementLevelId] = ml.[ManagementLevelId]
INNER JOIN [dbo].[PayrollItemSetting] pis ON pis.[CompanyId] = ce.[CompanyId] 
    AND pis.[Type] = 'Management Allowance'
INNER JOIN [dbo].[AllowanceItemSetting] ais ON ais.[PayrollItemSettingId] = pis.[PayrollItemSettingId]
    AND ais.[ItemName] = ml.[Name]
WHERE ce.[ManagementLevelId] IS NOT NULL
    AND ml.[IsDeleted] = 0
    AND NOT EXISTS (
        SELECT 1 
        FROM [dbo].[EmployeePayrollAllowance] epa 
        WHERE epa.[EmpId] = ce.[EmpId] 
            AND epa.[AllowanceItemSettingId] = ais.[AllowanceItemSettingId]
    )
GO

-- Insert EmployeePayroll for all employees from data of CompanyEmployee
INSERT INTO [dbo].[EmployeePayroll] ([EmpId], [SalaryStructureId], [SpecialSubsidy], [NoOfDependent])
SELECT 
    ce.[EmpId],
    ce.[SalaryStructureId],
    ce.[Salary],
    0 AS [NoOfDependent]
FROM [dbo].[CompanyEmployee] ce
WHERE NOT EXISTS (
        SELECT 1 
        FROM [dbo].[EmployeePayroll] ep 
        WHERE ep.[EmpId] = ce.[EmpId]
    )
GO




