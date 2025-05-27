USE [bodb_HRM]
GO


CREATE TABLE [dbo].[CompanySecondmentEmployee](
	[EmpId] [int] NOT NULL,
	[CompanyId] [int] NOT NULL,
    [CreatedBy] [int] NULL,
    [CreatedDate] [datetime] NULL,
    [ModifiedBy] [int] NULL,
    [ModifiedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[EmpId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO


