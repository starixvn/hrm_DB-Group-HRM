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
	[NoOfDependent] [int] NOT NULL,
	[CreatedBy] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[ModifiedBy] [int] NULL,
	[ModifiedDate] [datetime] NULL,
 CONSTRAINT [PK_EmployeePayroll] PRIMARY KEY CLUSTERED 
(
	[EmpId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[EmployeePayrollAllowance](
	[EmpId] [int] NOT NULL,
	[AllowanceItemSettingId] [int] NOT NULL,
	[CreatedBy] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[ModifiedBy] [int] NULL,
	[ModifiedDate] [datetime] NULL,
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

INSERT INTO [dbo].[PayrollItemSetting] ([CompanyId], [Type], [Taxable], [Category], [IsMultiSelect], [IsActive], [IsDeleted])
VALUES 
(3, 'Basic Salary', 1, 'SalaryStructure', 0, 1, 0),
(3, 'Job Level Add-On', 1, 'SalaryStructure', 0, 1, 0),
(3, 'Management Allowance', 1, 'Allowance', 0, 1, 0),
(3, 'Overseas Allowance', 1, 'Allowance', 0, 1, 0),
(3, 'Skill Set Add-On', 1, 'Allowance', 1, 1, 0),
(3, 'Mobilephone Allowance', 0, 'Allowance', 0, 1, 0),
(3, 'Transportation Allowance', 1, 'Allowance', 0, 1, 0),
(3, 'Heavy Job Allowance', 0, 'Allowance', 0, 1, 0)
GO