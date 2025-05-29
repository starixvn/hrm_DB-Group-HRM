USE [bodb_HRM]
GO

CREATE TABLE [dbo].[tmpProcessDiscipline](
	[EmpId] [int] NOT NULL,
	[WorkDate] [date] NOT NULL,
	[InsertedDate] [datetime] NULL
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX IX_tmpProcessDiscipline_EmpId_WorkDate
ON tmpProcessDiscipline (EmpId, WorkDate)