USE [bodb_HRM]
GO

/****** Object:  Table [dbo].[SalaryUploadHistory] ******/
CREATE TABLE [dbo].[SalaryUploadHistory](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[FileName] varchar(200) NOT NULL,
	[SavedFileName] varchar(200) NOT NULL,
	[CreatedBy] int NULL,
	[CreatedDate] datetime NULL,
	[PeriodType] tinyint NOT NULL,
	[Month] date NOT NULL,
 CONSTRAINT [PK_SalaryUploadHistory] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[PersonalCost] ******/
CREATE TABLE [dbo].[EmployeePayroll](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EmpId] int NOT NULL,
	[PeriodType] tinyint NOT NULL,
	[Month] date NOT NULL,
	[PersonalCost] money NULL default 0,
	[ExtraPayment] money NULL default 0,
	[CreatedBy] int NOT NULL,
	[CreatedDate] datetime NOT NULL,
	[ModifiedBy] int NOT NULL,
	[ModifiedDate] datetime NOT NULL
 CONSTRAINT [PK_PersonalCost] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO