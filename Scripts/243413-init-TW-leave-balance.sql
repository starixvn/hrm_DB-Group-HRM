/*
    Created: Mira@20251110
    Task: Init TW Leave Balance
    DB: bodb_HRM

    Revisions:
        20251110@Mira: init TW leave balance [Redmine: #243413]
*/

USE [bodb_HRM]
GO

-- Create table for Taiwan Leave Balance
CREATE TABLE [dbo].[TWLeaveBalanceConfig](
    [TWLeaveBalanceId] [int] IDENTITY(1,1) NOT NULL,
    [Year] [int] NOT NULL,
    [LaborBalance] [int] NOT NULL,
    [CompanyLeave] [int] NOT NULL,
    [Total] [int] NOT NULL,
    [CreatedDate] [datetime] NULL,
    [ModifiedDate] [datetime] NULL,
    CONSTRAINT [PK_TWLeaveBalanceConfig] PRIMARY KEY CLUSTERED 
    (
        [TWLeaveBalanceId] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
    CONSTRAINT [UK_TWLeaveBalance_Year] UNIQUE NONCLUSTERED 
    (
        [Year] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
    
GO

-- Initialize data for Taiwan Leave Balance
INSERT INTO [dbo].[TWLeaveBalanceConfig] ([Year], [LaborBalance], [CompanyLeave], [Total], [CreatedDate])
VALUES
    (0, 10, 2, 12, GETDATE()),
    (1, 10, 3, 13, GETDATE()),
    (2, 14, 0, 14, GETDATE()),
    (3, 14, 1, 15, GETDATE()),
    (4, 15, 1, 16, GETDATE()),
    (5, 15, 2, 17, GETDATE()),
    (6, 15, 3, 18, GETDATE()),
    (7, 15, 4, 19, GETDATE()),
    (8, 15, 5, 20, GETDATE()),
    (9, 16, 5, 21, GETDATE()),
    (10, 17, 5, 22, GETDATE()),
    (11, 18, 5, 23, GETDATE()),
    (12, 19, 5, 24, GETDATE()),
    (13, 20, 5, 25, GETDATE()),
    (14, 21, 5, 26, GETDATE()),
    (15, 22, 5, 27, GETDATE()),
    (16, 23, 5, 28, GETDATE()),
    (17, 24, 5, 29, GETDATE()),
    (18, 25, 5, 30, GETDATE())
GO

 -- init "Years of Service for Extra Leave" for all teams (exclude Nex and TW companies)
UPDATE g
SET LocalYearsOfServiceForExtraLeave = 2,
	ExpatYearsOfServiceForExtraLeave = 2
FROM dbo.[Group] g 
INNER JOIN dbo.Company c WITH(NOLOCK) ON c.CompanyId = g.CompanyId
WHERE g.CompanyId NOT IN (1, 2, 34) -- Nexcel, Lumi, Nexvision
	AND c.CountryCode <> 'TW'
