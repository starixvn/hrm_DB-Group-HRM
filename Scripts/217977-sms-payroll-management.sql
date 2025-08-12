USE bodb_HRM
GO

INSERT INTO LogAction
VALUES(17, 'Payroll: Insert Update Payroll', 'Payroll_Calculate')
GO

CREATE TABLE [dbo].[MonthlyPayroll](
	[PayrollId] [int] IDENTITY(1,1) NOT NULL,
	[EmpId] [int] NOT NULL,
	[Month] [date] NOT NULL,
	[EmploymentStatus] [tinyint] NULL,
	[CompanyDate] [date] NULL,
	[ConfirmedDate] [date] NULL,
	[ModifiedBy] [int] NULL,
	[ModifiedDate] [datetime] NULL,
 CONSTRAINT [PK_MonthlyPayroll] PRIMARY KEY CLUSTERED 
(
	[PayrollId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[MonthlySalary](
	[PayrollId] [int] NOT NULL,
	[StandardWorkingDay] [tinyint] NULL,
	[UnpaidLeave] [real] NULL,
	[PaidDay] [real] NULL,
	[BasicSalary] [varchar](100) NULL,
	[GrossSalary] [varchar](100) NULL,
 CONSTRAINT [PK_MonthlySalary] PRIMARY KEY CLUSTERED 
(
	[PayrollId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[AccessCounter](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Date] [date] NOT NULL,
	[EmpId] [int] NOT NULL,
	[FunctionName] [nvarchar](200) NULL,
	[Count] [smallint] NULL,
 CONSTRAINT [PK_AccessCounter] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO