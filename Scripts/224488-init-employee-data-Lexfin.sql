USE [bodb_HRM]
GO

DECLARE @tmpTeam TABLE (
    [BUCode] NVARCHAR(10),
    [DepartmentCode] NVARCHAR(10),
    [TeamCode] NVARCHAR(10),
    [TeamName] NVARCHAR(100),
    [TeamPIC] NVARCHAR(100),
    [AccountableArea] NVARCHAR(100)
);

-- Insert values
INSERT INTO @tmpTeam ([BUCode], [DepartmentCode], [TeamCode], [TeamName], [TeamPIC], [AccountableArea])
VALUES 
('FI', 'FI01', 'FI1', 'Finance', 'Steven', 'Finance SU01'),
('HM', 'HM08', 'HL4', 'HR', 'Cams', 'HR SU04'),
('LG', 'LG02', 'CT1', 'Core Team', 'David Alfeche', 'Core Team SU02'),
('LG', 'LG02', 'LY2', 'Lawyer', 'David Alfeche', 'Lawyer SU03'),
('LG', 'LG03', 'LA2', 'Legal Admin', 'David Alfeche', 'Legal Admin SU05');

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

GO 

ALTER TABLE [dbo].[Employee]  
ALTER COLUMN OldEmpId INT NULL;
GO


-- INSERT NEW TEAM
DECLARE @tmpEmployeeInfo TABLE (
    [CtrId] INT,
    [TeamName] NVARCHAR(200),
    [TeamCode] NVARCHAR(200),
    [EmpCode] NVARCHAR(200),
    [NickName] NVARCHAR(200),
    [FullName] NVARCHAR(200),
    [UserId] INT,
    [RowIndex] INT 
);

-- Insert values
INSERT INTO @tmpEmployeeInfo ([CtrId], [EmpCode], [NickName], [FullName], [TeamCode], [TeamName], [UserId], [RowIndex])
VALUES 
   (406, N'LEX0008', N'Rachel', N'Bulahan, Rachel Dizon', N'FI1', N'Finance',7563, 1),
 (784, N'LEX0102', N'Lawrence', N'Tordecillas, Lawrence John Tugnao', N'FI1', N'Finance',7564, 2),
 (998, N'LEX0070', N'Diane', N'Calibuyot, Diane Michelle', N'FI1', N'Finance',7565, 3),
 (293, N'LEX0074', N'Wendy', N'Gamilla, Wendy Almoete', N'FI1', N'Finance',7566, 4),
 (387, N'LEX0034', N'Myleen', N'Espiritu, Myleen Melgar', N'FI1', N'Finance',7567, 5),
 (1362, N'LEX0101', N'Tere', N'Dominguez, Teressa Anihal', N'FI1', N'Finance',7568, 6),
 (517, N'LEX0104', N'Mayann', N'Lajara, Mayann Vergara', N'FI1', N'Finance',7569, 7),
 (1263, N'LEX0078', N'Lea', N'Marcial, Lea Albay', N'FI1', N'Finance',7570, 8),
 (1920, N'LEX0098', N'DJ', N'Sael, Danie Joy', N'FI1', N'Finance',7571, 9),
 (1921, N'LEX0099', N'Joy', N'Barba, Evangielyn Joy Loayon', N'FI1', N'Finance',7572, 10),
 (1487, N'LEX0091', N'Cams', N'Aguilan, Ma. Camille Rebutica', N'HL4', N'HR',7573, 11),
 (811, N'LEX0039', N'Erna', N'Lim, Ma. Ernalissa Tinio', N'HL4', N'HR',7574, 12),
 (814, N'LEX0040', N'Loa', N'Perdido, Ma. Luisa Bautista', N'HL4', N'HR',7575, 13),
 (947, N'LEX0062', N'Demz', N'Zamora, Deniezel Pacete', N'HL4', N'HR',7576, 14),
 (1189, N'LEX0077', N'Ruben', N'Tobias, Ruben Anthony III Ongpico', N'HL4', N'HR',7577, 15),
 (1708, N'LEX0092', N'Dhenz', N'Nabre, Dennis Sola', N'HL4', N'HR',7578, 16),
 (1856, N'LEX0095', N'Charlie', N'Quitain, Charlie Reyes', N'HL4', N'HR',7579, 17),
 (2165, N'LEX0103', N'Jayson', N'Capellan, Jayson Abejuela', N'HL4', N'HR',7580, 18),
 (208, N'LEX0007', N'David Alfeche', N'Alfeche, David III Santacera', N'CT1', N'Core Team',7581, 19),
 (778, N'LEX0004', N'Mar', N'Mance, Marilyn Nuval', N'LY2', N'Lawyer',7582, 20),
 (503, N'LEX0001', N'Cel', N'Sison, Maricel Echavez', N'LY2', N'Lawyer',7583, 21),
 (559, N'LEX0009', N'Michael', N'Sebastian, Michael Pagtakhan', N'LY2', N'Lawyer',7584, 22),
 (884, N'LEX0049', N'Jappy', N'Villareal-Guevarra, Jobelle Untalasco', N'LY2', N'Lawyer',7585, 23),
 (1081, N'LEX0075', N'Mari', N'Magrata, Marielle Morales', N'LY2', N'Lawyer',7586, 24),
 (1469, N'LEX0090', N'Jam', N'Urbina, Jamila Reyes', N'LA2', N'Legal Admin',7587, 25),
 (1890, N'LEX0096', N'Butch', N'Bito, Virgilio Galliguez', N'LA2', N'Legal Admin',7588, 26),
 (1911, N'LEX0097', N'Jasmine', N'Torio, Alyanna Jasmine', N'LA2', N'Legal Admin',7589, 27),
 (2034, N'LEX0100', N'Julie', N'Pascua, Julie Anne Enrera', N'LA2', N'Legal Admin',7590, 28),
 (984, N'LEX0068', N'Bry', N'Sy, Bryan Arabaca', N'LA2', N'Legal Admin',7591, 29),
 (378, N'LEX0016', N'Elaine', N'Bautista, Elaine Corre', N'LA2', N'Legal Admin',7592, 30),
 (488, N'LEX0017', N'Hannah', N'Cruz, Hannah Keeziah Quimpo', N'LA2', N'Legal Admin',7593, 31),
 (520, N'LEX0020', N'Grace', N'Luna, Marie Grace Gonzales', N'LA2', N'Legal Admin',7594, 32),
 (822, N'LEX0043', N'Pat', N'Quilatan, Patrick Laurence, Acosta', N'LA2', N'Legal Admin',7595, 33),
 (682, N'LEX0023', N'Paula', N'Angeles, Paula Kristina Alcaraz', N'LA2', N'Legal Admin',7596, 34),
 (726, N'LEX0025', N'Julie', N'Pascua, Julie Anne Enrera', N'LA2', N'Legal Admin',7597, 35),
 (665, N'LEX0021', N'Nikka', N'Nacis, Nikka Sarah Dela Cruz', N'LA2', N'Legal Admin',7598, 36),
 (670, N'LEX0022', N'Bhob', N'Dagdag, Maricel Domingo', N'LA2', N'Legal Admin',7599, 37),
 (789, N'LEX0036', N'Debbie', N'Muñoz, Denise Abby Bautista', N'LA2', N'Legal Admin',7600, 38),
 (790, N'LEX0037', N'Yana', N'Bautista, Ma. Xheryka Alyana Alcaraz', N'LA2', N'Legal Admin',7601, 39),
 (885, N'LEX0051', N'Ann', N'Tabugara, Mary Ann Santiago', N'LA2', N'Legal Admin',7602, 40),
 (1050, N'LEX0072', N'Tabs', N'Salonga, Tabitha Denise Icban', N'LA2', N'Legal Admin',7603, 41),
 (1407, N'LEX0085', N'Ella', N'Palomo, Elyssa Carmella Pineda', N'LA2', N'Legal Admin',7604, 42),
 (1313, N'LEX0079', N'Raph', N'Tugbo, Raphael Tolentino', N'LA2', N'Legal Admin',7605, 43);

DECLARE @rowIndex INT
	,@TotalRows INT
	,@Password VARCHAR(100) = '/IirRX6DR+3J+itTfUQPFeDxmyMAAAAAAAAAAA=='
    ,@CompanyId INT = 6
SELECT @RowIndex = 1
	,@TotalRows = COUNT(1)
FROM @tmpEmployeeInfo

WHILE @RowIndex <= @TotalRows
BEGIN
    DECLARE @EmpId INT
		,@TeamId INT = NULL
		,@TeamCode NVARCHAR(200)

    SELECT  @TeamCode = TeamCode, @EmpId = UserId
	FROM @tmpEmployeeInfo
	WHERE RowIndex = @rowIndex

	SELECT @TeamId = team.GroupId
	FROM dbo.[Group] AS team WITH (NOLOCK)
	WHERE team.[Code] = @TeamCode and CompanyId = @CompanyId

INSERT INTO [dbo].[Employee]
           ([EmpId]
           ,[Code]
           ,[FullName]
           ,[NickName]
           ,[DOB]
           ,[Enabled]
           ,[GroupId]
           ,[CreatedDate]
           ,[isDeleted]
           ,[Password]
           ,[PasswordReset]
           ,[UserId]
           ,[CtrId])
     SELECT tmp.UserId
           ,tmp.EmpCode
           ,tmp.FullName
           ,tmp.NickName
           ,'1900-01-01'
           ,1
           ,@TeamId
           ,GETDATE()
           ,0
           ,@Password
           ,0
           ,tmp.UserId
           ,tmp.CtrId
     FROM @tmpEmployeeInfo tmp
     WHERE RowIndex = @rowIndex;

     INSERT INTO dbo.CompanyEmployee (EmpId, CompanyId)
     VALUES (@EmpId, @CompanyId);


    INSERT INTO dbo.EmployeeSummary (EmpId, CanOT, WorkingDays, WorkingHours, OffDaysbyWeek, IsLocal, IsTopManager, IsDefaultSchedule)
	SELECT tmp.UserId, 1, 22, 9, 2, 1, 0, 0
	FROM @tmpEmployeeInfo tmp
	WHERE RowIndex = @rowIndex;

    INSERT INTO dbo.EmployeeContract (EmpId)
	VALUES (@EmpId);

    EXEC dbo.EmployeeRole_Insert @EmployeeId = @EmpId
		,@RoleIds = '1'
		,@ModifiedBy = -1;
    
    INSERT INTO dbo.EmployeeDefaultShift (EmpId)
	VALUES (@EmpId);


    SET @RowIndex = @RowIndex + 1;
END

GO


-- Update TeamPIC

DECLARE @tmpTeam TABLE (
    [BUCode] NVARCHAR(10),
    [DepartmentCode] NVARCHAR(10),
    [TeamCode] NVARCHAR(10),
    [TeamName] NVARCHAR(100),
    [TeamPIC] NVARCHAR(100),
    [AccountableArea] NVARCHAR(100)
);

-- Insert values
INSERT INTO @tmpTeam ([BUCode], [DepartmentCode], [TeamCode], [TeamName], [TeamPIC], [AccountableArea])
VALUES 
('FI', 'FI01', 'FI1', 'Finance', 'Steven', 'Finance SU01'),
('HM', 'HM08', 'HL4', 'HR', 'Cams', 'HR SU04'),
('LG', 'LG02', 'CT1', 'Core Team', 'David Alfeche', 'Core Team SU02'),
('LG', 'LG02', 'LY2', 'Lawyer', 'David Alfeche', 'Lawyer SU03'),
('LG', 'LG03', 'LA2', 'Legal Admin', 'David Alfeche', 'Legal Admin SU05');

UPDATE g
SET PICEmpId = e.EmpId
FROM dbo.[Group] g
LEFT JOIN @tmpTeam t ON t.TeamCode = g.Code
LEFT JOIN dbo.Employee e WITH(NOLOCK) ON e.NickName = t.TeamPIC
INNER JOIN dbo.CompanyEmployee ce  WITH(NOLOCK) ON ce.EmpId = e.EmpId and ce.CompanyId = 6
WHERE g.CompanyId = 6

GO






