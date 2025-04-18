USE [bodb_HRM]
GO

-- INSERT NEW TEAM
DECLARE @tmpTeam TABLE (
    [BUCode] NVARCHAR(10),
    [DepartmentCode] NVARCHAR(10),
    [TeamCode] NVARCHAR(10),
    [TeamName] NVARCHAR(100),
    [TeamPIC] NVARCHAR(100)
);

-- Insert values
INSERT INTO @tmpTeam ([BUCode], [DepartmentCode], [TeamCode], [TeamName], [TeamPIC])
VALUES 
('FI', 'FI01', 'FI1', 'Finance', 'Steven'),
('HM', 'HM08', 'HL4', 'HR', 'Cams'),
('LG', 'LG02', 'CT1', 'Core Team', 'David Alfeche'),
('LG', 'LG02', 'LY2', 'Lawyer', 'David Alfeche'),
('LG', 'LG03', 'LA2', 'Legal Admin', 'David Alfeche');

-- Get max GroupTeamId
DECLARE @maxId INT = ISNULL((SELECT MAX(GroupTeamId) FROM dbo.[Group]), 0);

INSERT INTO [dbo].[Group]
           ([Code]
           ,[Name]
           ,[CreatedDate]
           ,[CreatedBy]
           ,[CompanyId]
           ,[DepartmentId]
           ,[GroupTeamId]
           ,[PICEmpId])
     SELECT t.TeamCode,
			t.TeamName,
			GETDATE(),
			NULL,
			6,
			d.DepartmentId,
			ROW_NUMBER() OVER (ORDER BY (SELECT 1)) + @maxId AS GroupTeamId,
			e.EmpId
	 FROM @tmpTeam t 
	 INNER JOIN Department d WITH(NOLOCK) ON d.Code = t.DepartmentCode
	 LEFT JOIN dbo.Employee e WITH(NOLOCK) ON e.NickName = t.TeamPIC



-- Insert Employee



-- Update TeamPIC
UPDATE g
SET PICEmpId = e.EmpId
FROM dbo.[Group] g
LEFT JOIN @tmpTeam t ON t.TeamCode = g.Code
LEFT JOIN dbo.Employee e WITH(NOLOCK) ON e.NickName = t.TeamPIC

GO

