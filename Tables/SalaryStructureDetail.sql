CREATE TABLE [dbo].[SalaryStructureDetail](
	[SalaryStructureId] [int] NOT NULL,
	[JobLevelId] [int] NOT NULL,
	[LocalSalary] [varchar](100) NULL,
	[ExpatSalary] [varchar](100) NULL,
 CONSTRAINT [PK_SalaryStructureDetail] PRIMARY KEY CLUSTERED 
(
	[SalaryStructureId] ASC,
	[JobLevelId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO