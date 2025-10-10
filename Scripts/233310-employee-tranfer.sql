USE [bodb_HRM]
GO

/*
    Created: Mira@20250919
    Task: Employee transfer
    DB: bodb_HRM

    Revisions:
        20250919@Mira: init table Employee transfer and History work [Redmine: #233310]
*/

-- EmployeeTransfer
CREATE TABLE dbo.EmployeeTransfer(
	TransferId INT IDENTITY(1, 1) NOT NULL,
	EmpId INT NOT NULL,	
	TransferOutCompanyId INT NOT NULL,
	TransferInCompanyId INT NOT NULL,
	TransferOutDate DATE,	
	TransferInDate DATE,
	ModifiedBy INT NOT NULL
 CONSTRAINT [PK_EmployeeTransfer] PRIMARY KEY CLUSTERED 
(
	[TransferId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX IX_EmployeeTransfer_EmpId
ON dbo.EmployeeTransfer (EmpId) INCLUDE (TransferOutCompanyId, TransferInCompanyId, TransferOutDate, TransferInDate);

-- History Work
CREATE TABLE dbo.HistoryWork(
	Id INT IDENTITY(1, 1) NOT NULL,
	EmpId INT NOT NULL,	
	Field NVARCHAR(100) NOT NULL,
	LogDate DATETIME NOT NULL,
	OldValue NVARCHAR(500),
	[Value] NVARCHAR(500),
	ModifiedBy INT NOT NULL
 CONSTRAINT [PK_HistoryWork] PRIMARY KEY CLUSTERED 
(
	[EmpId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX IX_HistoryWork_EmpId
ON dbo.HistoryWork (EmpId) INCLUDE (Field, LogDate, OldValue, [Value]);

